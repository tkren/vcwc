#!/bin/bash

source=/mnt/lion/home
target=/home

dirs="$source/aspcomp/{instances,benchmarks,participants,profiles}%$target/aspcomp"

for p in $(eval echo $dirs); do

	declare -a pair=( $(tr '%' ' ' <<< "$p") )
	test -d ${pair[0]} && sudo cp --backup=t -avui ${pair[*]}

done
