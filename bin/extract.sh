#!/bin/bash

# logging errors
function logerr() {
    echo "$*" 1>&2
}

# Expected input and format:
# $1: directory where to store output of this script
OUTPUT_DIR=$1
# $2: directory of run
EXEC_DIR=$2
# $3: directory of checker
CHECKER_DIR=$3

# check if arguments are present (TODO needed? check if dir?)
if [ "$OUTPUT_DIR" == "" ] || [ "$EXEC_DIR" == "" ] || [ "$CHECKER_DIR" == "" ];then
exit 1
fi

# TIMESTAMP of statrun.sh
DATEFORMAT="+%F_%T"
DATE0=$(date $DATEFORMAT)

# extract IDs
TRACK_ID=$(echo $OUTPUT_DIR | cut -f 4 -d '/')
BENCHMARK_ID=$(echo $OUTPUT_DIR | cut -f 5 -d '/')
SOLVER_ID=$(echo $OUTPUT_DIR | cut -f 6 -d '/')
INSTANCE_ID=$(echo $OUTPUT_DIR | cut -f 7 -d '/')
RUN_ID=$(echo $OUTPUT_DIR | cut -f 8 -d '/')

# check if fields are empty
if [ "$TRACK_ID" == "" ] || [ "$BENCHMARK_ID" == "" ] || [ "$SOLVER_ID" == "" ] || [ "$INSTANCE_ID" == "" ] || [ "$RUN_ID" == "" ];then 
logerr $0 $*
logerr "Error: Could not extract all IDs for run from first argument"
logerr "TRACK_ID:"$TRACK_I$INSTANCE_IDD
logerr "BENCHMARK_ID:"$BENCHMARK_ID
logerr "SOLVER_ID:"$SOLVER_ID
logerr "INSTANCE_ID:"$INSTANCE_ID
logerr "RUN_ID:"$RUN_ID
exit 1
fi

# retreive file names
EXEC_STDERR_FILE=$(find $EXEC_DIR -maxdepth 1 -mindepth 1 -type f -name "*_stderr")
EXEC_STDOUT_FILE=$(find $EXEC_DIR -maxdepth 1 -mindepth 1 -type f -name "*_stdout")
EXEC_RUN_FILE=$(find $EXEC_DIR -maxdepth 1 -mindepth 1 -type f -name "*_run")
CHECKER_STDERR_FILE=$(find $CHECKER_DIR -maxdepth 1 -mindepth 1 -type f -name "*_stderr")
CHECKER_STDOUT_FILE=$(find $CHECKER_DIR -maxdepth 1 -mindepth 1 -type f -name "*_stdout")

# check if multiple or no files are present
NUMBER_OF_FILES=$(echo $EXEC_STDERR_FILE | wc -w)
if [ $NUMBER_OF_FILES != 1 ];then
logerr $0 $*
logerr "Error: multiple or no stderr files present for run"
logerr "files:"$EXEC_STDERR_FILE
exit 1
fi

NUMBER_OF_FILES=$(echo $EXEC_STDOUT_FILE | wc -w)
if [ $NUMBER_OF_FILES != 1 ];then
logerr $0 $*
logerr "Error: multiple or no stdout files present for run"
logerr "files:"$EXEC_STDOUT_FILE
exit 1
fi

NUMBER_OF_FILES=$(echo $CHECKER_STDERR_FILE | wc -w)
if [ $NUMBER_OF_FILES != 1 ];then
logerr $0 $*
logerr "Error: multiple or no stderr files present for checker"
logerr "files:"$CHECKER_STDERR_FILE
exit 1
fi

NUMBER_OF_FILES=$(echo $CHECKER_STDOUT_FILE | wc -w)
if [ $NUMBER_OF_FILES != 1 ];then
logerr $0 $*
logerr "Error: multiple or no stdout files present for checker"
logerr "files:"$CHECKER_STDOUT_FILE
exit 1
fi

# host info
EXEC_HOST=$(grep "^Hostname:" $EXEC_RUN_FILE | cut -f2 -d " ")

# time
EXEC_TIMESTAMP=$(grep "^Timestamp:" $EXEC_RUN_FILE | cut -f2 -d " ")

# EC solver
EC_SOLVER=$(grep "^exit code:" $EXEC_STDERR_FILE | cut -f3 -d " ")

# collect all the lines start with "Command being timed"
TIMING_LINES=$(grep -n "Command being timed" $EXEC_STDERR_FILE | cut -f1 -d ":")

GROUNDER_LINE_NR=$(echo $TIMING_LINES | cut -f1 -d " ")
SOLVER_LINE_NR=$(echo $TIMING_LINES | cut -f2 -d " ")
COMBINED_LINE_NR=$(echo $TIMING_LINES | cut -f3 -d " ")

# EC solver
EC_SOLVER_LINE_NR=$(($SOLVER_LINE_NR+22))
EC_SOLVER=$(awk " NR == $EC_SOLVER_LINE_NR " $EXEC_STDERR_FILE | cut -f3 -d " ")


# TIME_GROUNDER_LINE_NR=$(echo $TIMING_LINES | cut -f1 -d " ")
# TIME_SOLVER_LINE_NR=$(echo $TIMING_LINES | cut -f2 -d " ")
# TIME_COMBINED_LINE_NR=$(echo $TIMING_LINES | cut -f3 -d " ")

# times
TIME_GROUNDER_LINE_NR=$(($GROUNDER_LINE_NR+1))
TIME_GROUNDER=$(awk " NR == $TIME_GROUNDER_LINE_NR " $EXEC_STDERR_FILE | cut -f4 -d " ")

TIME_SOLVER_LINE_NR=$(($SOLVER_LINE_NR+1))
TIME_SOLVER=$(awk " NR == $TIME_SOLVER_LINE_NR " $EXEC_STDERR_FILE | cut -f4 -d " ")

# also record the overall wall clock time for e.g. parallel runs
WALL_TIME_COMBINED_NR=$(($COMBINED_LINE_NR+4))
WALL_TIME_COMBINED=$(awk " NR == $WALL_TIME_COMBINED_NR " $EXEC_STDERR_FILE | cut -f8 -d " ")

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

WALL_TIME_COMBINED_CALC=$(( ($WALL_HOURS * 3600) + ($WALL_MINS * 60) + $WALL_SECS ))
WALL_TIME_COMBINED_IN_SECS=$WALL_TIME_COMBINED_CALC"."$WALL_MSECS

# the line with Maximum resident set size (kbytes):
# TODO check whether it is this line
# TODO what exactly to do with these numbers?
MEM_GROUNDER_LINE_NR=$(($GROUNDER_LINE_NR+9))
MEM_GROUNDER=$(awk " NR == $MEM_GROUNDER_LINE_NR " $EXEC_STDERR_FILE | cut -f6 -d " ")

MEM_SOLVER_LINE_NR=$(($SOLVER_LINE_NR+9))
MEM_SOLVER=$(awk " NR == $MEM_SOLVER_LINE_NR " $EXEC_STDERR_FILE | cut -f6 -d " ")

# EC checker
EC_CHECKER=$(grep "^exit code:" $CHECKER_STDERR_FILE | cut -f3 -d " ")

# get checker output (should be one of: OK [cost], FAIL, DONTKNOW or WARN)
CHECKER_OUTPUT=$(cat $CHECKER_STDOUT_FILE)

# checker result
CHECKER_RESULT=$(echo $CHECKER_OUTPUT | awk '{print $1}')

# if checker result is WARN, then ensure it has exit code 3 (regardless of its actuall EC)
if [ "$CHECKER_RESULT" == "WARN" ];then
EC_CHECKER=3
fi

# in case checker exited with 3, then we fail
if [ $EC_CHECKER == 3 ];then
logerr $0 $*
logerr "Error: checker returned WARN"
exit 1
fi

# parse cost result from solver
COST_SOLVER=$(grep "^COST" $EXEC_STDOUT_FILE | tail -n 1 | cut -f2- -d " ")

# check if COST is empty
if [ "$COST_SOLVER" == "" ];then 
COST_SOLVER=NA
fi

# checker cost
COST_CHECKER=$(echo $CHECKER_OUTPUT | awk '{print $2}')

# check if COST is empty
if [ "$COST_CHECKER" == "" ];then 
COST_CHECKER=NA
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
if [ "$DATE0" == "" ] || [ "$EXEC_TIMESTAMP" == "" ] || [ "$EXEC_HOST" == "" ] || [ "$EC_SOLVER" == "" ] || [ "$EC_CHECKER" == "" ] || [ "$TIME_GROUNDER" == "" ] || [ "$MEM_GROUNDER" == "" ] || [ "$TIME_SOLVER" == "" ] || [ "$MEM_SOLVER" == "" ] || [ "$PROBLEM_TYPE" == "" ] || [ "$WALL_TIME_COMBINED_IN_SECS" == "." ];then 
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
logerr "PROBLEM_TYPE:"$PROBLEM_TYPE 
logerr "WALL_TIME_COMBINED_IN_SECS:"$WALL_TIME_COMBINED_IN_SECS
exit 1
fi

# check if OUTPUT_DIR exists
if [ -d "$OUTPUT_DIR" ]; then
# append to stat file in OUTPUT_DIR
echo -e "${DATE0}\t${EXEC_TIMESTAMP}\t${EXEC_HOST}\t${TRACK_ID}\t${BENCHMARK_ID}\t${SOLVER_ID}\t${INSTANCE_ID}\t${RUN_ID}\t${EC_SOLVER}\t${EC_CHECKER}\t\"${COST_SOLVER}\"\t\"${COST_CHECKER}\"\t$PROBLEM_TYPE\t$WALL_TIME_COMBINED_IN_SECS\t${TIME_GROUNDER}\t${MEM_GROUNDER}\t${TIME_SOLVER}\t${MEM_SOLVER}" >> $OUTPUT_DIR/stat
else
logerr $0 $*
logerr "Error: output directory does not exist."
logerr "OUTPUT_DIR:"$OUTPUT_DIR
exit 1
fi

exit 0