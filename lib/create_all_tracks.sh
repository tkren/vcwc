#!/bin/bash

tracksdir=/home/aspcomp/aspcomp2013-svn/tracks
encodingsdir=/home/aspcomp/aspcomp2013-svn/benchmarks/encodings
tracks="t01-Model+Solve.txt t02-Sequential_Systems.txt t03-Parallel_Systems.txt"
participants=/home/aspcomp/participants
images=$participants/images
submissions=/home/aspcomp/submissions
create_participant_image=/home/aspcomp/aspcomp2013-svn/aspexec/lib/create_participant_image.sh

for t in $tracks; do

    track=$(echo $t | cut -d- -f1)

    echo Creating participant images for $track

    while read ID foo ENC ; do

	echo Creating participant ${images}/s${ID}.img

	case $ID in
	    52|62)
		sandbox=/home/aspcomp/software/sandbox-cplex.tar
		;;
	    *)
		sandbox=/home/aspcomp/software/sandbox.tar
		;;
	esac

	test -f ${images}/s${ID}.img && \
	    echo $ID is already there. || \
	    sudo $create_participant_image ${ID} ${sandbox} $submissions/aspcomp2013_submission_${ID}.zip ${images}/s${ID}.img $participants/$track

	for bm in $encodingsdir/$ENC/[[:digit:]]*/encoding.asp ; do

	    bmid=$(cut -d/ -f8 <<<"$bm" | cut -d- -f1)
	    sudo ln -sv ${bm} ${participants}/${track}/b${bmid}/s${ID}/encoding.asp

	done

    done < $tracksdir/$t

done
