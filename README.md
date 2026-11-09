# ProcessWatch

**CSC 501 — Operating Systems | NC State University | Fall 2026**

**Status:** Core Linux `/proc` snapshot monitor, security flags, eBPF execution-event monitor, and initial detection benchmark implemented. Repeated experiments, CPU/memory overhead measurements, and final report remain outstanding.

## Overview

ProcessWatch is a Linux process-monitoring project written primarily in C. It compares a **point-in-time** `/proc` process listing with **event-driven** eBPF monitoring using the kernel `sched_process_exec` tracepoint.

**Research question:** How well does event-driven eBPF monitoring capture short-lived process executions compared with periodic `/proc` snapshots, and what monitoring overhead does each approach incur?

The tools are separate executables; they are not yet integrated into a single combined interface.

## Implemented features

- **Snapshot:** `./build/processwatch snapshot` enumerates numeric `/proc/<pid>` directories, reads `/proc/<pid>/status`, and displays PID, PPID, UID, state, resident memory in kB (when available), and process name.
- **Security review flags:** `ROOT` marks UID 0; `TMP_EXEC` marks executables resolved under `/tmp/`. These are **review signals, not evidence of malicious activity**. Executable paths may be unavailable due to permissions or process exit.
- **eBPF monitor:** `ebpf/process_exec.bpf.c` hooks `sched_process_exec`, obtains PID, parent PID, UID, command name and monotonic kernel timestamp, and submits structured records to a BPF ring buffer. `ebpf/loader.c` reads and prints them.
- **Controlled workload:** `tests/workload.sh` launches a specified number of short-lived `/bin/sleep` processes and records their PIDs.
- **Benchmark:** `scripts/benchmark.sh` compares known workload PIDs with the PIDs seen by periodic snapshots and eBPF exec events, saving logs and a summary under `results/benchmark-*/`.

## Environment and dependencies

Developed on NC State VCL Ubuntu 24.04 LTS (x86_64; previously observed kernel 6.8.0-147-generic) using GCC, Make, Clang 18, bpftool, and libbpf. Building and attaching eBPF requires a compatible Linux kernel, BTF data, and elevated permissions. Linux `/proc` and eBPF run on the **Linux host**, not inside a Xinu guest.

Example dependency installation on Ubuntu:

```bash
sudo apt update
sudo apt install -y build-essential clang llvm bpftool libbpf-dev libelf-dev zlib1g-dev
```

## Build

From the repository root:

```bash
make
sudo bpftool btf dump file /sys/kernel/btf/vmlinux format c > ebpf/vmlinux.h
mkdir -p build
clang -O2 -g -target bpf -D__TARGET_ARCH_x86 \
  -Iebpf -I/usr/include/x86_64-linux-gnu \
  -c ebpf/process_exec.bpf.c -o build/process_exec.bpf.o
gcc -Wall -Wextra -O2 -Iebpf \
  ebpf/loader.c -o build/processwatch-loader -lbpf -lelf -lz
```

The Makefile currently builds only `build/processwatch`. The eBPF compilation steps remain manual. The generated `ebpf/vmlinux.h` is machine/kernel-specific; regenerate it as appropriate for the target environment. **`make clean` removes the entire `build/` directory**, including manually built eBPF binaries.

## Run

### /proc snapshot

```bash
./build/processwatch snapshot
```

Output columns: `PID PPID UID STATE RSS(KB) NAME FLAGS`. Processes that exit during enumeration or cannot be read may be skipped. `RSS(KB)=0` can mean that `VmRSS` was unavailable, not necessarily that the process used no memory.

### Live eBPF execution monitoring

```bash
sudo ./build/processwatch-loader
```

In another terminal, launch a process such as `/bin/sleep 2`. The loader displays entries similar to:

```text
EXEC PID=1125264 PPID=1117695 UID=510249 COMM=sleep TIME=895041159715633
```

`TIME` is a kernel monotonic timestamp in nanoseconds, **not a wall-clock date/time**. Stop with Ctrl+C. A `bash` process that `exec`s `sleep` can produce two execution events with the same PID; an `exec` replaces the process image without changing the PID.

### Controlled detection benchmark

```bash
bash -n scripts/benchmark.sh
bash scripts/benchmark.sh 20 0.05 0.1
```

Arguments: `[number_of_processes] [sleep_duration_seconds] [snapshot_interval_seconds]`. The example runs 20 sequential `sleep` executions, requests a 50 ms sleep for each, and requests a 100 ms snapshot interval. The benchmark requires `sudo` to attach the eBPF program and assumes the two monitor binaries are already built.

Results are stored in a unique `results/benchmark-*/` directory, including `summary.txt`, `ebpf.log`, `workload_pids.txt`, and intermediate PID sets. The benchmark matches **known workload PIDs** against the observed PID sets; unrelated background processes are excluded from the final detection counts.

**Observed initial trial (November 8, 2026):**

| Metric | /proc snapshots | eBPF |
|---|---:|---:|
| Workload executions | 20 | 20 |
| Detected workload PIDs | 8 | 20 |
| Detection rate | 40.0% | 100.0% |

The observed run used `bash scripts/benchmark.sh 20 0.05 0.1` and saved its output under `results/benchmark-35LW8ig9/` on the VCL host. That run printed a trailing shell syntax error after the detection summary due to duplicated script content. The duplicate tail was subsequently removed in commit `ad82c37`; **a clean rerun after that fix has not yet been confirmed**.

**Additional observed trial (November 8, 2026):** Running `bash scripts/benchmark.sh 100 0.05 0.1` produced 42/100 (42.0%) snapshot detections and 100/100 (100.0%) eBPF detections. The VCL host saved output under `results/benchmark-dpLxymCR/`. The terminal output shared for this run ended with a truncated note, so a complete clean exit was not independently confirmed.\n\nThese figures describe **one preliminary trial**, not a statistically supported general performance claim. Requested sleep duration and snapshot interval are not exact measured timings. CPU and memory overhead are **not yet measured**.

## Benchmark methodology and limitations

The workload records each child PID as ground truth. Snapshot sampling runs `./build/processwatch snapshot` repeatedly and extracts its PID column. The eBPF loader captures execution events via the kernel tracepoint. The benchmark intersects each observed PID set with the known workload PID set.

Important limitations:
- Snapshot detection depends on the process lifetime, sampling interval, snapshot execution time, and scheduler timing.
- eBPF monitors **exec events**, whereas `/proc` lists **currently existing processes**; these are different observation semantics.
- Ring-buffer events may be dropped under heavy load; 100% detection in one trial does not guarantee lossless capture.
- The current benchmark does not measure CPU or memory overhead, monitor actual sampling cadence, or run repeated trials automatically.
- The snapshot executable includes process enumeration and status parsing overhead; the eBPF executable includes event delivery and terminal output overhead. Any overhead comparison should account for this.
- The benchmark is intended for controlled, low-load experiments. Review cleanup behavior before running concurrently with other instances of the loader.

## Repository layout

```text
src/          C CLI, /proc reader, security checks
include/      C headers
ebpf/         kernel-side BPF program, shared event structure, userspace loader
tests/        controlled workload and test scaffolding
scripts/      benchmark runner
results/      generated benchmark outputs (local)
docs/         proposal, architecture, evaluation plan, report drafts
Makefile      snapshot monitor build
```

## Progress and next steps

1. **Complete:** /proc snapshot with root and /tmp review flags.
2. **Complete:** structured eBPF ring-buffer execution events, including verified PPID tracking.
3. **Complete:** initial 20-process detection benchmark; clean-script rerun still needed.
4. **Next:** repeat controlled trials with multiple process lifetimes and polling intervals.
5. **Next:** implement and record CPU and memory overhead measurements; validate benchmark reliability.
6. **Next:** finalize build reproducibility, documentation, analysis, and CSC 501 report.

## Course deliverables

- **Presentation dates previously noted:** November 11, 16, and 18, 2026; verify requirements for the enrolled section, especially EOL/online students.
- **Final report deadline previously noted:** December 1, 2026 at 11:59 PM via Gradescope.
- **Solo report requirement previously noted:** at least three single-spaced pages in 10-point font, excluding contribution table and AI statement. Verify against the current assignment.
- Suggested sections: abstract; motivation; implementation and OS concepts; experimental methodology; measured results and limitations; contribution table; AI assistance statement.

## AI assistance disclosure

AI was used to assist with C/eBPF implementation, Bash benchmark scripts, debugging, and README drafting. The student should review, test, and understand all code and report statements. The final report should disclose actual AI assistance in accordance with course requirements.

Additional documents: [proposal](docs/proposal.md), [architecture](docs/architecture.md), [evaluation plan](docs/evaluation_plan.md), [milestones](docs/milestones.md).
