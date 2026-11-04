# ProcessWatch

**CSC 501 — Operating Systems | NC State University | Fall 2026**

**Status: In development — `/proc` snapshot monitoring implemented and initial eBPF process-execution monitoring previously tested.** Integrated event collection, security heuristics, automated tests, and comparative measurements remain unfinished.

## Project overview

ProcessWatch is a Linux command-line process monitoring and security-analysis project written primarily in C. It aims to compare periodic snapshots of running processes from Linux `/proc` with event-driven eBPF process-execution monitoring.

**Research question:** Compared with periodic `/proc` polling, can eBPF-based process-execution monitoring detect short-lived process executions more reliably with acceptable monitoring overhead?

## Scope

- **Snapshot MVP (implemented):** Enumerate numeric `/proc/<pid>` directories and show PID, PPID, command name, state, resident memory (VmRSS in kB when available), and UID. Explicit root-status flags and executable-path resolution are not yet implemented.
- **Security heuristics (planned):** Flag UID 0 and executable paths under `/tmp` as **review signals, not proof of compromise**.
- **eBPF extension (initial implementation working):** Capture `sched_process_exec` tracepoint events using a kernel-side C program and a user-space `libbpf` loader. Currently prints PID messages through the kernel tracing buffer.
- **Evaluation (planned):** Compare polling and eBPF on a controlled workload, measuring detection count, missed short-lived executions, CPU overhead, and memory overhead across repeated trials.
- **Stretch goals:** CPU usage, event timestamps, filters, CSV export.

## Progress

### Completed — October 29, 2026

- Set up Ubuntu 24.04 LTS on NC State VCL and verified kernel BPF support, BTF, and sudo access.
- Installed and verified `bpftrace`, `bpftool`, Clang, and `libbpf` development tools.
- Captured `execve` events with a `bpftrace` smoke test.
- Implemented `ebpf/process_exec.bpf.c` with a `sched_process_exec` tracepoint handler.
- Implemented `ebpf/loader.c` to load and attach the program with `libbpf`.
- Compiled both components and observed ProcessWatch PID messages in the kernel trace buffer when test programs ran.

### Completed — November 4, 2026

- Added a C `/proc` snapshot reader in `src/process.c` and the `ProcessInfo` record in `include/process.h`.
- Added `snapshot` command handling in `src/main.c`, displaying PID, PPID, UID, state, RSS (kB), and process name.
- Replaced the placeholder Makefile with a build target for `build/processwatch` and a `clean` target.
- Committed these changes to `main` (`dacc4ab`). Build and runtime behavior on the VCL host have not been independently re-verified as part of this documentation update.

### Next steps

1. Test and validate the snapshot executable on the Linux VCL host, including process-exit and permission edge cases.
2. Add review-only root UID and `/tmp` executable-path flags.
3. Replace debug-only `bpf_printk()` output with structured events consumed by the user-space application.
4. Add reproducible eBPF Makefile targets, automated tests, and controlled workloads.
5. Run controlled comparisons, record measurements, and discuss limitations.

## Development environment

| Component | Verified environment |
|---|---|
| Operating system | Ubuntu 24.04 LTS (NC State VCL) |
| Kernel | 6.8.0-147-generic |
| Architecture | x86_64 |
| Language | C |
| bpftrace | 0.20.2 |
| bpftool | 7.4.0 |
| Clang | 18.1.3 |
| eBPF library | libbpf |
| Editor / connection | VS Code Remote SSH |

## Architecture

```text
Linux host (NOT Xinu guest)
  /proc/<pid>/status --> C snapshot reader --> terminal process table (implemented)

  kernel sched_process_exec --> eBPF program --> libbpf loader
                                  |
                           bpf_printk trace messages (previously tested)

  Structured event collection, flags, and combined analysis: planned
```

The working loader attaches the kernel program, but it does **not yet** collect structured events or combine them with the `/proc` reader. Xinu runs in QEMU for other CSC 501 work; Linux `/proc` and eBPF are not APIs inside the Xinu guest. Confirm the Linux-host choice with the instructor if required.

## Repository layout

```text
src/        main.c, process.c, security.c
include/    process.h, security.h
ebpf/       process_exec.bpf.c, loader.c
tests/      test_process.c, workload.sh
scripts/    benchmark.sh
results/    measurements.csv
docs/       proposal.md, architecture.md, evaluation_plan.md,
            setup.md, milestones.md, presentation.md, final_report.md
Makefile    builds the `/proc` snapshot executable; eBPF build remains manual
```

Some files are starter scaffolding and are not yet functional.

## Build and run — `/proc` snapshot monitor

From the repository root on Linux, with `gcc` and `make` installed:

```bash
make clean
make
./build/processwatch snapshot
```

The output is a point-in-time table with `PID`, `PPID`, `UID`, `STATE`, `RSS(KB)`, and `NAME`. Processes that exit during scanning or whose required status fields cannot be read are skipped. `RSS(KB)` displays `0` when `VmRSS` is absent, so zero is not necessarily a measured resident-memory value. The snapshot mode does not yet flag root processes or resolve executable paths. `make clean` removes the generated `build/` directory, including any manually compiled eBPF artifacts.

## Build and run — initial eBPF monitor

Run these commands from the repository root on a compatible Linux host. They require installed `bpftool`, Clang with BPF target support, `gcc`, `libbpf-dev`, `libelf-dev`, and `zlib1g-dev`. The generated `ebpf/vmlinux.h` and compiled `build/` files are ignored by Git.

### 1. Generate kernel type definitions

```bash
sudo bpftool btf dump file /sys/kernel/btf/vmlinux format c > ebpf/vmlinux.h
```

### 2. Compile the kernel-side eBPF program

```bash
mkdir -p build
clang -O2 -g -target bpf -D__TARGET_ARCH_x86 \
  -I./ebpf -I/usr/include/x86_64-linux-gnu \
  -c ebpf/process_exec.bpf.c \
  -o build/process_exec.bpf.o
```

### 3. Compile the user-space loader

```bash
gcc -Wall -Wextra -O2 \
  ebpf/loader.c \
  -o build/processwatch-loader \
  -lbpf -lelf -lz
```

### 4. Run and observe

In terminal 1:

```bash
sudo ./build/processwatch-loader
```

In terminal 2:

```bash
sudo cat /sys/kernel/tracing/trace_pipe
```

In terminal 3:

```bash
/bin/ls
/bin/echo "Testing ProcessWatch"
```

Look for `ProcessWatch: process executed, PID=...` in the trace output. Press **Ctrl+C** to stop the trace reader and loader. The trace buffer can contain messages from other tracing activity on the host.

**Current limitation:** The loader attaches the eBPF program but does not display process events itself; the kernel program uses `bpf_printk()` for debugging output. The Makefile currently builds only the `/proc` snapshot executable; the eBPF build commands remain manual.

## Evaluation plan

Use a controlled workload to compare periodic `/proc` snapshots with eBPF execution events. Planned measurements include total executions generated, detections and missed short-lived executions, CPU overhead, memory overhead, and variation across repeated trials. **No comparative results have been measured yet.**

## Operating systems relevance

ProcessWatch explores process management, the `/proc` interface, kernel versus user space, kernel execution tracepoints, and the overhead of observing operating-system behavior. It relates to CPU virtualization and scheduling but does not itself implement a scheduler.

## Course deliverables

- **Presentation window:** November 11, 16, and 18, 2026; 5 minutes for solo projects. Course notice says EOL students do not present; confirm section requirements.
- **Final report:** December 1, 2026 at 11:59 PM, Gradescope. Solo: 3+ single-spaced pages, 10-point font, excluding contribution table and AI statement.
- **Code:** GitHub repository with reproducible build/run instructions.
- **Report sections:** Abstract; motivation and idea; technical detail; evaluation (setup, baseline, measured numbers); contribution table; AI-use statement.

## AI assistance and academic integrity

AI assistance was used for implementation guidance, C/eBPF examples, compilation instructions, troubleshooting, and documentation drafting. The author must review, understand, and be able to explain all submitted code and text. Actual AI use will be documented in the final report in accordance with course requirements.

See [proposal](docs/proposal.md), [architecture](docs/architecture.md), [evaluation plan](docs/evaluation_plan.md), and [milestones](docs/milestones.md).
