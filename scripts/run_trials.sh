#!/usr/bin/env bash
# Run repeatable controlled detection trials using the existing benchmark.
# Usage: bash scripts/run_trials.sh [trials] [count] [duration] [interval]
set -euo pipefail

trials=${1:-3}
count=${2:-100}
duration=${3:-0.05}
interval=${4:-0.1}

[[ "$trials" =~ ^[1-9][0-9]*$ ]] || { echo "trials must be a positive integer" >&2; exit 2; }
(( trials <= 30 )) || { echo "trials must be <= 30" >&2; exit 2; }

cd "$(dirname "$0")/.."
mkdir -p results
csv="results/detection_trials.csv"
if [[ ! -e "$csv" ]]; then
    printf 'trial,workload_count,requested_lifetime_s,requested_poll_interval_s,snapshot_detected,ebpf_detected,snapshot_rate_percent,ebpf_rate_percent,result_directory\n' > "$csv"
fi

for (( trial=1; trial<=trials; trial++ )); do
    echo "Running trial $trial of $trials"
    # Capture stdout but preserve the benchmark's logs and summary on disk.
    output=$(bash scripts/benchmark.sh "$count" "$duration" "$interval")
    printf '%s\n' "$output"
    dir=$(printf '%s\n' "$output" | sed -n 's/^Benchmark results: //p' | head -n 1)
    [[ -n "$dir" && -f "$dir/summary.txt" ]] || { echo "Missing benchmark summary" >&2; exit 1; }
    summary="$dir/summary.txt"
    expected=$(sed -n 's/^Workload executions: //p' "$summary")
    snapshot=$(sed -n 's@^Snapshot detections: \([0-9]*\) /.*@\1@p' "$summary")
    ebpf=$(sed -n 's@^eBPF detections: \([0-9]*\) /.*@\1@p' "$summary")
    [[ "$expected" =~ ^[1-9][0-9]*$ && "$snapshot" =~ ^[0-9]+$ && "$ebpf" =~ ^[0-9]+$ ]] || {
        echo "Could not parse detection counts from $summary" >&2; exit 1;
    }
    rates=$(awk -v s="$snapshot" -v b="$ebpf" -v n="$expected" 'BEGIN {printf "%.2f,%.2f", 100*s/n, 100*b/n}')
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$trial" "$expected" "$duration" "$interval" "$snapshot" "$ebpf" "$rates" "$dir" >> "$csv"
done
echo "Trial data saved to $csv"
