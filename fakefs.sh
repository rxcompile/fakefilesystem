#!/bin/bash

DEVICE_MAGIC=$(echo -ne "\xFA\xCE")
off_header=0;
off_filemeta=32;
len_filemeta_name=28;
len_filemeta_loc=4;
filemeta_count=100; #$(expr 1024 \* 1024 / 32 - 1 );


function usage {
echo "Usage:";
echo "fakefs <mode> [args]"
echo "mode:"
echo "download <fileOnFs> <device> <location>"
echo "upload <fileOnFs> <device> <location>"
echo "copy <fileOnFs> <device> <newFileOnFs>"
echo "ls <device>"
echo "rm <fileOnFs> <device>"
}

function get_length {
echo -ne "$1" | dd 2>&1 >/dev/null | awk ' NR==3 {print $1} '
}

function error_arg {
if [[ $1 < $2 ]]; then
    echo "ERROR: Wrong number of arguments";
    usage;
    exit;
fi
}

function check_fs {
if [[ "$(get_block $off_header $(get_length $DEVICE_MAGIC))" != "$DEVICE_MAGIC" ]]; then
    echo "ERROR: Not a fakefs device";
    exit 1;
fi
}

function get_block {
local l_skip=$1;
local l_size=${3:-1};
local l_count=${2:-1};
local ret=$(dd if=$device bs=$l_size count=$l_count skip=$l_skip status=none conv=notrunc,sync)
if [[ $? > 0 ]]; then
    echo ""
else
    echo $ret
fi
}

function set_block {
local l_bytes=$1;
local l_seek=${2:-0};
local l_count=${3:-$(get_length $l_bytes)};
echo -ne $l_bytes | dd of=$device bs=1 seek=$l_seek count=$l_count status=none conv=notrunc,sync
}

function find_free_slot {
for (( off=$off_filemeta; off<$filemeta_count*$off_filemeta; off+=$off_filemeta ))
do
    if [[ $(get_block $off 1) == "\x00" ]]; then
        echo $(expr $off / 32);
        break;
    fi
done
echo $off_filemeta;
}

function set_filemeta {
local l_filename=${1:0:$len_filemeta_name};
local l_slot=${2:-$(find_free_slot)};
set_block $l_filename $(expr $l_slot \* 32 + $off_filemeta);
}

function get_filemeta {
local l_slot=${1:-0}
local ret=$(get_block $(expr $l_slot \* 32 + $off_filemeta) $len_filemeta_name)
if [[ $? > 0 ]]; then
    echo ""
else
    echo $ret
fi
}

function get_file_offset {
local l_slot=${1:-0}
get_block $(expr $l_slot \* 32 + $off_filemeta + $len_filemeta_name) $len_filemeta_loc
}

function create_device {
touch $device;
set_block $DEVICE_MAGIC $off_header;
for (( i=1; i<$filemeta_count; i++ ))
do
    echo -n "["
    for ((j=0; j<i; j++)) ; do echo -n '='; done
    echo -n '=>'
    for ((j=i; j<100; j++)) ; do echo -n ' '; done
    echo -n "] $i% / 100%" $'\r'

    set_filemeta "\x00" $i;
done
echo
}

function list_device {
for (( i=1; i<$filemeta_count; i++ ))
do
    local l_filename=$(get_filemeta $i)
    if [[ "$l_filename" != "" ]]; then
        echo "Slot $i: $(get_filemeta $i) Offset: $(get_file_offset $i)"
    fi
done
}

error_arg $# 1;
mode=$1;

case $mode in
    download | upload | copy )
        error_arg $# 4;
        filename=$2;
        device=$3;
        location=$4;
        ;;
    ls | format )
        error_arg $# 2;
        device=$2;
        ;;
    rm )
        error_arg $# 3;
        filename=$2;
        device=$3;
        ;;
    * )
        echo "Unknown mode";
        usage;
        exit;
        ;;
esac

case $mode in
    format )
        rm -f $device
        echo "Creating Device"
        create_device;
        check_fs;
        echo "Device is OK"
        ;;
    ls )
        check_fs;
        echo "Device is OK"
        echo "Device listing:"
        list_device;
        ;;
    download )
        echo "Download mode active"
        check_fs;
        echo "Device is OK, working"
        ;;
    upload )
        echo "Upload mode active"
        check_fs;
        echo "Device is OK, working"
        ;;
    copy )
        echo "Copy mode active"
        check_fs;
        echo "Device is OK, working"
        ;;
    rm )
        echo "Removing file from device"
        check_fs;
        echo "Device is OK, working"
        ;;
esac
