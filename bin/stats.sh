#!/bin/bash

# argument $1 is the path to the directory containing the instances
path=$1

rotate_conf=~/bin/aspexec_rotate.conf

exclude_file=BROKEN
stat_file=stat

instances_file=instances.dat
summary_file=summary.dat
boxplot_file=boxplot.pdf
textable_file=summary.tex
runmeans_file=runmeans.dat

# output is as in 20130204_TUmeeting_minutes.txt, but with a discrepancy flag instead of run_id.
# this flag is 0 if the solver and checker output was the same for all runs, and 1 otherwise
instance_means="
t <- read.table('stdin',header=FALSE,as.is=TRUE);

# 1. output columns 1,2,3,4,5,6,7 (they are the same for all runs)
output <- c(t[1,1],t[1,2],t[1,3],t[1,4],t[1,5],t[1,6],t[1,7]);

# 2. do NOT output column 8 (run ID)

# 3. check if all runs have 1. no simultanous SAT _and_ UNSAT answers by the solver, and 2. the same checker output for all runs
solverOutputs <- t[c(9)][,1];
checkerOutputs <- t[c(10)][,1];
solverOk <- ! ( ( (10 %in% solverOutputs) || (11 %in% solverOutputs) || (30 %in% solverOutputs) ) && (20 %in% solverOutputs) );

# aggregate checker output
aggCheckerOutput <- 3
if (0 %in% checkerOutputs && !(1 %in% checkerOutputs) && !(2 %in% checkerOutputs)){
	aggCheckerOutput <- 0
}
if (1 %in% checkerOutputs){
	aggCheckerOutput <- 1
}
if (0 %in% checkerOutputs && 2 %in% checkerOutputs){
	aggCheckerOutput <- 1
}
if (2 %in% checkerOutputs && 124 %in% checkerOutputs){
	aggCheckerOutput <- 1
}
if (!(0 %in% checkerOutputs) && !(1 %in% checkerOutputs) && !(2 %in% checkerOutputs) && 124 %in% checkerOutputs){
	aggCheckerOutput <- 124
}
if (!(0 %in% checkerOutputs) && !(1 %in% checkerOutputs) && !(124 %in% checkerOutputs) && 2 %in% checkerOutputs){
	aggCheckerOutput <- NA
}

if (solverOk){
  # if yes: output 0 (discrepancy flag) and original solver and checker output
	output <- append(output, 0);
	output <- append(output, (unique(solverOutputs))[1]);
	output <- append(output, aggCheckerOutput);
}else{
  # if no: output 1 (discrepancy flag), followed by 1, 1
	output <- append(output, 1)
	output <- append(output, 1)
	output <- append(output, 1)
}

# 4. output minimum and maximum of columns 11 and 12
minCosts <- sapply(t[c(11,12)],min,na.rm=TRUE);
maxCosts <- sapply(t[c(11,12)],max,na.rm=TRUE);
output <- append(output, minCosts[1:2])
output <- append(output, maxCosts[1:2])

# 5. output column 13 (it is the same for all runs)
output <- append(output, c(t[1,13]));

# 6. compute means of columns 14,15,16,17,18,19,20
means <- sapply(t[c(14,15,16,17,18,19,20)],mean,na.rm=TRUE);
output <- append(output, means[1:7])
write(output,stdout(),22);"

summary_statistics="
t <- read.table('stdin',header=FALSE,as.is=TRUE);
t <- t[c(17,18,19,20)];
colnames(t) <- c('timegrounder', 'memorygrounder', 'timesolver', 'memorysolver');

# replace timeouts and memouts with NaN and omit them
t <- within(t, timegrounder <- replace(timegrounder, timegrounder > 600, NaN));
t <- within(t, memorygrounder <- replace(memorygrounder, memorygrounder > 6*2^30, NaN));
t <- within(t, timesolver <- replace(timesolver, timesolver > 600, NaN));
t <- within(t, memorysolver <- replace(memorysolver, memorysolver > 6*2^30, NaN));

# remove NA columns
t <- t[,colSums(is.na(t))<nrow(t)]
t <- na.omit(t);

pdf(file='$path/$boxplot_file');
boxplot(t);
graphics.off();

mins <- sapply(t,min);
qu <- sapply(t,quantile);
meds <- sapply(t,median);
means <- sapply(t,mean);
maxs <- sapply(t,max);

summary <- rbind(mins, qu[2,], meds, means, qu[4,], maxs);
colnames(summary) <- colnames(t);
rownames(summary) <- c('Min','25Qu','Med','Mean','75Qu','Max');

write.table(summary, file='$path/$summary_file');
suppressMessages(library(xtable));
print(xtable(summary), file='$path/$textable_file');
"

# rotate the statistics and plots
(cd $path; /usr/sbin/logrotate -s /dev/null $rotate_conf)

for d in $(find $path -mindepth 1 -maxdepth 1 -type d); do

    # rotate the statistics and plots
    (cd $d; /usr/sbin/logrotate -s /dev/null $rotate_conf)

    # (1) append to instances_file: the last line of instances that
    # have no exclude_file, and the last line of instances with
    # exclude_file s.t. last two fields (time + memory) are replaced
    # by NA
    #
    # (2) stdout: means of all runs ignoring NA values

    {
	{
	    {
		
		find $d -mindepth 1 -maxdepth 1 -type d \
		    \( -exec test -f {}/$stat_file -a ! -f {}/$exclude_file \; \
		       -fprintf /dev/stdout "%h/%f/$stat_file\0" \) -o \
		    \( -exec test -f {}/$stat_file -a -f {}/$exclude_file \; \
		       -fprintf /dev/stderr "%h/%f/$stat_file\0" \)
		
            } | xargs -0 tail -qn1 1>&3 2>&4 3>&- 4>&-
	    
	} 2>&1 | xargs -0 tail -qn1 | awk '{$NF=$($NF-1)="NA"}1' 3>&- 4>&- #1>&2 3>&- 4>&-
	
    } 3>&1 4>&2 | tee -a $path/$instances_file | Rscript <(echo "$instance_means") | tee -a $d/$runmeans_file

done | Rscript <(echo "$summary_statistics") # compute summary statistics
