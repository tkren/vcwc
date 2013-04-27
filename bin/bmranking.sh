#!/bin/bash
# argument $1 is the path to the directory containing the instances
#path=$1
#rotate_conf=$path/aspexec_rotate.conf
#exclude_file=BROKEN
#stat_file=stat
#runmeans_file=$path/runmeans.dat

# argument $1 is the path to the directory containing the instances
path=$1

# TODO not taken into account for this script yet
exclude_file=BROKEN

# (1)
 min_costs="
 t <- read.table('stdin',header=FALSE,as.is=TRUE);
 
 # ignore costs from failed solvers
#  t <- within(t, V11 <- replace(V11, V10 != 0, NaN));
#  t <- within(t, V12 <- replace(V12, V10 != 0, NaN));
 
 # compute minimum costs of all remaining solvers
 minCosts <- sapply(t[c(11,12)],min,na.rm=TRUE);
 
 write(minCosts,stdout(),18);"

# for all solvers
# for s in $(find $path -mindepth 1 -maxdepth 1 -type d); do
# 
# 	# for all instances
# 	for d in $(find $s -mindepth 1 -maxdepth 1 -type d); do
# 		inst=`basename $d`
# 
# 		# get output of all solvers for this instance
# 		inp=""
# 		for sopt in $(find $path -mindepth 1 -maxdepth 1 -type d); do
# 			row=`cat $sopt/$inst/runmeans.dat | tail -n1`
# 			inp=$(echo "$inp\n$row")
# 		done
# 		echo -e $inp | Rscript <(echo "$min_costs") | tee -a $d/opt.dat
# 	done
# done

# minCost for all solvers
for s in $(find $path -mindepth 1 -maxdepth 1 -type d); do

	# for all instances
 	for d in $(find $s -mindepth 1 -maxdepth 1 -type d); do
 		inst=`basename $d`
 
 		# get output of all solvers for this instance
 		minp=""
 		for sopt in $(find $path -mindepth 1 -maxdepth 1 -type d); do
 			row=`cat $sopt/$inst/runmeans.dat | tail -n1`
 			minp=$(echo "$minp\n$row")
 		done
 		echo -e $minp | Rscript <(echo "$min_costs") >> $d/opt.dat
 	done
 done


bm_rscipt="
#### global variables
instances <- read.table('stdin',header=FALSE,as.is=TRUE);
#write.table(instances,stdout());

gamma <- 1-(log(11)/log(611));
alpha <- 50;
s <- 10;
tout <- 600;
N <- length(instances\$V1); 
diskrepanz <- 0;

## CalculateScore - main function for score calculation
CalculateScore <- function(instances){
  score <- 0;
  if(instances[1,15] == \"O\"){
    score <- ScoreOPT(instances);
    if(score == -1){
      diskrepanz <- 1;
      score <- 0;
    }
  } else { # Else: Search or Query Problem
    score <- ScoreSQ(instances);
    if(score == -1){
      diskrepanz <- 1;
      score <- 0;
    }
  }
  score <- round(score);
  # host | track_id | solver_id | bm_id | diskrepanz | score
  output <- data.frame(instances[1,3],instances[1,4],instances[1,6],instances[1,5],diskrepanz,score);
  return (output);
}

# instances dataset:
# V1 timest.stat V2 timestamp V3 host
# V4 track_id V5 bm_id V6 solver_id V7 instance_id V8 diskrepanz
# V9 Solver Exit Code      | 1 / 10 / 11 / 20 / 30 / 128     |
# V10 Checker Exit Code     | 0 / 1 / 2 / 3                   |
# V11 Min Cost (solver)         | cost reported by solver, or NA  |
# V12 Min Cost (checker)        | cost reported by checker, or NA |
# V13 Max Cost (solver)         | cost reported by solver, or NA  |
# V14 Max Cost (checker)        | cost reported by checker, or NA |
# V15 Problem type          | O(pt), Q(uery) or S(earcH)      |
# V16 Wall Clock time       
# V17 Runtime grounder      
# V18 Memory usage grounder 
# V19 Runtime solver        
# V20 Memory usage solver   

ScoreSQ <- function(instances){
  lengthNA <- length(instances\$V10[instances\$V10 == \"NaN\"]);
  length1 <- length(instances\$V10[instances\$V10 == 1]);

  # if checker exit code is 1
  if((length1-lengthNA) > 0 ){
    # TODO: EXIT CODE 1
	return(-1);
  }
  ssolve <- Ssolve(instances);
  stime <- Stime(instances);
  return(ssolve + stime);
}

ScoreOPT <- function(instances){
  lengthNA <- length(instances\$V10[instances\$V10 == \"NaN\"]);
  length1 <- length(instances\$V10[instances\$V10 == 1]);

  # if checker exit code is 1
  if((length1-lengthNA) > 0 ){
	# TODO: EXIT CODE 1
	return(-1);
  }
 
  sopt <- Sopt(instances);
  stime <- Stime(instances);
  return(sopt + stime);
}

Ssolve <- function(instances){
  lengthNA <- length(instances\$V9[instances\$V9 == \"NaN\"]);
  length128 <- length(instances\$V9[instances\$V9 == 128]);
  lengthRT <- length(instances\$V15[instances\$V17+instances\$V19 > 600]);
  length128 <- length128-lengthNA;
  Ni <- N - length128 - lengthNA - lengthRT;
  ssolve <- alpha * (Ni/N)
  return(ssolve);
}

Sopt <- function(instances){
  linst = nrow(instances);
  i<- 1; sopt <- 0; sumsopt <- 0;
  while (i < linst){
    instanceid <- instances\$V7;
    #best <- 100;
    best <- instances[i,21];
    #TODO: CHECK IF BEST IS OK
    sumsopt <- sumsopt + Sopti(instances[i,],best);
    i <- i+1;
  }
  sopt <- alpha * sumsopt;
  return(sopt);
}

Sopti <- function(instancei,best){
  sopti <- 0;
  if(instancei\$V9 == 20) {
    sopti <- 1/N;
  } 
  else {
    if(instancei\$V11 != instancei\$V12){
      # if cost solver !=  cost checker
      # TODO: EXIT CODE 1 NEEDED??
      diskrepanz <- 1;
      return(0);
    }
    if(instancei\$V9 == 11) {
      sopti <- 1/(4*N) + (1/(2*N))*exp(100-(instancei\$V11*100/best));
    }
    else if(instancei\$V9 == 30 && best == instancei\$V11) {
        sopti <- 2/(4*N) + (1/(2*N))*exp(100-(instancei\$V11*100/best));
    } 
   }
  return(sopti);
}

Stime <- function(instances){
  stime <- (100-alpha)/(N*gamma) + sum(1 - (log(instances\$V17+instances\$V19+s)/log(tout+s)));
  return(stime);
}

output <- CalculateScore(instances);
write.table(output,stdout(),20,col.names=FALSE,row.names=FALSE);"


# (2)
# for all solvers
inp=""
for s in $(find $path -mindepth 1 -maxdepth 1 -type d); do
	
	# for all instances
	for d in $(find $s -mindepth 1 -maxdepth 1 -type d); do
		inst=`basename $d`

		# test if BROKEN is present in instance directory, we then ignore it
		test -f $d/$exclude_file
		if [ "$?" == 0 ];then
			continue
		fi
		row=`cat $d/runmeans.dat | tail -n1`
			mrow=`cat $d/opt.dat | tail -n1`
			row=$(echo "$row\t$mrow")
                        inp=$(echo "$inp\n$row")
		# get output of all solvers for this instance
# 		for sopt in $(find $path -mindepth 1 -maxdepth 1 -type d); do
# 			row=`cat $sopt/$inst/runmeans.dat | tail -n1`
# 			mrow=`cat $sopt/$inst/opt.dat | tail -n1`
# 			row=$(echo "$row\t$mrow")
#                         inp=$(echo "$inp\n$row")
# 		done
	done
 	echo -e $inp | Rscript <(echo "$bm_rscipt")  >> $path/score.dat
 	inp=""
done

