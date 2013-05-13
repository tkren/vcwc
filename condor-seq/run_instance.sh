#!/bin/bash
set -e
runas=$1
profile=$2
output=$3
test -d $output && /usr/bin/sudo -u $runas find $output -maxdepth 1 -mindepth 1 -type f -delete
aspcomp_cgroup=$(cat /proc/self/cgroup | grep memory | cut -d: -f3)/aspcomp2013
/usr/bin/sudo -u $runas /usr/bin/cgexec -g cpuset,memory:$aspcomp_cgroup /home/$runas/bin/run.sh $profile $output
cp -av $output -T .
me=$(hostname); for host in lion node{2,3,4}; do test $host = $me || /usr/bin/sudo -u $runas cp -avu $output -T /mnt/$host/$output; done
