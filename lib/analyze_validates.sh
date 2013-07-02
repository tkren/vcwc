#!/bin/bash
set -e

track=${1:?'track unset'}
benchmark=${2:-*}
participant=${3:-*}

for d in $(eval echo $track/$benchmark/$participant)
do

    if [ -d $d ]; then

	echo $d

	{
	    {
		{
		    find $d -mindepth 3 -maxdepth 3 \
			\( -name "validate_*_stdout" -fprint0 /dev/stdout \) -o \
			\( -name "validate_*_stderr" -fprint0 /dev/stderr \)
		} | xargs -0 awk -F' ' \
		    'BEGIN{nok=0; ncs=0; nfl=0; ndk=0; nwn=0; nds=0;}
                     /^OK/{nok++; if ($2) {ncs++;} next; }
		     /^FAIL/{ nfl++; next; }
		     /^DONTKNOW/{ ndk++; next; }
		     /^WARN/{ nwn++; next; }
                     { nds++; next; }
		     END{ print "OK:", nok, "COST:", ncs, "FAIL:", nfl, "DONTKNOW:", ndk, "WARN:", nwn, "DISCREPANCY:", nds; }' 1>&3 2>&4 3>&- 4>&-

	    } 2>&1 | xargs -0 awk -F: \
		'/Elapsed/{ if ($5 == 0) {
		              if ($6 <= 5) { print "completed within 05 secs"; }
		              else { print "completed within 59 secs"; }
		            } else { printf("completed >= %02d mins\n", int($5)); }
		            elapsed++;
		          }
                 /Minor/{ if ( (int($2) * 4096) > 536870912) { memout++; } }
		 /Exit status/{ print "Exit status:", $2; }
		 END{ print "TOTAL:", elapsed > "/dev/stderr";
                      print "MEMOUT:", int(memout) > "/dev/stderr"; }' | \
		     sort | uniq -c 3>&- 4>&-

	} 2>&1 3>&1 4>&2


	{
	    {
		{
		    find $d -mindepth 3 -maxdepth 3 -type f -name "validate_*_stdout" \
			-printf "%h\n" | sort | tee /dev/stderr
		} | uniq | join -v 1 <(find $d -mindepth 2 -type d -prune | sort) - \
		    | xargs -r echo "Missing validations:" 1>&3 2>&4 3>&- 4>&-

	    } 2>&1 | uniq -d | xargs -r echo "Duplicate validations:" 3>&- 4>&-

	} 3>&1 4>&1 

	echo "-- "

    fi

done
