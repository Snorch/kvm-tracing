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

function lock_monitoring {
	prev=()
	while :; do
		DATE=$(date +%F.%H_%M_%S)
		cat /proc/lock_stat > "lock_stat_$DATE"
		prev+=($DATE)
		if [ "${#prev[@]}" -gt 10 ]; then
			PREV="${prev[0]}"
			prev=("${prev[@]:1}")
			rm "lock_stat_$PREV"
		fi
		sleep 1m
	done
}

LOCK_MONITORING_PID=""
if [ -f /proc/sys/kernel/lock_stat ]; then
	echo "Clear and enable lock stat debug"
	echo 1 > /proc/sys/kernel/lock_stat
	echo 0 > /proc/lock_stat
	lock_monitoring &
	LOCK_MONITORING_PID="$!"
fi

perf record -age 'kvm:*' --switch-output=5m --switch-max-files=6 &
TRACE_PID="$!"

finish_trace () {
	echo "Stop tracing at $(date +%F.%H_%M_%S)"
	if [ -n "$TRACE_PID" ]; then
		kill "$TRACE_PID"
	fi
	if [ -n "$LOCK_MONITORING_PID" ]; then
		kill "$LOCK_MONITORING_PID"
	fi
	exit 0
}
trap 'finish_trace' SIGINT

python3 ../detect-vm-panic.py | tee detect-vm-panic.log
pstree -sSpla 1 > pstree.log
if [ -f /proc/sys/kernel/lock_stat ]; then
	cat /proc/lock_stat > "lock_stat.out"
fi
finish_trace
