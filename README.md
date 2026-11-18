# ProcessWatch: Linux Process Monitoring Using C and eBPF

**Course:** CSC 501 — Operating Systems, NC State University, Fall 2026  
**Team member:** Amanda Willbanks (individual project)  
**Submission repository:** Use the GitHub Classroom repository created through the course invitation, **not** this personal development repository.  
**Status:** Unified CLI changes are awaiting build and benchmark verification on NC State VCL. Historical measurements below have not been rerun.

## Overview

ProcessWatch is a C-based Linux process monitor that compares point-in-time process snapshots from `/proc` with event-driven execution monitoring via an eBPF `sched_process_exec` tracepoint. Its goal is to quantify how often periodic polling misses short-lived processes compared with kernel execution events. The snapshot also shows informational `ROOT` and `TMP_EXEC` review flags. These flags do **not** establish malicious activity.

The unified command-line executable provides `snapshot` and `monitor` modes. The monitor loads a separately compiled eBPF object and receives structured events over a libbpf ring buffer.

## Your code: source inventory and provenance

This project was developed for CSC 501 rather than forked from an existing application. It uses the Linux kernel's documented `/proc` interface and scheduler tracepoint, plus libbpf, but does **not** modify Linux kernel source.

| Path | Role |
| --- | --- |
| `src/main.c` | Unified CLI entry point: `snapshot` and `monitor` |
| `src/process.c`, `include/process.h` | Enumerate `/proc`; read process status and executable path |
| `src/security.c`, `include/security.h` | Informational root UID and temporary executable flags |
| `ebpf/process_exec.bpf.c` | Kernel-side execution tracepoint and ring-buffer event producer |
| `ebpf/process_event.h` | Shared event structure |
| `ebpf/loader.c` | libbpf object loading, tracepoint attachment, event consumption |
| `tests/test_process.c` | C assertions for `/proc` parsing and security checks |
| `tests/workload.sh` | Sequential short-lived process workload; records expected PIDs |
| `scripts/benchmark.sh` | Single synchronized snapshot-versus-eBPF detection trial |
| `scripts/run_trials.sh` | Repeated trials and CSV export |
| `Makefile` | Build and test rules |
| `docs/` | Proposal, architecture, evaluation plan, report drafts |

The generated `ebpf/vmlinux.h` is derived from the **running host kernel's** BTF information; it is not hand-authored source and is regenerated during the build. The implementation depends on the host Linux kernel rather than embedding or changing a kernel version.

## Dependencies and installation

**Target:** Ubuntu 24.04 LTS, x86_64 Linux, with a BTF-enabled kernel and permissions to load and attach BPF programs. Earlier development notes recorded kernel `6.8.0-147-generic`; confirm the actual kernel used for the final experiments.

Install prerequisites using these step-by-step commands:

```bash
sudo apt update
sudo apt install -y build-essential pkg-config clang llvm bpftool libbpf-dev libelf-dev zlib1g-dev gawk coreutils procps
```

The project was developed using Clang 18; Ubuntu's available versions of GCC, Make, bpftool and libbpf can be inspected with the commands below. **Exact final dependency versions must be recorded from the VCL machine**, rather than assumed from the package list.

```bash
gcc --version | head -n 1
clang --version | head -n 1
make --version | head -n 1
bpftool version
pkg-config --modversion libbpf
```

The eBPF build requires `/sys/kernel/btf/vmlinux`. The monitor generally requires `sudo` on the teaching VM. Run both monitors on the **Linux host**, not inside a Xinu guest.

## System used for evaluation

| Property | Recorded / to verify |
| --- | --- |
| Platform | NC State Virtual Computing Lab (VCL), virtual machine |
| Operating system | Ubuntu 24.04 LTS |
| CPU architecture | x86_64 |
| Kernel | Previously observed `6.8.0-147-generic`; verify on final test machine |
| CPU model / vCPU count | **Record after running the commands below** |
| RAM | **Record after running the commands below** |
| Hypervisor / VM type | VCL VM; underlying hypervisor not yet documented |
| Compiler | Clang 18 reported during development; verify final environment |

Capture the final system information:

```bash
uname -a
cat /etc/os-release
lscpu
free -h
systemd-detect-virt || true
test -r /sys/kernel/btf/vmlinux && echo "BTF available"
```

Copy the relevant CPU, memory, OS, kernel, and VM details into this section **before final submission**.

## Build

From the repository root, after installing dependencies:

```bash
make clean
make ebpf
make test
```

`make ebpf` generates `ebpf/vmlinux.h` from the host's BTF data, compiles `build/process_exec.bpf.o`, and builds the unified `build/processwatch` executable linked against libbpf. `make test` runs C assertions and shell syntax checks; it is **not** an end-to-end eBPF integration test. `make clean` removes generated build files and the generated BTF header.

## Run

For a current process snapshot:

```bash
./build/processwatch snapshot
```

The output includes PID, PPID, UID, state, resident memory (KB), name, flags and executable path. Processes that disappear or cannot be read may be skipped; `[unavailable]` means the executable path could not be resolved.

For live execution events, from the repository root:

```bash
sudo ./build/processwatch monitor
```

In a **second terminal**, run:

```bash
/bin/sleep 2
```

The monitor should display an event resembling:

```text
EXEC PID=1125264 PPID=1117695 UID=510249 COMM=sleep TIME=895041159715633
```

Values will vary. `TIME` is a monotonic kernel timestamp in nanoseconds, **not** a calendar time. Stop monitoring with Ctrl+C. Each `exec` event is not necessarily a distinct PID.

## Reproduce the experiments and save raw data

**Single detection trial** — 20 sequential processes, requested 50 ms lifetime, 100 ms snapshot delay:

```bash
bash scripts/benchmark.sh 20 0.05 0.1
```

**Repeated trials** — three repetitions of 100 processes each:

```bash
bash scripts/run_trials.sh 3 100 0.05 0.1
```

The scripts start the eBPF monitor with `sudo`, sample the snapshot command, generate a known-PID workload, and compare matched PIDs. Each single run creates a `results/benchmark-XXXXXXXX/` directory containing `summary.txt`, `ebpf.log`, `workload_pids.txt`, `snapshot_pids.txt` and intermediate sorted PID sets. Repeated runs append rows to `results/detection_trials.csv`.

**Important:** Run `make ebpf` first and verify the monitor works. The scripts have not yet been rerun following the unified CLI update. Requested timing values are not measured exact durations; the scripts do **not** measure CPU/RSS overhead.

## Figures and tables: reproduction map

| Report output | Raw input | Generator / procedure | Status |
| --- | --- | --- | --- |
| Detection-rate comparison table | `results/detection_trials.csv` | `bash scripts/run_trials.sh 3 100 0.05 0.1` generates CSV; calculate percentages from its rate columns | Trial script exists; new data pending |
| Per-trial detection counts | `results/benchmark-*/summary.txt` and PID lists | `bash scripts/benchmark.sh 100 0.05 0.1` | Trial script exists; new data pending |
| Detection-rate figure | `results/detection_trials.csv` | **Plotting script not yet implemented; add and document its command before submission** | Pending |
| Resource-overhead table or figure | New raw CPU/RSS measurements | **Matched measurement and plotting scripts not yet implemented** | Pending; do not present historical notes as reproducible raw data |

The instructor requires **scripts for each plotted figure** and **the raw data used to plot it**. Once benchmarks are run, commit the actual CSV/logs or provide a working location and explicit regeneration instructions if large. Do not claim the historical figures below can be regenerated from files that are not committed.

## Previously recorded results (historical, not the new benchmark run)

| Workload | Requested lifetime | Requested polling delay | Snapshot detected | eBPF detected |
| ---: | ---: | ---: | ---: | ---: |
| 20 | 50 ms | 100 ms | 8/20 (40%) | 20/20 (100%) |
| 100 | 50 ms | 100 ms | 42/100 (42%) | 100/100 (100%) |
| 100 | 200 ms | 100 ms | 100/100 (100%) | 100/100 (100%) |
| 100 | 50 ms | 10 ms | 100/100 (100%) | 100/100 (100%) |

These are single user-recorded November 8, 2026 runs, not means or newly reproduced results. Raw logs for those historical runs were not confirmed in GitHub. They show that snapshots can miss short-lived processes when polling is slow, whereas more frequent polling can improve detection. They do **not** establish lossless eBPF delivery or a matched resource-overhead comparison.

## Methodology, interpretation and limitations

The workload records expected child PIDs. Snapshot polling enumerates currently visible processes, whereas eBPF captures **execution events** at `sched_process_exec`. Both observed PID sets are intersected with the workload PID set to exclude unrelated processes. A snapshot can miss a process that exits between scans; event-driven monitoring can capture its execution if the monitor is active and the ring buffer delivers the event.

Limitations include process-lifetime and scheduling variability, different observation semantics, potential PID reuse, lack of eBPF dropped-event accounting, and the absence of matched CPU/memory measurements in the current benchmark. Reported idle CPU/RSS observations are historical and should not be presented as equivalent matched comparisons. Repeated trials and figure scripts are still pending final verification.

## Final submission and provenance

**Deadline:** December 1, 2026, 11:59 PM (report PDF, slides, and Classroom repository). Accept the [GitHub Classroom invitation](https://classroom50.org/ncsu-csc-501/csc-501-operating-systems/assignments/semester-project/accept), transfer the validated project into that Classroom repository, and push all source, experiment scripts, raw data and figure scripts before the deadline.

**Classroom repository URL:** TO BE FILLED IN  
**Final graded commit hash:** TO BE FILLED IN AFTER FINAL PUSH

Put the **Classroom repository URL and exact final commit hash** in the PDF report. Include a contribution table (one row for the individual author) and an AI-use statement naming ChatGPT and its use for code drafting, debugging, scripts, review and documentation, with all work understood and verified by the author.

See `docs/final_report.md` for the existing draft report. That draft still describes the old separate-executable architecture and must be updated before submission.
