#!/bin/bash
set -e

runas=$1
profile=$2
output=$3

test -d $output || exit 3

output_find_opts1="$output -maxdepth 1"
output_find_opts2="$output -mindepth 1 -maxdepth 1 -type f"
function sorthead { sort -r | head -n1 ; }

last_mtime=$(find $output_find_opts1 -printf "%TY-%Tm-%Td %TT\n" | sorthead)

aspcomp_cgroup=$(grep memory /proc/self/cgroup | cut -d: -f3)/aspcomp2013
/usr/bin/sudo -u $runas /usr/bin/cgexec -g cpuset,memory:$aspcomp_cgroup /home/$runas/bin/run.sh $profile $output

find $output_find_opts2 -newermt "$last_mtime" -print0 | xargs -0 cp -avt .

me=$(hostname)
for host in lion node{2,3,4}; do
    test $host = $me || find $output_find_opts2 -newermt "$last_mtime" -print0 | xargs -0 /usr/bin/sudo -u $runas cp -avut /mnt/$host/$output
done
