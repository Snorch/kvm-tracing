#!/bin/bash
# to trace something different, e.g.: kvm events:
# PERF_OPTIONS="-e kvm:*" bash perf-trace-kvm.sh

PERF_OPTIONS="${PERF_OPTIONS:--F 99}"
INTERVAL="${INTERVAL:-30m}"

if ! rpm -qa | grep "debuginfo.*$(uname -r)" &>/dev/null; then
	echo "Please install kernel debuginfo before running this script!!!"
	exit 1
fi

if [ ! -f /usr/bin/python3 ]; then
	echo "Please install python3 (e.g. python36) before running this script!!!"
	exit 1
fi

if [ ! -f ./detect-vm-panic.py ]; then
	echo "Please put detect-vm-panic.py to cwd before running this script!!!"
	exit 1
fi

set -e

DIR="./perf-logs-kvm-$(date +%F.%H_%M_%S)"
mkdir $DIR
echo "Created $DIR for perf logs"
cd $DIR

set +e

# Create info pipe
exec {pipe}<> <(:)
exec {pipe_r}</proc/self/fd/$pipe
exec {pipe_w}>/proc/self/fd/$pipe
exec {pipe}>&-

# Report info message to main process and fail if pipe is closed
write_pipe () {
	set -e
	echo "$1" >&$pipe_w
	set +e
}

post_trace () {
	DATE=$1
	PREV=$2

	if [ -n "$PREV" ]; then
		write_pipe "Removing old report perf-record-$PREV"
		rm perf-record-$PREV
	fi
}

do_trace () {
	exec {pipe_r}>&-
	PREV=""
	while true; do
		DATE=$(date +%F.%H_%M_%S)
		write_pipe "Collecting perf for $DATE"
		perf record -ag "$PERF_OPTIONS" -o perf-record-$DATE sleep $INTERVAL
		post_trace "$DATE" "$PREV" &
		PREV=$DATE
	done
}

do_trace &
exec {pipe_w}>&-

cat <&$pipe_r &
CAT_PID="$!"

finish_trace () {
	echo "Exiting..."
	kill $CAT_PID
	exec {pipe_r}>&-
	# This assumes we have only our perf on the system
	killall perf
	exit 0
}
trap 'finish_trace' SIGINT

python3 ../detect-vm-panic.py

DATE=$(date +%F.%H_%M_%S)
echo "Stop tracing at $DATE"

finish_trace
