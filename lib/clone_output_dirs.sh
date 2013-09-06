#!/bin/bash

source=/mnt/lion/home
target=/home

dirs="$source/aspstat/t0{1..3}%$target/aspstat \
	$source/aspexec/t0{1..3}%$target/aspexec \
	$source/aspck/t0{1..3}%$target/aspck"

for p in $(eval echo $dirs); do

	declare -a pair=( $(tr '%' ' ' <<< "$p") )
	test -d ${pair[0]} && sudo cp --backup=t -avui ${pair[*]}

done
