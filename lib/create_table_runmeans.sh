#!/bin/bash

set -e

track=${1:?'track unset'}

seq -s' ' 1 22

echo -e "Timestamp-Statrun Timestamp-Execution Host Track-ID Benchmark-ID Solver-ID Instance-ID Stats-Discrepancy Exit-Code-Solver Exit-Code-Checker Min-Cost-Solver Max-Cost-Solver Min-Cost-Checker Max-Cost-Checker Problem-Type Wall-Clock-Time Time-Grounder Memory-Grounder Time-Solver Memory-Solver Time-Combined Memory-Combined"

find $track -mindepth 4 -maxdepth 4 -type f -name runmeans.dat | xargs tail -qn1 | sort -k5,8

# pipe into column -t | less -S if you want to pretty-print it
