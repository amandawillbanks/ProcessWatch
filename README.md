# ProcessWatch

**CSC 501 : Operating Systems | NC State University | Fall 2026**

**Status:** Unified CLI changes prepared November 18, 2026; not yet rebuilt or benchmarked on NC State VCL. Historical results are not newly rerun tests.

## Overview

ProcessWatch is a Linux process-monitoring project written primarily in C. It compares a **point-in-time** `/proc` process listing with **event-driven** eBPF monitoring using the kernel `sched_process_exec` tracepoint.

**Research question:** How well does event-driven eBPF monitoring capture short-lived process executions compared with periodic `/proc` snapshots, and what monitoring overhead does each approach incur?

The snapshot and eBPF monitor share a single CLI executable (`processwatch snapshot` and `processwatch monitor`). The kernel BPF object remains separate.

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
make ebpf
make test
```

The default `make` target builds the unified CLI with libbpf; `make ebpf` builds the BPF object and generates `ebpf/vmlinux.h` from host BTF as needed. The generated `ebpf/vmlinux.h` is machine/kernel-specific; regenerate it as appropriate for the target environment. **`make clean` removes the entire `build/` directory**, including manually built eBPF binaries.

## Run

### /proc snapshot

```bash
./build/processwatch snapshot
```

Output columns: `PID PPID UID STATE RSS(KB) NAME FLAGS`. Processes that exit during enumeration or cannot be read may be skipped. `RSS(KB)=0` can mean that `VmRSS` was unavailable, not necessarily that the process used no memory.

### Live eBPF execution monitoring

```bash
sudo ./build/processwatch monitor
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

**Observed detection experiments (November 8, 2026):**

| Trial | Workload count | Requested sleep | Requested snapshot interval | /proc detected | eBPF detected | Local result directory |
|---|---:|---:|---:|---:|---:|---|
| 1 | 20 | 0.05 s | 0.1 s | 8/20 (40%) | 20/20 (100%) | `benchmark-FWQxdoXr` |
| 2 | 100 | 0.05 s | 0.1 s | 42/100 (42%) | 100/100 (100%) | `benchmark-dpLxymCR` |
| 3 | 100 | 0.2 s | 0.1 s | 100/100 (100%) | 100/100 (100%) | `benchmark-hPrkgHVm` |
| 4 | 100 | 0.05 s | 0.01 s | 100/100 (100%) | 100/100 (100%) | `benchmark-lVAux9Nf` |

These are user-reported terminal results from individual VCL runs, not averages. The first clean run used `benchmark-FWQxdoXr`, superseding an earlier trial that printed a shell error after its summary. Requested sleep duration and polling interval are not exact measured timings. Trial 4 shows that faster polling can recover short-lived processes in this workload; it does **not** establish the CPU/memory cost. Some pasted outputs were truncated at the final note, but all displayed detection counts.

**Single `/proc` snapshot baseline (November 8, 2026, one observed run):** GNU `/usr/bin/time` reported user CPU `0.00 s`, system CPU `0.00 s`, elapsed `0.01 s`, and maximum RSS `1664 KB` (approximately `1.63 MiB`) for `./build/processwatch snapshot > /dev/null`. The CPU figures are rounded to hundredths of a second and should not be interpreted as zero CPU usage. An earlier verbose invocation also reported 83 minor faults, zero major faults, and two total context switches. This is **not** a continuous-polling overhead measurement.\n\n**Continuous snapshot polling baseline (user-reported, November 8, 2026):** A shell loop running `./build/processwatch snapshot > /dev/null` followed by `sleep 0.01` for approximately 15 seconds completed **796 snapshots** in **14.78 s** elapsed, with GNU `time` reporting **1.91 s user CPU**, **5.01 s system CPU**, and **3584 KB peak child RSS**. Combined CPU time was **6.92 CPU-seconds**, equivalent to approximately **46.8% of one CPU core** over elapsed time, inclusive of the shell, snapshot commands, and sleep subprocesses. Average completed-cycle duration was **18.6 ms** (approximately 53.9 snapshots/s), **not** a measured 10 ms start-to-start interval. This was one idle-monitoring trial, not a matched comparison against eBPF; peak RSS is not total or cumulative memory consumption.\n\n**Continuous snapshot polling, requested 100 ms delay (user-reported, November 8, 2026):** The same shell loop with `sleep 0.1` completed **136 snapshots** in **14.82 s**, reporting **0.32 s user CPU**, **0.91 s system CPU**, and **3584 KB peak child RSS**. Combined CPU time was **1.23 CPU-seconds**, equivalent to approximately **8.3% of one CPU core**; average completed-cycle duration was **109.0 ms** (approximately 9.2 snapshots/s). In separate single trials, the 10 ms-delay loop consumed approximately **5.6×** the combined CPU time of the 100 ms-delay loop. Both measurements include shell and subprocess overhead and were conducted without the controlled detection workload. The identical reported peak RSS does not establish equal total memory footprints.\n\n**Idle eBPF loader overhead (user-reported, November 8, 2026):** Command `sudo /usr/bin/time -f ... timeout --signal=INT --kill-after=3s 15s ./build/processwatch-loader > /dev/null` returned timeout status **124** after **15.03 s**, with **0.01 s user CPU**, **0.03 s system CPU**, and **35,424 KB peak RSS**. Combined CPU time was **0.04 CPU-seconds**, approximately **0.27% of one CPU core** over elapsed time. Status 124 is consistent with the intentional time limit; it does not alone prove successful loader startup or event capture. The timed command includes the timeout wrapper, and RSS does not account for all kernel-side BPF memory. **Comparison (single idle trials only):** 10 ms `/proc` delay loop: 6.92 CPU-seconds/14.78 s (46.8%); 100 ms delay loop: 1.23 CPU-seconds/14.82 s (8.3%); eBPF timed loader: 0.04 CPU-seconds/15.03 s (0.27%). Workload, output and measurement boundaries differ; avoid treating these as matched full-system overhead benchmarks.\n\n**Active-workload eBPF event count (user-reported, November 8, 2026):** During a separate 100-process workload (`bash tests/workload.sh 100 0.05 /tmp/processwatch-workload-pids.txt`), `grep -c '^EXEC PID=' /tmp/processwatch-ebpf-test.log` returned **210 total exec-event lines**. This includes potential unrelated process activity and duplicate exec events per PID; a subsequent PID intersection matched **89 of 100** workload PIDs (**89%**) against that log; the CPU/RSS for this active trial have not yet been supplied. The 11 unmatched PIDs cannot be attributed to eBPF event loss without verifying monitor startup, temporal overlap, log flush, and workload timing. The workload and loader must overlap in time for a valid comparison.\n\n**Synchronized active-workload verification (user-reported, November 8, 2026):** Started the eBPF loader under a 20-second `timeout`, waited 2 seconds, executed 100 sequential 50 ms sleep commands, waited for monitor completion, and intersected recorded exec PIDs with the workload PID list. **100 of 100 workload PIDs matched (100%)**. The earlier manual two-terminal test matched only 89/100 and had its 11 missing PIDs clustered at the end of the workload (last observed exec PID 1134226; final workload PID 1134238), consistent with the monitoring window ending before workload completion. This supports a timing/coordination explanation but does not prove it definitively or guarantee lossless eBPF capture. CPU and memory overhead for the synchronized active trial were **not measured**.\n\n**Next phase : resource overhead:** Measure CPU time and peak RSS for each monitor with comparable workloads, multiple trials, and explicit test duration. GNU `/usr/bin/time` can report user CPU (`%U`), system CPU (`%S`), elapsed wall time (`%e`), and maximum resident set size in KB (`%M`). When using wrappers such as `sudo`, `timeout`, or a shell, verify which process is actually being measured; wrapper measurements must not be labeled as the monitor's memory usage. Peak RSS is not the same as total memory footprint, and eBPF kernel memory is not fully represented by a userspace loader's RSS. Report sampling workload and output/logging costs separately where possible.

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

## Implementation status and possible future work

1. **Complete:** /proc snapshot with root and /tmp review flags.
2. **Complete:** structured eBPF ring-buffer execution events, including verified PPID tracking.
3. **Complete:** four successful detection trials covering 20/100 processes, 50/200 ms requested lifetimes, and 10/100 ms requested polling intervals.
4. **Recorded:** separate idle-monitoring CPU-time and RSS observations; these are not matched active-workload overhead experiments.
5. **Future work:** repeated matched trials and event-loss accounting. The CLI is now unified.
6. **Documentation:** completed final technical report is in [docs/final_report.md](docs/final_report.md).

## Course deliverables

- **Presentation dates previously noted:** November 11, 16, and 18, 2026; verify requirements for the enrolled section, especially EOL/online students.
- **Final report deadline previously noted:** December 1, 2026 at 11:59 PM via Gradescope.
- **Solo report requirement previously noted:** at least three single-spaced pages in 10-point font, excluding contribution table and AI statement. Verify against the current assignment.
- Suggested sections: abstract; motivation; implementation and OS concepts; experimental methodology; measured results and limitations; contribution table; AI assistance statement.

## AI assistance disclosure

ChatGPT was used as a supplementary tool during the development and documentation of this project. The final report contains the author's disclosure. Consult the instructor's assignment-specific requirements.

Additional documents: [proposal](docs/proposal.md), [architecture](docs/architecture.md), [evaluation plan](docs/evaluation_plan.md), [milestones](docs/milestones.md).
