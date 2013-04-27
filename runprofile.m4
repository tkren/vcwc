test -f TRACK_DIR/TRACK/track_profile.sh && source TRACK_DIR/TRACK/track_profile.sh
test -f TRACK_DIR/TRACK/BENCH/benchmark_profile.sh && source TRACK_DIR/TRACK/BENCH/benchmark_profile.sh
test -f TRACK_DIR/TRACK/PART/participant_profile.sh && source TRACK_DIR/TRACK/PART/participant_profile.sh

SOLVER=PART
ARGS="__ARGV1__ __ARGV2__ __ARGV3__"
INSTANCE="BENCHMARKS_DIR/BENCH/encoding.asp BENCHMARKS_DIR/BENCH/instances/__INSTANCE__"
LOG=format(`%s_%s_%s_%s',TRACK,BENCH,PART,__INSTANCE__)
USESTDIN=true
