#!/bin/bash

set -e
set -x

id=$1
sandbox=$2
part_zip=$3
image=$4
track=$5

patches=/home/aspcomp/aspcomp2013-svn/participants

loop=$(mktemp -d)
trap "umount -d /dev/loop0; rmdir $loop" EXIT
trap "rm $image" ERR

( losetup -d /dev/loop0 2>/dev/null || exit 0 )
size=$(du $sandbox | cut -f1)
dd if=/dev/zero of=$image bs=1k count=$(( $size + ( $size < 150000 ? 150000 : ($size / 4) ) ))
losetup /dev/loop0 $image
mkfs -t ext2 /dev/loop0 >/dev/null
mount -t ext2 /dev/loop0 $loop
tar -C ${loop} --strip-components=1 -xf $sandbox

7z x -o${loop}/usr/local $part_zip 

#
# quick fixes for the images
#

# make everything 0777, some participants bring their own tmp folder in /usr/local
chmod -Rv ugo+rwx ${loop}/usr/local

#
# less quick fixes
#

patch=${patches}/s${id}/s${id}.patch
test -f ${patch} && patch -d ${loop}/usr/local -p1 < ${patch}


# report all files
find ${loop}/usr/local -ls


# get benchmarks dirs for the participant image
if [ -x ${loop}/usr/local/bin/run ]
then
    BMDIRS=$(find $track -maxdepth 1 -mindepth 1 -type d -printf "%P\n")
else
    BMDIRS=$(find ${loop}/usr/local -mindepth 3 -maxdepth 3 -name run -printf "b%P\n" | cut -d/ -f1 | cut -d- -f1)
fi

# create solver dir and link the image in the appropriate benchmark
# dirs (not all solvers participate in all benchmarks in the M&S
# track)
for b in $BMDIRS
do
    mkdir -pv $track/$b/s$id
    ln -sv $image $track/$b/s$id/$(basename $image)
done
