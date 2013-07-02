#!/bin/bash

source=/mnt/lion/home
target=/home

list="$source/aspcomp/{instances,benchmarks,participants,profiles}%$target/aspcomp \
	$source/aspstat/{t0{1..3},bin,profiles}%$target/aspstat \
	$source/aspexec/{t0{1..3},bin}%$target/aspexec \
	$source/aspck/{t0{1..3},bin}%$target/aspck"

for p in $(eval echo $list); do

	declare -a pair=( $(echo $p | tr "%" " ") )
	test -d ${pair[0]} && sudo cp -avu ${pair[*]}

done
