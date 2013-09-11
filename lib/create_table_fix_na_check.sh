#!/bin/bash

set -e

track=${1:?'track unset'}

seq -s "$(echo -e '\t')" 1 22

echo -e "Timestamp-Statrun Timestamp-Execution Host Track-ID Benchmark-ID Solver-ID Instance-ID Stats-Discrepancy Exit-Code-Solver Exit-Code-Checker Min-Cost-Solver Min-Cost-Checker Max-Cost-Solver Max-Cost-Checker Problem-Type Wall-Clock-Time Time-Grounder Memory-Grounder Time-Solver Memory-Solver Time-Combined Memory-Combined"

find $track -mindepth 4 -maxdepth 4 -type f -name runmeans.dat | xargs tail -qn1 | sort -k5,5 -k7,7 | awk \
    'BEGIN{ bm=0; inst=0; verified=0; i=-1; first=1; }

     func print_elem(elem, dec) {
       split(elem,a," ");
       for(j=1;j<10;++j) {
         printf "%s%s", a[j], OFS;
       }
       printf "%s%s", dec, OFS;
       for(j=11;j<22;++j) {
         printf "%s%s", a[j], OFS;
       }
       printf "%s%s", a[22], ORS;
     }

     func decide_na_list() {
       if(i >= 0) {
         for(na in na_list) {
           print_elem(na_list[na], verified);
         }
       }
     }

     $5 != bm || $7 != inst {

       if(first) {
         first = 0;
       } else {
         decide_na_list();
       }

       bm=$5; inst=$7; verified=0; delete na_list; i=-1;
     }

     $10 == 0 { verified = 1; print; next; }
     $10 == 1 || $10 == 124 { print; next; }
     $10 == "NA"  { na_list[++i]=$0; next; }
     
     { print "error" > "/dev/stderr"; exit 1; }

     END{ decide_na_list(); }'

# pipe into column -t | less -S if you want to pretty-print it
