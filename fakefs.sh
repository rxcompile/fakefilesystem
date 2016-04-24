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
dd if=$device bs=$l_size count=$l_count skip=$l_skip status=none conv=notrunc,sync
}

function set_block {
local l_bytes=${1:-\x00};
local l_seek=${2:-0};
local l_count=${3:-$(get_length $l_bytes)};
echo -ne $l_bytes | dd of=$device bs=1 seek=$l_seek count=$l_count status=none conv=notrunc,sync
}

function set_filemeta {
local l_filename=$1;
local l_slot=find_free_slot;
set_block $l_filename $(expr $l_slot \* 32 + $off_filemeta);
}

function create_device {
touch $device;
set_block $DEVICE_MAGIC $off_header;
local i=1;
for (( off=$off_filemeta; off<$filemeta_count*$off_filemeta; off+=$off_filemeta ))
do
    echo -n "["
    for ((j=0; j<i; j++)) ; do echo -n ' '; done
    echo -n '=>'
    for ((j=i; j<$filemeta_count; j++)) ; do echo -n ' '; done
    echo -n "] $i / $filemeta_count" $'\r'
    #echo $off
    set_block 1 $off;
    ((i++))
done
echo
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


#set_block $DEVICE_MAGIC $off_header;
#get_block $off_header;
get_block $off_header $(get_length $DEVICE_MAGIC)
echo "$DEVICE_MAGIC"

case $mode in
    format )
        rm -f $device
        echo "Creating Device"
        create_device;
        check_fs;
        echo "Device is OK"
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
    ls )
        echo "Device listing"
        check_fs;
        echo "Device is OK, working"
        ;;
    rm )
        echo "Removing file from device"
        check_fs;
        echo "Device is OK, working"
        ;;
esac

