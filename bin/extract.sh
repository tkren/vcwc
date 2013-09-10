#!/bin/bash

# logging errors
function logerr() {
    echo "$*" 1>&2
}

# 
input_find_opts="-mindepth 1 -maxdepth 1 -type f"
function sorthead { sort -r | head -n1 ; }

rotate_conf=~/bin/aspexec_rotate.conf

# obtain exit code, etc (possibly with fixing magic)
function repair_output {
  awk -F' ' 'BEGIN { nans=0; nfac=0; nunk=0; ninc=0; ncos=0; nopt=0; split("",cost); ncom=0; ndis=0; }

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

    split("",cost); # portable way to empty cost array

    # we assume non-sparse list of levels
    for(i = NF; i > 1; i--) {
      split($i,a,"@");
      if (a[2]) { j = a[2]; }
      else      { j = NF - i + 1; }
      cost[j] = a[1];
    }

    ncos++; next;
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

      l = length(cost);

      if (l) {
        costlist = cost[l];
        for (j = l-1; j > 0; j--) {
          costlist = costlist "," cost[j];
        }
      } else {
        costlist=0;
      }

      print nunk, nans, nfac, ninc, ncos, costlist, nopt, ncom, ndis;
  }'  $EXEC_STDOUT_FILE | tail -n2 | {

      read answer
      read -a things
      
      declare -i num_unknown=${things[0]}
      declare -i num_answers=${things[1]}
      declare -i num_facts=${things[2]}
      declare -i num_inconsistent=${things[3]}
      declare -i num_costs=${things[4]}
      if [ $num_costs -ne 0 ]; then
	declare cost=${things[5]}
      else
	declare cost="NA"
      fi
      declare -i num_optimum=${things[6]}
      declare -i num_comments=${things[7]}
      declare -i num_discrepancies=${things[8]}

      answer_summary="$(echo "$answer" | cut -c1-20)"
      is_no=0; test "$(echo "$answer_summary" | sed -e 's/^ *//g' -e 's/ *$//g')" = "no." && is_no=1

      if ! ( ( [ $num_inconsistent -gt 0 ] && [ $exit_code -eq 20 ] ) || \
	    ( [ $num_facts -gt 0 ] && [ $num_costs -eq 0 ] && [ $num_optimum -eq 0 ] && [ $exit_code -eq 20 ] && [ $is_no -eq 1 ] ) || \
	    ( [ $num_facts -gt 0 ] && [ $num_costs -gt 0 ] && [ $num_optimum -gt 0 ] && [ $exit_code -eq 30 ] ) || \
	    ( [ $num_facts -gt 0 ] && [ $num_costs -gt 0 ] && [ $num_optimum -eq 0 ] && [ $exit_code -eq 11 ] ) || \
	    ( [ $num_facts -gt 0 ] && [ $num_costs -eq 0 ] && [ $num_optimum -eq 0 ] && [ $exit_code -eq 10 ] ) || \
	    ( [ $num_unknown -gt 0 ] && [ $exit_code -eq 1 ] )
	  )
      then
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

	  let num_discrepancies++

      fi
      
      echo $exit_code $cost $num_discrepancies
  }
}



# Expected input and format:
# $1: directory where to store output of this script
OUTPUT_DIR=$1
# $2: directory of run
EXEC_DIR=$2
# $3: directory of checker
CHECKER_DIR=$3

# ensure trailing slash
OUTPUT_DIR=${OUTPUT_DIR%/}"/"
EXEC_DIR=${EXEC_DIR%/}"/"
CHECKER_DIR=${CHECKER_DIR%/}"/"

# check if arguments are present (TODO needed? check if dir?)
if [ "$OUTPUT_DIR" == "" ] || [ "$EXEC_DIR" == "" ] || [ "$CHECKER_DIR" == "" ];then
exit 3
fi

# TIMESTAMP of statrun.sh
DATEFORMAT="+%F_%T"
DATE0=$(date $DATEFORMAT)

# extract IDs
TRACK_ID=$(echo $OUTPUT_DIR | awk 'BEGIN { FS = "/" } ; {print $(NF-5)}')
BENCHMARK_ID=$(echo $OUTPUT_DIR | awk 'BEGIN { FS = "/" } ; {print $(NF-4)}')
SOLVER_ID=$(echo $OUTPUT_DIR | awk 'BEGIN { FS = "/" } ; {print $(NF-3)}')
INSTANCE_ID=$(echo $OUTPUT_DIR | awk 'BEGIN { FS = "/" } ; {print $(NF-2)}')
RUN_ID=$(echo $OUTPUT_DIR | awk 'BEGIN { FS = "/" } ; {print $(NF-1)}')

# check IDs
echo $TRACK_ID$BENCHMARK_ID$SOLVER_ID$INSTANCE_ID$RUN_ID | grep "t[0-9]*b[0-9]*s[0-9]*i[0-9]*r[0-9]*" -q
if [ $? != 0 ];then
logerr $0 $*
logerr "Error: Could not extract syntactically valid IDs for run from first argument"
logerr "TRACK_ID:"$TRACK_ID
logerr "BENCHMARK_ID:"$BENCHMARK_ID
logerr "SOLVER_ID:"$SOLVER_ID
logerr "INSTANCE_ID:"$INSTANCE_ID
logerr "RUN_ID:"$RUN_ID
exit 3
fi

# retreive file names
EXEC_STDERR_FILE=$(find $EXEC_DIR $input_find_opts -name "run_*_stderr" | sorthead)
EXEC_STDOUT_FILE=$(find $EXEC_DIR $input_find_opts -name "run_*_stdout" | sorthead)
EXEC_RUN_FILE=$(find $EXEC_DIR $input_find_opts -name "run_*_run" | sorthead)
CHECKER_STDERR_FILE=$(find $CHECKER_DIR $input_find_opts -name "validate_*_stderr" | sorthead)
CHECKER_STDOUT_FILE=$(find $CHECKER_DIR $input_find_opts -name "validate_*_stdout" | sorthead)

declare -i exit_code=$(find $EXEC_DIR $input_find_opts -name "run_*_stderr" | sorthead | xargs egrep -m1 $'^\tExit status:' | cut -d: -f2)

if [ ! -e "$CHECKER_STDERR_FILE" ] || [ ! -e "$CHECKER_STDOUT_FILE" ] || [ ! -e "$EXEC_STDERR_FILE" ] || [ ! -e "$EXEC_STDOUT_FILE" ] || [ ! -e "$EXEC_RUN_FILE" ]; then
logerr "Error: Input file missing"
logerr "EXEC_STDERR_FILE: " $EXEC_STDERR_FILE
logerr "EXEC_STDOUT_FILE: " $EXEC_STDOUT_FILE
logerr "EXEC_RUN_FILE: " $EXEC_RUN_FILE
logerr "CHECKER_STDERR_FILE: " $CHECKER_STDERR_FILE
logerr "CHECKER_STDOUT_FILE: " $CHECKER_STDOUT_FILE
exit 3
fi

# check if multiple or no files are present
# NUMBER_OF_FILES=$(echo $EXEC_STDERR_FILE | wc -w)
# if [ $NUMBER_OF_FILES != 1 ];then
# logerr $0 $*
# logerr "Error: multiple or no stderr files present for run"
# logerr "files:"$EXEC_STDERR_FILE
# exit 3
# fi
# 
# NUMBER_OF_FILES=$(echo $EXEC_STDOUT_FILE | wc -w)
# if [ $NUMBER_OF_FILES != 1 ];then
# logerr $0 $*
# logerr "Error: multiple or no stdout files present for run"
# logerr "files:"$EXEC_STDOUT_FILE
# exit 3
# fi
# 
# NUMBER_OF_FILES=$(echo $CHECKER_STDERR_FILE | wc -w)
# if [ $NUMBER_OF_FILES != 1 ];then
# logerr $0 $*
# logerr "Error: multiple or no stderr files present for checker"
# logerr "files:"$CHECKER_STDERR_FILE
# exit 3
# fi
# 
# NUMBER_OF_FILES=$(echo $CHECKER_STDOUT_FILE | wc -w)
# if [ $NUMBER_OF_FILES != 1 ];then
# logerr $0 $*
# logerr "Error: multiple or no stdout files present for checker"
# logerr "files:"$CHECKER_STDOUT_FILE
# exit 3
# fi

# host info
EXEC_HOST=$(grep "^Hostname:" $EXEC_RUN_FILE | cut -f2 -d " ")

# time
EXEC_TIMESTAMP=$(grep "^Timestamp:" $EXEC_RUN_FILE | cut -f2 -d " ")


# obtain fixed output
read -a repaired_things < <(repair_output)

declare -i EC_SOLVER=${repaired_things[0]}
declare COST_SOLVER=${repaired_things[1]}
declare -i DISCREPANCIES_SOLVER=${repaired_things[2]}

# EC solver
# EC_SOLVER=$(cat $EXEC_STDERR_FILE |  awk -F: 'BEGIN { u = 0 } /\tExit/{ut[u]=$2; u++} END {if (u>1) print ut[1]; else print ut[0]}')
# $(grep "Exit status:" $EXEC_STDERR_FILE | cut -f3 -d " ")

# collect all the lines start with "Command being timed"
# TIMING_LINES=$(grep -n "Command being timed" $EXEC_STDERR_FILE | cut -f1 -d ":")
# 
# GROUNDER_LINE_NR=$(echo $TIMING_LINES | cut -f1 -d " ")
# SOLVER_LINE_NR=$(echo $TIMING_LINES | cut -f2 -d " ")
# COMBINED_LINE_NR=$(echo $TIMING_LINES | cut -f3 -d " ")

# EC solver
# EC_SOLVER_LINE_NR=$(($SOLVER_LINE_NR+22))
# EC_SOLVER=$(awk " NR == $EC_SOLVER_LINE_NR " $EXEC_STDERR_FILE | cut -f3 -d " ")


# TIME_GROUNDER_LINE_NR=$(echo $TIMING_LINES | cut -f1 -d " ")
# TIME_SOLVER_LINE_NR=$(echo $TIMING_LINES | cut -f2 -d " ")
# TIME_COMBINED_LINE_NR=$(echo $TIMING_LINES | cut -f3 -d " ")

# times
# TIME_GROUNDER_LINE_NR=$(($GROUNDER_LINE_NR+1))
# TIME_GROUNDER=$(awk " NR == $TIME_GROUNDER_LINE_NR " $EXEC_STDERR_FILE | cut -f4 -d " ")

TIME_GROUNDER=$(cat $EXEC_STDERR_FILE |  awk -F: 'BEGIN { u = 0 } /\tUser/{ut[u]=$2; u++} END {if (u>1) print ut[0]; else print "NA"}')

TIME_SOLVER=$(cat $EXEC_STDERR_FILE |  awk -F: 'BEGIN { u = 0 } /\tUser/{ut[u]=$2; u++} END {if (u>1) print ut[1]; else print ut[0]}')

TIME_COMBINED=$(cat $EXEC_STDERR_FILE |  awk -F: 'BEGIN { u = 0 } /\tUser/{ut[u]=$2; u++} END {if (u>1) print ut[2]; else print ut[0]}')

# TIME_SOLVER_LINE_NR=$(($SOLVER_LINE_NR+1))
# TIME_SOLVER=$(awk " NR == $TIME_SOLVER_LINE_NR " $EXEC_STDERR_FILE | cut -f4 -d " ")

# also record the overall wall clock time for e.g. parallel runs
WALL_TIME_COMBINED_NR=$(($COMBINED_LINE_NR+4))
WALL_TIME_COMBINED=$(awk " NR == $WALL_TIME_COMBINED_NR " $EXEC_STDERR_FILE | cut -f8 -d " ")

WALL_TIME_COMBINED=$(cat $EXEC_STDERR_FILE |  awk 'BEGIN { u = 0 } /\tElapsed/{ut[u]=$8; u++} END {if (u>1) print ut[2]; else print ut[0]}')

# check if we have h:mm:ss.ss or m:ss.ss (3 means former, 2 means latter)
WALL_INCLUDES_HOURS=$(echo $WALL_TIME_COMBINED | sed 's/[^:]//g' | wc -m)

# transform the wall clock time to seconds (e.g. 1:02:16.55 => 3736.55)
WALL_HOURS=0
WALL_MINS=0
WALL_SECS=0
WALL_MSECS=0
if [ "$WALL_INCLUDES_HOURS" == "2" ];then
WALL_MINS=$(echo $WALL_TIME_COMBINED | awk -F: '{print $1}')
WALL_SECS=$(echo $WALL_TIME_COMBINED | awk -F: '{print $2}' | awk -F"." '{print $1}')
WALL_MSECS=$(echo $WALL_TIME_COMBINED | awk -F: '{print $2}' | awk -F"." '{print $2}')
else
WALL_HOURS=$(echo $WALL_TIME_COMBINED | awk -F: '{print $1}')
WALL_MINS=$(echo $WALL_TIME_COMBINED | awk -F: '{print $2}')
WALL_SECS=$(echo $WALL_TIME_COMBINED | awk -F: '{print $3}' | awk -F"." '{print $1}')
WALL_MSECS=$(echo $WALL_TIME_COMBINED | awk -F: '{print $3}' | awk -F"." '{print $2}')
fi

WALL_TIME_COMBINED_CALC=$(( (10#$WALL_HOURS * 3600) + (10#$WALL_MINS * 60) + 10#$WALL_SECS ))
WALL_TIME_COMBINED_IN_SECS=$WALL_TIME_COMBINED_CALC"."$WALL_MSECS

# if the walltime is over 600secs, we definitely have a timeout: force
# INCONSISTENT to INCOMPLETE for witty solvers
if [ $WALL_TIME_COMBINED_CALC -ge 600 ] && [ ${EC_SOLVER} -eq 20 ]; then
    EC_SOLVER=1
    ((DISCREPANCIES_SOLVER++))
fi

# memory
MEM_GROUNDER_LINE_NR=$(($GROUNDER_LINE_NR+9))
MEM_GROUNDER=$(awk " NR == $MEM_GROUNDER_LINE_NR " $EXEC_STDERR_FILE | cut -f6 -d " ")

MEM_GROUNDER=$(cat $EXEC_STDERR_FILE |  awk -F: 'BEGIN { u = 0 } /\tMinor/{ut[u]=$2; u++} END {if (u>1) print ut[0]; else print "NA"}')

MEM_SOLVER=$(cat $EXEC_STDERR_FILE |  awk -F: 'BEGIN { u = 0 } /\tMinor/{ut[u]=$2; u++} END {if (u>1) print ut[1]; else print ut[0]}')

MEM_COMBINED=$(cat $EXEC_STDERR_FILE |  awk -F: 'BEGIN { u = 0 } /\tMinor/{ut[u]=$2; u++} END {if (u>1) print ut[2]; else print ut[0]}')

if echo $MEM_GROUNDER | egrep -q '^[0-9]+$'; then
  MEM_GROUNDER=`expr ${MEM_GROUNDER} \* 4096`
fi


# MEM_SOLVER_LINE_NR=$(($SOLVER_LINE_NR+9))
# MEM_SOLVER=$(awk " NR == $MEM_SOLVER_LINE_NR " $EXEC_STDERR_FILE | cut -f6 -d " ")
if echo $MEM_SOLVER | egrep -q '^[0-9]+$'; then
  MEM_SOLVER=`expr ${MEM_SOLVER} \* 4096`
fi

if echo $MEM_COMBINED | egrep -q '^[0-9]+$'; then
  MEM_COMBINED=`expr ${MEM_COMBINED} \* 4096`
fi

# EC checker
EC_CHECKER=$(egrep -m1 $'^\tExit status:' $CHECKER_STDERR_FILE | cut -f3 -d " ")

# get checker output (should be one of: OK [cost], FAIL, DONTKNOW or WARN)
CHECKER_OUTPUT=$(cat $CHECKER_STDOUT_FILE)

# checker result
CHECKER_RESULT=$(echo $CHECKER_OUTPUT | awk '{print $1}')

# if checker result is WARN, then ensure it has exit code 3 (regardless of its actuall EC)
if [ "$CHECKER_RESULT" == "WARN" ];then
EC_CHECKER=3
fi

# in case checker exited with 3, then we fail
if [ "$EC_CHECKER" == 3 ];then
logerr $0 $*
logerr "Error: checker returned WARN"
exit 3
fi

# parse cost result from solver
# COST_SOLVER=$(grep "^COST" $EXEC_STDOUT_FILE | tail -n 1 | cut -f2- -d " ")

# check if COST is empty
if [ "$COST_SOLVER" == "" ];then 
COST_SOLVER="NA"
fi

# checker cost
COST_CHECKER=$(echo $CHECKER_OUTPUT | \
awk '
{
  split("",cost); # portable way to empty cost array

  # we assume non-sparse list of levels
  for(i=2; i<=NF; i++) {
    split($i,a,"@");
    if (a[2]) { j=a[2]; }
    else      { j=length(cost)+1; }
    cost[j] = a[1];
  }
}

END {
  ORS=","; l = length(cost);
  for (j=l; j > 1; j--) { print cost[j]; }
  ORS="\n"; if (l) { print cost[1]; }
}')

# check if COST is empty
if [ "$COST_CHECKER" == "" ];then 
COST_CHECKER="NA"
fi

# fetch type of problem (query, search, opt)
LAST_ANSWER_LINE_NR=$(grep -n "Answer" $EXEC_STDOUT_FILE | cut -f1 -d ":" | cut -f1 -d " ")
LAST_ANSWER_LINE_NR=$(($LAST_ANSWER_LINE_NR+1))

LAST_ANSWER=$(awk " NR == $LAST_ANSWER_LINE_NR " $EXEC_STDOUT_FILE)

# add this to output accordingly
PROBLEM_TYPE=
if [ "$COST_CHECKER" != "NA" ] || [ "$COST_SOLVER" != "NA" ];then
PROBLEM_TYPE=O #opt
elif [ "$LAST_ANSWER" == "yes." ] || [ "$LAST_ANSWER" == "no." ];then
PROBLEM_TYPE=Q #query
else
PROBLEM_TYPE=S #search
fi

# check if fields are empty (non of them should be empty)
if [ "$DATE0" == "" ] || [ "$EXEC_TIMESTAMP" == "" ] || [ "$EXEC_HOST" == "" ] || [ "$EC_SOLVER" == "" ] || [ "$EC_CHECKER" == "" ] || [ "$TIME_GROUNDER" == "" ] || [ "$MEM_GROUNDER" == "" ] || [ "$TIME_SOLVER" == "" ] || [ "$MEM_SOLVER" == "" ] || [ "$TIME_COMBINED" == "" ] || [ "$MEM_COMBINED" == "" ] || [ "$PROBLEM_TYPE" == "" ] || [ "$DISCREPANCIES_SOLVER" == "" ] || [ "$WALL_TIME_COMBINED_IN_SECS" == "." ];then 
logerr $0 $*
logerr "Error: Not all required fields were found"
logerr "DATE0:"$DATE0
logerr "EXEC_TIMESTAMP:"$EXEC_TIMESTAMP
logerr "EXEC_HOST:"$EXEC_HOST
logerr "EC_SOLVER:"$EC_SOLVER 
logerr "EC_CHECKER:"$EC_CHECKER
logerr "TIME_GROUNDER:"$TIME_GROUNDER 
logerr "MEM_GROUNDER:"$MEM_GROUNDER 
logerr "TIME_SOLVER:"$TIME_SOLVER 
logerr "MEM_SOLVER:"$MEM_SOLVER 
logerr "TIME_COMBINED:"$TIME_COMBINED 
logerr "MEM_COMBINED:"$MEM_COMBINED 
logerr "PROBLEM_TYPE:"$PROBLEM_TYPE 
logerr "WALL_TIME_COMBINED_IN_SECS:"$WALL_TIME_COMBINED_IN_SECS
logerr "DISCREPANCIES_SOLVER:"$DISCREPANCIES_SOLVER
exit 3
fi

# check if OUTPUT_DIR exists
if [ -d "$OUTPUT_DIR" ]; then

(cd $OUTPUT_DIR ; /usr/sbin/logrotate -s /dev/null $rotate_conf)

if [ ! -e $OUTPUT_DIR/stat ]; then
    echo -e "Timestamp-Statrun\tTimestamp-Execution\tHost\tTrack-ID\tBenchmark-ID\tSolver-ID\tInstance-ID\tRun-ID\tExit-Code-Solver\tExit-Code-Checker\tCost-Solver\tCost-Checker\tProblem-Type\tWall-Clock-Time\tTime-Grounder\tMemory-Grounder\tTime-Solver\tMemory-Solver\tTime-Combined\tMemory-Combined\tDiscrepancies-Solver" > $OUTPUT_DIR/stat
fi
# append to stat file in OUTPUT_DIR
echo -e "${DATE0}\t${EXEC_TIMESTAMP}\t${EXEC_HOST}\t${TRACK_ID}\t${BENCHMARK_ID}\t${SOLVER_ID}\t${INSTANCE_ID}\t${RUN_ID}\t${EC_SOLVER}\t${EC_CHECKER}\t${COST_SOLVER}\t${COST_CHECKER}\t$PROBLEM_TYPE\t$WALL_TIME_COMBINED_IN_SECS\t${TIME_GROUNDER}\t${MEM_GROUNDER}\t${TIME_SOLVER}\t${MEM_SOLVER}\t${TIME_COMBINED}\t${MEM_COMBINED}\t${DISCREPANCIES_SOLVER}" >> $OUTPUT_DIR/stat
else
logerr $0 $*
logerr "Error: output directory does not exist."
logerr "OUTPUT_DIR:"$OUTPUT_DIR
exit 3
fi

exit 0
