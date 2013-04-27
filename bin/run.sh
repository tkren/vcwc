#!/bin/bash
#
# run.sh -- runs benchmark suites
#
# Copyright (C) 2011, 2012, 2013 Thomas Krennwallner <tkren@kr.tuwien.ac.at>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

########################################################################
# 								       #
# run.sh PROFILE						       #
# 								       #
# run.sh takes one argument: the path to PROFILE. This file will be    #
# sourced by run.sh and should contain the following shell variables:  #
# 								       #
#  SOLVER: solver id for schroot				       #
#  RUNCMD: absolute path to run call                                   #
#  ARGS: solver arguments					       #
#  INSTANCE: string with instance file(s)			       #
#  LOG: absolute path to log file				       #
#  USESTDIN: set to nonempty string for cat'ing INSTANCE to SOLVER     #
# 								       #
#  MAILTO: email address for log file (default: $(whoami))	       #
#  MAXSIZE: max size of email in bytes (default: 20MiB)		       #
# 								       #
#  TIMEOUT: cpu timeout per process in secs (default: 10mins)	       #
#  WALLCLOCKTIMEOUT: wallclock timeout in secs (default: 0)	       #
#  MEMOUT: memout in kiB (default: 1GiB)			       #
#  MAXFILESIZE: max file size in kiB (default: 10MiB)		       #
# 								       #
# Requires /usr/bin/mutt, /usr/bin/schroot, /usr/bin/time (GNU time),  #
# /usr/bin/timeout (GNU coreutils), ts (moreutils), procinfo, sysstat, #
# and lockfile-progs.						       #
# 								       #
########################################################################

set -p # privileged mode

# first things first: make a clean environment
unalias -a

# allow only group reads
umask 0022

set +e # no errexit, no matter what
set -E # inherit traps
set -T # inherit traps

#

########################
# setup default values #
########################

MAILTO=$(whoami)
MAXSIZE=20971520

RUNCMD=/usr/local/bin/run
TIMEOUT=600
WALLCLOCKTIMEOUT=0
MEMOUT=6291456
MAXFILESIZE=10240

#

mutt=/usr/bin/mutt
schroot="/usr/bin/schroot -d/"
gnutime="/usr/bin/time --verbose"
wallclocklimit="/usr/bin/timeout --preserve-status"

# set to false after stream redirection
startup=1

dateformat="+%F_%T%:z" # --rfc-3339=seconds format with _

# startup time
date0=$(date $dateformat)

#

function logerr() {
    echo "$*" 1>&2
}

#

#######################
# read config profile #
#######################

if [ $# != 1 ]; then
    logerr "Profile argument missing."
    logerr "Usage: $0 PROFILE-FILE"
    exit 1
fi

config="$1"

# read profile file
if [ -e $config ]; then
    source $config
    if [ $? -gt 0 ]; then
	logerr "Cannot source profile \`\`$config''."
	exit 1
    fi
else
    logerr "Cannot read profile \`\`$config'': No such file or directory."
    exit 1
fi

#

#########################
# setup run and schroot #
#########################

# setup run, possibly with wall clock timeout
# we expect a recent /usr/bin/timeout, see http://debbugs.gnu.org/cgi/bugreport.cgi?bug=6308

if [ $WALLCLOCKTIMEOUT != 0 ]; then
    run="$gnutime $schroot -c $SOLVER -- $wallclocklimit -sXCPU -k10 $WALLCLOCKTIMEOUT $RUNCMD $ARGS"
else
    # we give enough time for reaching $TIMEOUT cpu time
    run="$gnutime $schroot -c $SOLVER -- $wallclocklimit -sXCPU -k10 $((2 * $TIMEOUT)) $RUNCMD $ARGS"
fi

#

function cleanup_and_runlogs() {

    if [ $startup == 0 ]; then

        ################################################################
        # kill runsid session, mail logs to $MAILTO and append them to #
        # log spoolfile                                                #
        ################################################################
    
        # first, we kill possible left-over processes in the runsid session
	test -z "$runsid" && logerr "Could not kill RUN session, runsid is empty." || pkill -9 -s $runsid
        # final kill, nothing shall survive
	test -z "$runpid" && logerr "Could not kill RUN session, runpid is empty." || pkill -9 -s $runpid

	# get finish time
	date1=$(date $dateformat)
	echo "Finish: $date1"

        # create attachments
	test ${MEMOUT} -gt 0 && XZ_DEFAULTS=--memlimit=${MEMOUT}kiB
	xz -k $logrun
	head -c $MAXSIZE $logout | xz > $logout.xz
	head -c $MAXSIZE $logerr | xz > $logerr.xz
	head -c $MAXSIZE $logoutts | xz > $logoutts.xz
	head -c $MAXSIZE $logerrts | xz > $logerrts.xz
	
	exec 1>&7 7>&- # Restore stdout
	exec 2>&8 8>&- # Restore stderr

        ##################################
        # we send an email with the logs #
        ##################################

        # here, bastard mutt sometimes sets logerrts.xz to text/plain
        # instead of application/octet-stream
	printf "${HEADER}\nFinish: $date1\n" | \
	    $mutt -e "set copy=no" -s "[BENCHMARK] $retval $SOLVER $ARGS $INSTANCE" \
	    -a $config $logrun.xz $logout.xz $logerr.xz $logoutts.xz $logerrts.xz \
	    -- $MAILTO

        ###############################
        # we log in record-jar format #
        ###############################

        # create lockfile for LOG appending
	#lockfile-create $LOG
	
        # append output, no matter what
	#printf "%%%%  \n" >>$LOG
	#cat $logrun >>$LOG

	# remove LOG lockfile
	#lockfile-remove $LOG

	# remove attachments
	rm -f $logrun.xz $logout.xz $logerr.xz $logoutts.xz $logerrts.xz
	
    fi

    exit
}

# do a clean-up and run the logs for Ctrl-C and exit
trap cleanup_and_runlogs INT EXIT

#

#logdir=$(dirname $LOG)
#logfile=$(basename $LOG)

# FIXME: use condor ID here?
logbase=.  # $(mktemp -d --tmpdir=$logdir ${logfile}.XXXXXXXXXX) # this must be unique
#if [ $? != 0 ]; then
#    logerr "Error: mktemp failed"
#    exit 1
#fi



logout=$logbase/${LOG}_${date0}_stdout
logerr=$logbase/${LOG}_${date0}_stderr
logoutts=$logbase/${LOG}_${date0}_stdout_ts
logerrts=$logbase/${LOG}_${date0}_stderr_ts
logrun=$logbase/${LOG}_${date0}_run

# stdout and stderr in LOG are indented
#function logindent() { sed -e "s/^/ /g" ; }
function logindent() { nl -w1 -bn ; }

# basic log formats
logformatstdout="%F %H:%M:%.S $HOSTNAME $(basename $SOLVER)[$$] STDOUT"
logformatstderr="%F %H:%M:%.S $HOSTNAME $(basename $SOLVER)[$$] STDERR"

#

startup=0
retval=170 # solver run not initiated, most likely the logfile is too big already

#

################################
# Redirect output to log files #
################################

# redirect stdout
exec 7>&1
exec > $logrun

# redirect stderr
exec 8>&2
exec 2> $logerr

#####################################
# log basic environment information #
# 				    #
# we log in record-jar format	    #
#####################################

# header of log entries and mail bodies
HEADER=`cat <<EOF
Instance: $INSTANCE
Timestamp: $date0
Hostname: $HOSTNAME
uname: $(uname -a)
Command: $run
EOF`

echo "$HEADER"

echo "logbase: $logbase"
echo "logrun: $logrun"
echo "logout: $logout"
echo "logerr: $logerr"
echo "logoutts: $logoutts"
echo "logerrts: $logerrts"

# hardware info

echo "arch: $(arch)"

echo "numactl --hardware:"
numactl --hardware | logindent

echo "numactl --show:"
numactl -s | logindent

# system accounting

echo "procinfo -r:"
procinfo -r | logindent

echo "vmstat -SM:"
vmstat -SM | logindent

echo "mpstat:"
mpstat | logindent

# user info

echo "id: $(id)"
echo "who -m: $(who -m)"

# shell environment

echo "Environment (empty during run):"
printenv | logindent

echo "Aliases:"
alias | logindent

echo "umask: $(umask)"

echo "pwd: $(pwd)"

# Condor setup

echo "_CONDOR_MACHINE_AD:"
test -e "${_CONDOR_MACHINE_AD}" && { cat ${_CONDOR_MACHINE_AD} | logindent ; }

echo "_CONDOR_JOB_AD:"
test -e "${_CONDOR_MACHINE_AD}" && { cat ${_CONDOR_JOB_AD} | logindent ; }

# limits

echo "/proc/self/cgroup:"
cat /proc/self/cgroup | logindent

echo "ulimit -a:"
ulimit -a | logindent

#

# restore stdout for RUN
exec 1>&7 7>&-

# restore stderr for RUN
exec 2>&8 8>&-

# redirect stdout for timestamped RUN
exec 7>&1
exec > $logoutts

# redirect stderr for timestamped RUN
exec 8>&2
exec 2> $logerrts

pidfile=$logbase/pid
mkfifo $pidfile

#

########################################################################
# now run the solver in its own session				       #
# 								       #
# the assumption is here that ulimit/timeout will kill the process     #
# eventually and the root command is time, which will be the session   #
# leader                                                               #
########################################################################

{
    set -o pipefail # we need exit code of RUN
    {
	(
            ##########################################
            # set up the limits of all children here #
            ##########################################

	    # turn off core files
	    ulimit -c 0
	    if [ $? != 0 ]; then
		logerr "Error: ulimit -c 0 failed"
		exit 128
	    fi

            # setup file size limit, process receives SIGXFSZ upon too
            # large files
	    if [ $MAXFILESIZE != 0 ]; then
		ulimit -S -f $MAXFILESIZE
		if [ $? != 0 ]; then
		    logerr "Error: ulimit -S -f $MAXFILESIZE failed"
		    exit 128
		fi
	    fi

            # setup memory limit, process receives SIGSEGV upon too
            # much memory consumption
	    if [ $MEMOUT != 0 ]; then
		ulimit -S -v $MEMOUT
		if [ $? != 0 ]; then
		    logerr "Error: ulimit -S -v $MEMOUT failed"
		    exit 128
		fi
	    fi

            # setup timeout with 10 sec additional time before we
            # slaughter the process really hard with SIGTERM
	    if [ $TIMEOUT != 0 ]; then

		# sends SIGXCPU after TIMEOUT secs, then every second
		# before hard limit
		ulimit -S -t $TIMEOUT
		if [ $? != 0 ]; then
		    logerr "Error : ulimit -S -t $TIMEOUT failed"
		    exit 128
		fi

		# sends SIGTERM after TIMEOUT+10 secs
		ulimit -H -t $((TIMEOUT+10))
		if [ $? != 0 ]; then
		    logerr "Error : ulimit -H -t $TIMEOUT failed"
		    exit 128
		fi

	    fi

            # run RUN with empty environment vars in a new session on
            # only k cpus on one single mem
	    
	    if [ -z "$USESTDIN" ]; then
		setsid env -i $run $INSTANCE 3>&- 4>&- &
	    else
		setsid env -i $run < <(exec cat $INSTANCE) 3>&- 4>&- &
	    fi
	    
            # get process id of RUN
	    runpid=$!
	    
            # we kill with runpid if runpid quits before we get runsid
	    runsid=$(ps --no-headers -o sid -p $runpid)

	    # communicate PIDs to the mothership
	    exec 5<> $pidfile
	    echo $runpid $runsid >&5

            # we assume that runpid will be killed by ulimit/timeout
	    # eventually, exit code is the one of RUN (see pipefile
	    # shopt above)
	    wait $runpid
	    
	) | tee $logout | ts "$logformatstdout" 1>&3 2>&4 3>&- 4>&-
	
    } 2>&1 | tee -a $logerr | ts "$logformatstderr" 1>&2 3>&- 4>&-
    
} 3>&1 4>&2 &

# get pid of the redirection behemoth above
lastpid=$!

# retrieve process and session id of RUN
exec 6<> $pidfile
read runpid runsid <&6
exec 5>&- 6>&-

# wait until RUN and pipe processes quit
wait $lastpid
retval=$? # get exit status of RUN

# remove pipe
rm -f $pidfile

# close stdout of RUN
exec 1>&7 7>&-
# close stderr of RUN
exec 2>&8 8>&-

#

# FIXME race condition: what happens if we segfault here, because we
# reached the limit of some logfile

# redirect stdout: append output, no matter what
exec 7>&1
exec >> $logrun

# redirect stderr: append output, no matter what
exec 8>&2
exec 2>> $logerr

########################################################
# log process ids, exit code, and some statistics      #
########################################################

# add various process ids of the run
echo "PID: $runpid"
echo "PPID: $$"
echo "SID: $runsid"
echo "exit code: $retval"

# log CPU time and wallclock time
echo "Timing:"
egrep "Command|(User|System|Elapsed).*time" $logerr | logindent

# for measuring page faults, see https://lwn.net/Articles/257209/ and
# http://article.gmane.org/gmane.comp.version-control.git/72001
echo "Memory usage:"
egrep "Command|Maximum resident set size|page faults" $logerr | logindent

# exit and cleanup
exit 0
