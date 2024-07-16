#!/bin/bash
set -e

DATE=$(date +%F.%H_%M_%S)
echo "Start tracing at $DATE"
DIR="./perf-logs-kvm-$DATE"
mkdir "$DIR"
echo "Created $DIR for perf logs"
cd "$DIR"
echo "(press Ctrl + C to stop, or it will automatically stop on first VM crash)"

set +e

perf record -age 'kvm:*' --switch-output=5m --switch-max-files=6 &
TRACE_PID="$!"

finish_trace () {
	echo "Stop tracing at $(date +%F.%H_%M_%S)"
	if [ -n "$TRACE_PID" ]; then
		kill "$TRACE_PID"
	fi
	exit 0
}
trap 'finish_trace' SIGINT

python3 ../detect-vm-panic.py | tee detect-vm-panic.log
pstree -sSpla 1 > pstree.log
finish_trace
