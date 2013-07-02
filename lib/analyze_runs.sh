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
			\( -name "run_*_stdout" -fprint0 /dev/stdout \) -o \
			\( -name "run_*_stderr" -fprint0 /dev/stderr \)
		} | xargs -0 awk \
		    'BEGIN {nans=0; nyes=0; nno=0; nfac=0; ninc=0; nunk=0; ncos=0; nopt=0; ndis=0;}
                     /^ANSWER/{nans++; next;}
		     /^yes./{nyes++; next;}
		     /^no./{nno++; next;}
		     /^[a-z]+[^\(\)\.\,]*\(([a-z0-9\_]+\,)*[a-z0-9\_]+\)\.([\ ]*[a-z]+[^\(\)\.\,]*\(([a-z0-9\_]+\,)*[a-z0-9\_]+\)[\ ]*)*/{nfac++; next;}
		     /^INCONSISTENT|UNSATISFIABLE/{ninc++; next;}
		     /^UNKNOWN/{nunk++; next;}
		     /^COST/{ncos++; next;}
		     /^OPTIMUM/{nopt++; next;}
                     {ndis++; next;}
		     END{ if (nyes + nno == 0) { print "ANSWER:", nans, "FACTS:", nfac, "COST:", ncos, "OPTIMUM:", nopt; }
		          else { print "ANSWER:", nans, "YES:", nyes, "NO:", nno; }
		          print "INCONSISTENT:", ninc;
		          print "UNKNOWN:", nunk;
                          print "DISCREPANCY:", ndis;
		       }' 1>&3 2>&4 3>&- 4>&-

	    } 2>&1 | xargs -0 awk -F: \
		'/Elapsed/{ if ($5 == 0) {
		              if ($6 <= 5) { print "completed within 05 secs"; }
		              else { print "completed within 59 secs"; }
		            } else { printf("completed >= %02d mins\n", int($5)); }
		            elapsed++;
		          }
                 /Minor/{ if ( (int($2) * 4096) > 6442450944) { memout++; } }
		 /Exit status/{ print "Exit status:", $2; }
		 END{ print "TOTAL:", elapsed > "/dev/stderr";
                      print "MEMOUT:", int(memout) > "/dev/stderr"; }' | \
		     sort | uniq -c 3>&- 4>&-

	} 2>&1 3>&1 4>&2


	{
	    {
		{
		    find $d -mindepth 3 -maxdepth 3 -type f -name "run_*_stdout" \
			-printf "%h\n" | sort | tee /dev/stderr
		} | uniq | join -v 1 <(find $d -mindepth 2 -prune | sort) - \
		    | xargs -r echo "Missing runs:" 1>&3 2>&4 3>&- 4>&-

	    } 2>&1 | uniq -d | xargs -r echo "Duplicate runs:" 3>&- 4>&-

	} 3>&1 4>&1 

	echo "-- "

    fi

done
