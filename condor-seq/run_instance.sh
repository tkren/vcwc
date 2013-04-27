#!/bin/bash
runas=$1
profile=$2
output=$3
test -d $output && /usr/bin/sudo -u $runas find $output -maxdepth 1 -mindepth 1 -type f -delete
/usr/bin/sudo -u $runas /home/$runas/bin/run.sh $profile $output
cp -av $output -T .
