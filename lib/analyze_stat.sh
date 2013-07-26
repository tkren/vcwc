#!/bin/bash
set -e

track=${1:?'track unset'}
benchmark=${2:-*}
participant=${3:-*}

for d in $(eval echo $track/$benchmark/$participant)
do

    if [ -d $d ]; then

	echo $d

	find $d -mindepth 3 -maxdepth 3 -name "stat" -fprint0 /dev/stdout | \
	    xargs -0 cat | sed -n '1p;2~2p' | nl -v0 | column -t

	echo "-- "

    fi

done
