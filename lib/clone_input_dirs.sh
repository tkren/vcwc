#!/bin/bash

source=/mnt/lion/home
target=/home

dirs="$source/aspcomp/{instances,benchmarks,participants,profiles}%$target/aspcomp \
	$source/aspexec/bin%$target/aspexec \
	$source/aspck/bin%$target/aspck \
	$source/aspstat/{bin,profiles/t{0..3}}%$target/aspstat"

for p in $(eval echo $dirs); do

	declare -a pair=( $(tr '%' ' ' <<< "$p") )
	test -d ${pair[0]} && sudo cp --backup=t -avui ${pair[*]}

done
