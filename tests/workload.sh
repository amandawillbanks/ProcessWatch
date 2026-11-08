#!/usr/bin/env bash
# Launch a repeatable set of short-lived child processes.
# Usage: bash tests/workload.sh [count] [duration_seconds] [pid_output_file]
set -euo pipefail

count=${1:-100}
duration=${2:-0.05}
pid_file=${3:-}

[[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo "count must be a positive integer" >&2; exit 2; }
[[ "$duration" =~ ^(0|[0-9]+)(\.[0-9]+)?$ ]] || { echo "duration must be nonnegative seconds" >&2; exit 2; }
(( count <= 10000 )) || { echo "count must be <= 10000" >&2; exit 2; }

if [[ -n "$pid_file" ]]; then
    : > "$pid_file"
fi

# One child at a time gives the snapshot sampler a measurable opportunity
# to observe each process, while avoiding excessive concurrent load.
for ((i = 0; i < count; i++)); do
    /bin/sleep "$duration" &
    child=$!
    if [[ -n "$pid_file" ]]; then
        printf '%s\n' "$child" >> "$pid_file"
    fi
    wait "$child"
done

echo "Completed $count sleep executions (requested duration: ${duration}s each)."
