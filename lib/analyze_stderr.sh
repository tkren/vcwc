#!/bin/bash
set -e

track=${1:?'track unset'}
benchmark=${2:-*}
participant=${3:-*}

for d in $(eval echo $track/$benchmark/$participant)
do

    if [ -d $d ]; then

	echo $d

	find $d -mindepth 3 -maxdepth 3 -name "run_*_stderr" -fprint0 /dev/stdout | xargs -0 egrep -hv $'(^\t|^Command exited)' | sed '/^$/d' | sort | uniq -c | sort -rn | less

	echo "-- "

    fi

done
