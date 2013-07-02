#!/bin/bash
set -e
runas=$1
profile=$2
output=$3

exit_code=$(find $output -maxdepth 1 -mindepth 1 -name "run_*_stderr" | head -n1 | xargs egrep -m1 $'^\tExit status:' | cut -d: -f2)
stdout_file=$(find $output -maxdepth 1 -mindepth 1 -name "run_*_stdout")

num_answers=$(egrep -c "^ANSWER" $stdout_file)
num_inconsistent=$(egrep -c "^INCONSISTENT|UNSATISFIABLE" $stdout_file)
num_unknown=$(egrep -c "^UNKNOWN" $stdout_file)
num_costs=$(egrep -c "^COST" $stdout_file)
num_optimum=$(egrep -c "^OPTIMUM" $stdout_file)

case $exit_code in

    0)

	# s53 either generates UNSATISFIABLE or a list of facts here
	# s47 sometimes generates ANSWER and then a list of facts here
	# s46 sometimes generates nothing in case of timeout


	;;

    1)

	# s37 on memout or timeout
	# s37 does not work on b04

	;;

    10|11|30)

	# most report 10/11 for an ANSWER + facts (+COST)

	# s45, s46 sometimes report 30 plus the only ANSWER + facts
	# otherwise ANSWER + facts + COST + OPTIMUM 

	;;
    
    20)
	# s36 just reports no. for b11
	# s46 reports ANSWER + no. for b11
	# s38 sometimes report comment lines for b12

	;;


    152)

	# s47 report ANSWER + facts + COST (interrupted run: 128 + 24 = 152)

	;;


    *)
	exit 3
	;;

esac

/usr/bin/sudo -u $runas /home/$runas/bin/validate.sh $profile $output $exit_code
cp -av $output -T .
me=$(hostname); for host in lion node{2,3,4}; do test $host = $me || /usr/bin/sudo -u $runas cp -avu $output -T /mnt/$host/$output; done
