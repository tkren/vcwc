#!/bin/bash
set -e

runas=$1
profile=$2
input=$3
output=$4

test -d $input || exit 3
test -d $output || exit 3

input_find_opts="$input -mindepth 1 -maxdepth 1 -type f"
output_find_opts1="$output -maxdepth 1"
output_find_opts2="$output -mindepth 1 -maxdepth 1 -type f"
function sorthead { sort -r | head -n1 ; }

last_mtime=$(find $output_find_opts1 -printf "%TY-%Tm-%Td %TT\n" | sorthead)

declare -i exit_code=$(find $input_find_opts -name "run_*_stderr" | sorthead | xargs egrep -m1 $'^\tExit status:' | cut -d: -f2)

stdout_file=$(find $input_find_opts -name "run_*_stdout" | sorthead)

if [ -z "$stdout_file" ]; then
    echo "No stdout file in $output" 1>&2
    exit 3
fi


# dispatch stdout file of the run
awk -F' ' 'BEGIN { nans=0; nfac=0; nunk=0; ninc=0; ncos=0; nopt=0; cost=0; ncom=0; ndis=0; }

/^ANSWER/ {
  ans_seen = ! ans_seen;
  if (ninc+nunk > 0) { ndis++; }
  nans++; next;
}

ans_seen == 1 {
  ans_seen = ! ans_seen;
  nfac++; print; next;
}

/^INCONSISTENT|UNSATISFIABLE/ {
  if (nans+nfac+nunk+ncos+nopt > 0) { ndis++; }
  ninc++; print "INCONSISTENT"; next;
}

/^UNKNOWN/ {
  if (nans+nfac+ncos+nopt+ninc == 0) { nunk++; print; }
  else { ndis++; }
  next;
}

/^COST/ {
  if ( (ninc+nunk > 0) || (nans+nfac == 0) ) { ndis++; }
  cost=int($2); ncos++; next;
}

/^OPTIMUM/ {
  if ( ninc+nunk > 0 || ncos == 0 ) { ndis++; }
  nopt++; next;
}

/^%/ {
  ncom++;
}

/^[a-z]+[^\(\)\.\,]*(\(([a-z0-9\_]+\,)*[a-z0-9\_]+\))?\.([\ ]*[a-z]+[^\(\)\.\,]*(\(([a-z0-9\_]+\,)*[a-z0-9\_]+\))?\.[\ ]*)*/ {
  if (ninc+nunk > 0) { ndis++; }
  nfac++; print; next;
}

{ ndis++; }

END {
    if (nans+nfac+ncos+nopt+ninc+nunk == 0) { ndis++; nunk++; print "UNKNOWN"; }
    else if (nans > 0 && nfac == 0) { ndis++; nfac++; print ""; }
    else if (nans != nfac) { ndis++; }
    print nunk, nans, nfac, ninc, ncos, cost, nopt, ncom, ndis;
}' $stdout_file | tail -n2 | {

    read answer
    read -a things
    
    declare -i num_unknown=${things[0]}
    declare -i num_answers=${things[1]}
    declare -i num_facts=${things[2]}
    declare -i num_inconsistent=${things[3]}
    declare -i num_costs=${things[4]}
    declare -i cost=${things[5]}
    declare -i num_optimum=${things[6]}
    declare -i num_comments=${things[7]}
    declare -i num_discrepancies=${things[8]}
    
    echo "EXIT: " $exit_code
    echo "OUTPUT: " $(echo $answer | cut -c1-60)
    echo "COST: " $cost
    printf "ANSWER: %s FACTS: %s INCONSISTENT: %s UNKNOWN: %s COST: %s OPTIMUM: %s COMMENTS: %s DISCREPANCIES: %s\n" \
	$num_answers \
	$num_facts \
	$num_inconsistent \
	$num_unknown \
	$num_costs \
	$num_optimum \
	$num_comments \
	$num_discrepancies
    

    answer_summary="$(echo "$answer" | cut -c1-20)"
    is_no=0; test "$(echo "$answer_summary" | sed -e 's/^ *//g' -e 's/ *$//g')" = "no." && is_no=1

    if ( [ $num_inconsistent -gt 0 ] && [ $exit_code -eq 20 ] ) || \
        ( [ $num_facts -gt 0 ] && [ $num_costs -eq 0 ] && [ $num_optimum -eq 0 ] && [ $exit_code -eq 20 ] && [ $is_no -eq 1 ] ) || \
	( [ $num_facts -gt 0 ] && [ $num_costs -gt 0 ] && [ $num_optimum -gt 0 ] && [ $exit_code -eq 30 ] ) || \
	( [ $num_facts -gt 0 ] && [ $num_costs -gt 0 ] && [ $num_optimum -eq 0 ] && [ $exit_code -eq 11 ] ) || \
	( [ $num_facts -gt 0 ] && [ $num_costs -eq 0 ] && [ $num_optimum -eq 0 ] && [ $exit_code -eq 10 ] ) || \
	( [ $num_unknown -gt 0 ] && [ $exit_code -eq 1 ] )
    then

	test $num_discrepancies -eq 0 && echo GOOD || echo DISCREPANCY

    else

	if [ $num_inconsistent -gt 0 ] && [ $exit_code != 20 ]; then
	    exit_code=20
        elif [ $num_facts -gt 0 ] && [ $num_costs -eq 0 ] && [ $num_optimum -eq 0 ] && [ $exit_code != 20 ] && [ $is_no -eq 1 ]; then
	    exit_code=20
	elif [ $num_facts -gt 0 ] && [ $num_costs -gt 0 ] && [ $num_optimum -gt 0 ] && [ $exit_code != 30 ]; then
	    exit_code=30
	elif [ $num_facts -gt 0 ] && [ $num_costs -gt 0 ] && [ $num_optimum -eq 0 ] && [ $exit_code != 11 ]; then
	    exit_code=11
	elif [ $num_facts -gt 0 ] && [ $num_costs -eq 0 ] && [ $num_optimum -eq 0 ] && [ $exit_code != 10 ]; then
	    exit_code=10	    
	else
	    exit_code=1
	fi

	printf "DECISION: %s, %s, %s, %s\n" $exit_code "$(test $exit_code -eq 1 -o \( $is_no -eq 0 -a $exit_code -eq 20 \) && echo "$answer" || printf '{ %s ... }' "$answer_summary" )" $cost $num_optimum

	#let num_discrepancies++

    fi
    
    echo "$answer" | /usr/bin/sudo -u $runas /home/$runas/bin/validate.sh $profile $output $(( $exit_code & 0xFE ))
    
}


find $output_find_opts2 -newermt "$last_mtime" -print0 | xargs -0 cp -avt .

me=$(hostname)
for host in lion node{2,3,4}; do
    test $host = $me || find $output_find_opts2 -newermt "$last_mtime" -print0 | xargs -0 /usr/bin/sudo -u $runas cp -avut /mnt/$host/$output
done
