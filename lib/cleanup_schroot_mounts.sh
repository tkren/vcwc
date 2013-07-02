#!/bin/bash

sdir=/var/lib/schroot

find ${sdir}/session -maxdepth 1 -mindepth 1 -type f -printf "${sdir}/mount/%f\n" | \
    xargs -I{} umount -v {}/var/tmp {}/tmp {}/sys {}/proc {}

find /var/lib/schroot/{mount,session} -mindepth 1 -maxdepth 1 -ls -delete