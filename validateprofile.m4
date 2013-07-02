test -f TRACK_DIR/TRACK/track_profile.sh && source TRACK_DIR/TRACK/track_profile.sh
test -f TRACK_DIR/TRACK/BENCH/benchmark_profile.sh && source TRACK_DIR/TRACK/BENCH/benchmark_profile.sh
test -f TRACK_DIR/TRACK/PART/participant_profile.sh && source TRACK_DIR/TRACK/PART/participant_profile.sh

MAILTO=aspcomp2013@gmail.com
SOLVER=PART
RUNCMD=__RUNCMD__
INSTANCE="BENCHMARKS_DIR/BENCH/instances/__INSTANCE__"
LOG=format(`validate_%s_%s_%s_%s',TRACK,BENCH,PART,__INSTANCE__)
