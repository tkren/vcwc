#!/bin/bash
#
# condor job wrapper script: setup time, memory, and file limits, and
# assign slots to Linux control groups
#
# Copyright 2008 Red Hat, Inc.
# Copyright 2011,2013 Thomas Krennwallner <tkren@kr.tuwien.ac.at>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# See documentation for USER_JOB_WRAPPER in
# http://research.cs.wisc.edu/htcondor/manual/v7.8/3_3Configuration.html#SECTION004313000000000000000 
# http://research.cs.wisc.edu/htcondor/manual/v7.8/3_12Setting_Up.html#SECTION0041213000000000000000
# http://research.cs.wisc.edu/htcondor/manual/v7.8/2_5Submitting_Job.html
#

function logdebug() { if [ -n "$DEBUG" ]; then echo "$(date) $(hostname): $*" >&2 ; fi }
function bailout() { echo "$*" > $_CONDOR_WRAPPER_ERROR_FILE ; exit 1 ; }

logdebug Setting up job $@

#
# file $_CONDOR_MACHINE_AD contains the current limitations
#

declare -i memory=0
declare -i cpus=0
declare -i disk=0
declare -i slotid=0

if [ $_CONDOR_MACHINE_AD != "" ]; then
    old_ifs="$IFS"
    IFS="" # turn of field separator

    vars=`egrep '^(Memory|Cpus|Disk|SlotID)' $_CONDOR_MACHINE_AD`

    memory=$((`echo $vars | egrep '^Memory' | cut -d ' ' -f 3` * 1024))
    cpus=`echo $vars | egrep '^Cpus' | cut -d ' ' -f 3`
    disk=`echo $vars | egrep '^Disk' | cut -d ' ' -f 3`
    slotid=`echo $vars | egrep '^SlotID' | cut -d ' ' -f 3`

    IFS="$old_ifs"
    
    # setup memory limit
    ulimit -v $memory
    if [ $? != 0 ] || [ $memory = 0 ]; then
        bailout "Error: ulimit -v $memory failed"
    fi

    # setup filesize limit
    ulimit -f $disk
    if [ $? != 0 ]; then
        bailout "Error: ulimit -f $disk failed"
    fi
else
    bailout "Failed to setup environment: _CONDOR_MACHINE_AD($_CONDOR_MACHINE_AD) unusable."
fi

# have a look at the env-vars, aliases, etc.
if [ -n "$DEBUG" ]; then
    ( cat $_CONDOR_MACHINE_AD ; export ; alias ; ulimit -a ) | sed 's/^\(.*\)/\ \ \1/g' >&2
fi 

# execute this command
RUN="$@"

# run under timeout, and SIGKILL after $timelimit+10 secs
if [ -n "$timelimit" ]; then
    RUN="/usr/bin/timeout -k 10 $timelimit $RUN"
fi

# setup cpu affinity and bind memory to cpunode
#
# we assume that the slot requirements correspond to cgroup setup
#
# slot[1..4] -> cgroup cpunode[0..3]/singlecore
# slot[5..8] -> cgroup cpunode[0..3]
# slot9_[1..24] -> do nothing, dynamic slot

if [[ $slotid > 0 && $slotid < 9 ]]; then
    CGROUP="cpuset,memory:cpunode$(( (${slotid} - 1) % 4 ))"

    if [[ $slotid > 0 && $slotid < 5 ]]; then
	CGROUP="${CGROUP}/singlecore"
    fi

    # Attention: the cgroup hierarchy must be user or group-writable
    # for the calling user
    RUN="/usr/bin/cgexec -g $CGROUP $RUN"
fi


logdebug Running job $RUN on slot $slotid with $cpus CPUs, $memory kB virtual memory, $disk kB filesize, for at most $timelimit secs wall time

exec $RUN
error=$?
bailout "Failed to exec($error): $RUN"
