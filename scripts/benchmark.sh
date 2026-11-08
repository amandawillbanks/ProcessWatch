#!/usr/bin/env bash
# Compare periodic /proc snapshots with kernel eBPF exec events.
# Run from the repository root: bash scripts/benchmark.sh [count] [duration] [interval]
set -euo pipefail

count=${1:-100}
duration=${2:-0.05}
interval=${3:-0.1}

[[ "$count" =~ ^[1-9][0-9]*$ ]] || { echo "count must be a positive integer" >&2; exit 2; }
[[ "$duration" =~ ^(0|[0-9]+)(\.[0-9]+)?$ ]] || { echo "duration must be nonnegative seconds" >&2; exit 2; }
[[ "$interval" =~ ^(0|[0-9]+)(\.[0-9]+)?$ ]] || { echo "interval must be nonnegative seconds" >&2; exit 2; }
(( count <= 10000 )) || { echo "count must be <= 10000" >&2; exit 2; }
awk -v n="$interval" 'BEGIN {exit !(n > 0)}' || { echo "interval must be > 0" >&2; exit 2; }

cd "$(dirname "$0")/.."
[[ -x build/processwatch ]] || { echo "Run make first" >&2; exit 1; }
[[ -x build/processwatch-loader && -f build/process_exec.bpf.o ]] || {
    echo "Compile the eBPF object and loader first (see README)." >&2; exit 1;
}

mkdir -p results
run_dir=$(mktemp -d results/benchmark-XXXXXXXX)
pid_file="$run_dir/workload_pids.txt"
snapshot_file="$run_dir/snapshot_pids.txt"
ebpf_file="$run_dir/ebpf.log"
summary_file="$run_dir/summary.txt"
: > "$snapshot_file"
: > "$ebpf_file"
loader_pid=""
sampler_pid=""

cleanup() {
    if [[ -n "$sampler_pid" ]]; then
        kill "$sampler_pid" 2>/dev/null || true
        wait "$sampler_pid" 2>/dev/null || true
    fi
    if [[ -n "$loader_pid" ]]; then
        # sudo may be the parent of the actual loader process.
        sudo pkill -INT -f '^\./build/processwatch-loader$' 2>/dev/null || true
        wait "$loader_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "Benchmark results: $run_dir"
echo "Checking sudo permission (needed to attach eBPF)..."
sudo -v
# Start loader as root, but retain the PID of the shell's sudo child.
sudo ./build/processwatch-loader > "$ebpf_file" 2>&1 &
loader_pid=$!
sleep 1
if ! kill -0 "$loader_pid" 2>/dev/null; then
    echo "eBPF loader failed to start:" >&2
    cat "$ebpf_file" >&2
    exit 1
fi

# Periodically run the project's actual snapshot command.
# Save all observed numeric PIDs; restrict to workload PIDs in analysis.
(
    while :; do
        ./build/processwatch snapshot |
            awk 'NR > 4 && $1 ~ /^[0-9]+$/ {print $1}' >> "$snapshot_file"
        sleep "$interval"
    done
) &
sampler_pid=$!

# Workload generates known child PIDs for both monitors to compare.
bash tests/workload.sh "$count" "$duration" "$pid_file"
sleep 0.5
kill "$sampler_pid" 2>/dev/null || true
wait "$sampler_pid" 2>/dev/null || true
sampler_pid=""

# Stop loader and wait for the ring-buffer output to flush.
# pkill targets the executable rather than relying on sudo's PID semantics.
        sudo pkill -INT -f '^\./build/processwatch-loader$' 2>/dev/null || true
wait "$loader_pid" 2>/dev/null || true
loader_pid=""

sort -nu "$pid_file" > "$run_dir/expected.sorted"
sort -nu "$snapshot_file" > "$run_dir/snapshot.sorted"
awk '/^EXEC PID=/ {
    split($2, field, "=");
    if (field[2] ~ /^[0-9]+$/) print field[2]
}' "$ebpf_file" | sort -nu > "$run_dir/ebpf.sorted"

expected=$(wc -l < "$run_dir/expected.sorted")
snapshot_hits=$(comm -12 "$run_dir/expected.sorted" "$run_dir/snapshot.sorted" | wc -l)
ebpf_hits=$(comm -12 "$run_dir/expected.sorted" "$run_dir/ebpf.sorted" | wc -l)

{
    echo "ProcessWatch benchmark"
    echo "Workload executions: $expected"
    echo "Requested process lifetime (seconds): $duration"
    echo "Requested snapshot interval (seconds): $interval"
    echo "Snapshot detections: $snapshot_hits / $expected"
    echo "eBPF detections: $ebpf_hits / $expected"
    awk -v s="$snapshot_hits" -v b="$ebpf_hits" -v n="$expected" 'BEGIN {
        printf "Snapshot detection rate: %.1f%%\n", 100*s/n
        printf "eBPF detection rate: %.1f%%\n", 100*b/n
    }'
    echo "Note: detection rates are for this workload and trial only."
    echo "Note: this script does not measure CPU or memory overhead."
} | tee "$summary_file"
 2>/dev/null || true
        wait "$loader_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "Benchmark results: $run_dir"
echo "Checking sudo permission (needed to attach eBPF)..."
sudo -v
# Start loader as root, but retain the PID of the shell's sudo child.
sudo ./build/processwatch-loader > "$ebpf_file" 2>&1 &
loader_pid=$!
sleep 1
if ! kill -0 "$loader_pid" 2>/dev/null; then
    echo "eBPF loader failed to start:" >&2
    cat "$ebpf_file" >&2
    exit 1
fi

# Periodically run the project's actual snapshot command.
# Save all observed numeric PIDs; restrict to workload PIDs in analysis.
(
    while :; do
        ./build/processwatch snapshot |
            awk 'NR > 4 && $1 ~ /^[0-9]+$/ {print $1}' >> "$snapshot_file"
        sleep "$interval"
    done
) &
sampler_pid=$!

# Workload generates known child PIDs for both monitors to compare.
bash tests/workload.sh "$count" "$duration" "$pid_file"
sleep 0.5
kill "$sampler_pid" 2>/dev/null || true
wait "$sampler_pid" 2>/dev/null || true
sampler_pid=""

# Stop loader and wait for the ring-buffer output to flush.
# pkill targets the executable rather than relying on sudo's PID semantics.
sudo pkill -INT -x processwatch-loader 2>/dev/null || true
wait "$loader_pid" 2>/dev/null || true
loader_pid=""

sort -nu "$pid_file" > "$run_dir/expected.sorted"
sort -nu "$snapshot_file" > "$run_dir/snapshot.sorted"
awk '/^EXEC PID=/ {
    split($2, field, "=");
    if (field[2] ~ /^[0-9]+$/) print field[2]
}' "$ebpf_file" | sort -nu > "$run_dir/ebpf.sorted"

expected=$(wc -l < "$run_dir/expected.sorted")
snapshot_hits=$(comm -12 "$run_dir/expected.sorted" "$run_dir/snapshot.sorted" | wc -l)
ebpf_hits=$(comm -12 "$run_dir/expected.sorted" "$run_dir/ebpf.sorted" | wc -l)

{
    echo "ProcessWatch benchmark"
    echo "Workload executions: $expected"
    echo "Requested process lifetime (seconds): $duration"
    echo "Requested snapshot interval (seconds): $interval"
    echo "Snapshot detections: $snapshot_hits / $expected"
    echo "eBPF detections: $ebpf_hits / $expected"
    awk -v s="$snapshot_hits" -v b="$ebpf_hits" -v n="$expected" 'BEGIN {
        printf "Snapshot detection rate: %.1f%%\n", 100*s/n
        printf "eBPF detection rate: %.1f%%\n", 100*b/n
    }'
    echo "Note: detection rates are for this workload and trial only."
    echo "Note: this script does not measure CPU or memory overhead."
} | tee "$summary_file"
 2>/dev/null || true
wait "$loader_pid" 2>/dev/null || true
loader_pid=""

sort -nu "$pid_file" > "$run_dir/expected.sorted"
sort -nu "$snapshot_file" > "$run_dir/snapshot.sorted"
awk '/^EXEC PID=/ {
    split($2, field, "=");
    if (field[2] ~ /^[0-9]+$/) print field[2]
}' "$ebpf_file" | sort -nu > "$run_dir/ebpf.sorted"

expected=$(wc -l < "$run_dir/expected.sorted")
snapshot_hits=$(comm -12 "$run_dir/expected.sorted" "$run_dir/snapshot.sorted" | wc -l)
ebpf_hits=$(comm -12 "$run_dir/expected.sorted" "$run_dir/ebpf.sorted" | wc -l)

{
    echo "ProcessWatch benchmark"
    echo "Workload executions: $expected"
    echo "Requested process lifetime (seconds): $duration"
    echo "Requested snapshot interval (seconds): $interval"
    echo "Snapshot detections: $snapshot_hits / $expected"
    echo "eBPF detections: $ebpf_hits / $expected"
    awk -v s="$snapshot_hits" -v b="$ebpf_hits" -v n="$expected" 'BEGIN {
        printf "Snapshot detection rate: %.1f%%\n", 100*s/n
        printf "eBPF detection rate: %.1f%%\n", 100*b/n
    }'
    echo "Note: detection rates are for this workload and trial only."
    echo "Note: this script does not measure CPU or memory overhead."
} | tee "$summary_file"
 2>/dev/null || true
        wait "$loader_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "Benchmark results: $run_dir"
echo "Checking sudo permission (needed to attach eBPF)..."
sudo -v
# Start loader as root, but retain the PID of the shell's sudo child.
sudo ./build/processwatch-loader > "$ebpf_file" 2>&1 &
loader_pid=$!
sleep 1
if ! kill -0 "$loader_pid" 2>/dev/null; then
    echo "eBPF loader failed to start:" >&2
    cat "$ebpf_file" >&2
    exit 1
fi

# Periodically run the project's actual snapshot command.
# Save all observed numeric PIDs; restrict to workload PIDs in analysis.
(
    while :; do
        ./build/processwatch snapshot |
            awk 'NR > 4 && $1 ~ /^[0-9]+$/ {print $1}' >> "$snapshot_file"
        sleep "$interval"
    done
) &
sampler_pid=$!

# Workload generates known child PIDs for both monitors to compare.
bash tests/workload.sh "$count" "$duration" "$pid_file"
sleep 0.5
kill "$sampler_pid" 2>/dev/null || true
wait "$sampler_pid" 2>/dev/null || true
sampler_pid=""

# Stop loader and wait for the ring-buffer output to flush.
# pkill targets the executable rather than relying on sudo's PID semantics.
sudo pkill -INT -x processwatch-loader 2>/dev/null || true
wait "$loader_pid" 2>/dev/null || true
loader_pid=""

sort -nu "$pid_file" > "$run_dir/expected.sorted"
sort -nu "$snapshot_file" > "$run_dir/snapshot.sorted"
awk '/^EXEC PID=/ {
    split($2, field, "=");
    if (field[2] ~ /^[0-9]+$/) print field[2]
}' "$ebpf_file" | sort -nu > "$run_dir/ebpf.sorted"

expected=$(wc -l < "$run_dir/expected.sorted")
snapshot_hits=$(comm -12 "$run_dir/expected.sorted" "$run_dir/snapshot.sorted" | wc -l)
ebpf_hits=$(comm -12 "$run_dir/expected.sorted" "$run_dir/ebpf.sorted" | wc -l)

{
    echo "ProcessWatch benchmark"
    echo "Workload executions: $expected"
    echo "Requested process lifetime (seconds): $duration"
    echo "Requested snapshot interval (seconds): $interval"
    echo "Snapshot detections: $snapshot_hits / $expected"
    echo "eBPF detections: $ebpf_hits / $expected"
    awk -v s="$snapshot_hits" -v b="$ebpf_hits" -v n="$expected" 'BEGIN {
        printf "Snapshot detection rate: %.1f%%\n", 100*s/n
        printf "eBPF detection rate: %.1f%%\n", 100*b/n
    }'
    echo "Note: detection rates are for this workload and trial only."
    echo "Note: this script does not measure CPU or memory overhead."
} | tee "$summary_file"
