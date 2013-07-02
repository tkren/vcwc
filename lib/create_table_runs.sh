#!/bin/bash

set -e

track=${1:?'track unset'}

seq -s' ' 1 21

echo -e "Timestamp-Statrun\tTimestamp-Execution\tHost\tTrack-ID\tBenchmark-ID\tSolver-ID\tInstance-ID\tRun-ID\tExit-Code-Solver\tExit-Code-Checker\tCost-Solver\tCost-C\
hecker\tProblem-Type\tWall-Clock-Time\tTime-Grounder\tMemory-Grounder\tTime-Solver\tMemory-Solver\tTime-Combined\tMemory-Combined\tDiscrepancies-Solver"

find $track -mindepth 5 -maxdepth 5 -type f -name stat | xargs tail -qn1 | sort -k5,8

# pipe into column -t | less -S if you want to pretty-print it
