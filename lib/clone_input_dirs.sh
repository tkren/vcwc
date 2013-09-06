#!/bin/bash

source=/mnt/lion/home
target=/home

dirs="$source/aspcomp/{instances,benchmarks,participants,profiles}%$target/aspcomp \
	$source/aspexec/bin%$target/aspexec \
	$source/aspck/bin%$target/aspck \
	$source/aspstat/bin%$target/aspstat \
	$source/aspstat/profiles/t0{1..3}%$target/aspstat/profiles"

for p in $(eval echo $dirs); do

	declare -a pair=( $(tr '%' ' ' <<< "$p") )
	test -d ${pair[0]} && sudo cp --backup=t -avui ${pair[*]}

done
