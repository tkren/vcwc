test -f TRACK_DIR/TRACK/track_profile.sh && source TRACK_DIR/TRACK/track_profile.sh
test -f TRACK_DIR/TRACK/BENCH/benchmark_profile.sh && source TRACK_DIR/TRACK/BENCH/benchmark_profile.sh
test -f TRACK_DIR/TRACK/PART/participant_profile.sh && source TRACK_DIR/TRACK/PART/participant_profile.sh

MAILTO=aspcomp2013@gmail.com
SOLVER=PART
RUNCMD=__RUNCMD__
ARGS="__ARGV1__ __ARGV2__ __ARGV3__"
INSTANCE="__ENCODING__ BENCHMARKS_DIR/BENCH/instances/__INSTANCE__"
LOG=format(`%s_%s_%s_%s',TRACK,BENCH,PART,__INSTANCE__)
USESTDIN=true
