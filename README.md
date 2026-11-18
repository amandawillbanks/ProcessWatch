# ProcessWatch: Linux Process Monitoring Using C and eBPF

**Course:** CSC 501 — Operating Systems, NC State University, Fall 2026  
**Author:** Amanda Willbanks (individual project)  
**Language:** C | **Platform:** Linux | **Interfaces:** `/proc`, eBPF, libbpf

## Project overview and scope

ProcessWatch is a lightweight Linux command-line process monitor developed for CSC 501. As proposed, it uses the Linux `/proc` filesystem to inspect current processes and an eBPF program attached to `sched_process_exec` to observe new program executions. It also marks processes with UID 0 (`ROOT`) and executable paths under `/tmp/` (`TMP_EXEC`) for informational review. **These flags are not malware verdicts.**

The project demonstrates process management, process states, parent-child relationships, Linux system interfaces, and communication from kernel space to a user-space C program. The completed application provides two subcommands in one executable; it is not a continuous combined dashboard.

The original proposal's core phases—`/proc` monitoring, eBPF integration, security checks, and controlled testing/documentation—are implemented. CPU utilization, termination-event monitoring, and other proposed *potential extensions* are not part of the implemented scope. The snapshot additionally reports resident memory (RSS) when available.

## Source code and file inventory

| Path | Purpose |
| --- | --- |
| `src/main.c` | Unified `snapshot` and `monitor` command-line entry point |
| `src/process.c`, `include/process.h` | Enumerate numeric `/proc` directories; read process metadata and executable paths |
| `src/security.c`, `include/security.h` | Informational `ROOT` and `TMP_EXEC` flags |
| `ebpf/process_exec.bpf.c` | eBPF program attached to the scheduler's process-execution tracepoint |
| `ebpf/process_event.h` | Shared kernel/user-space event record |
| `ebpf/loader.c` | Load/attach BPF object and consume events through libbpf ring buffer |
| `tests/test_process.c` | Process reader and security flag assertions |
| `tests/workload.sh` | Sequential `/bin/sleep` executions with known child PIDs |
| `scripts/benchmark.sh` | One controlled snapshot/eBPF comparison; saves logs and matched PID counts |
| `scripts/run_trials.sh` | Repeat benchmarks and append results to CSV |
| `results/detection_trials.csv` | Raw per-trial detection counts, rates, and benchmark directory references |
| `results/benchmark-*/` | Detailed per-run logs, expected and observed PID sets, and summary |
| `docs/final_report.md` | Final-report manuscript for PDF preparation |
| `Makefile` | Build and test targets |

The generated `ebpf/vmlinux.h` comes from the host's BTF data and is intentionally not committed. Compiled binaries and object files are also generated locally.

## Experimental platform

The following configuration was recorded from the NC State Virtual Computing Lab machine used for the November 18, 2026 experiments:

| Property | Value |
| --- | --- |
| Environment | NC State VCL virtual machine |
| Operating system | Ubuntu 24.04.5 LTS |
| Kernel | `6.8.0-147-generic` |
| CPU architecture | x86_64 |
| Processor | Intel Xeon Processor (Skylake, IBRS) |
| Virtual CPUs | 4 |
| Installed RAM | 7.8 GiB |
| Swap | 2.0 GiB |
| Virtualization | KVM |

Exact installed compiler and libbpf package versions were not captured with these system specifications. Check versions on the host with `gcc --version`, `clang --version`, `bpftool version`, and `pkg-config --modversion libbpf`.

## Prerequisites and installation

Use an Ubuntu Linux host with `/proc`, BTF at `/sys/kernel/btf/vmlinux`, and permission to load/attach eBPF programs. The eBPF monitor generally needs `sudo` on the VCL VM.

```bash
sudo apt update
sudo apt install -y build-essential pkg-config clang llvm bpftool libbpf-dev libelf-dev zlib1g-dev gawk coreutils procps
test -r /sys/kernel/btf/vmlinux && echo "Kernel BTF available"
```

## Build and test

From the repository root:

```bash
make clean
make ebpf
make test
```

`make ebpf` generates the BTF-derived header, builds `build/process_exec.bpf.o`, and compiles `build/processwatch` with libbpf. `make test` runs C assertions and shell syntax checks. Successful builds, unit tests, and manual monitoring checks were observed on the VCL host on November 18, 2026. Unit tests do not themselves prove successful kernel tracepoint attachment.

## Run ProcessWatch

**Current-process snapshot:**

```bash
./build/processwatch snapshot
```

The snapshot shows PID, PPID, UID, state, RSS (KB), name, flags, and executable path. A process can exit during scanning, and permissions can prevent reading a process or resolving its executable. `[unavailable]` is not a security finding.

**Live execution events:**

```bash
sudo ./build/processwatch monitor
```

In another terminal:

```bash
/bin/sleep 2
```

The monitor prints records in this format:

```text
EXEC PID=12345 PPID=12000 UID=1000 COMM=sleep TIME=895041159715633
```

The numbers above are illustrative. `TIME` is a monotonic kernel timestamp in nanoseconds, not a wall-clock time. Stop with Ctrl+C. The BPF program captures `sched_process_exec` events and sends records to user space through a ring buffer. Repeated `exec` calls can generate multiple events for the same PID.

## Controlled evaluation and reproducibility

The workload runs sequential `/bin/sleep` child processes and records their PIDs. The benchmark starts the eBPF monitor, repeatedly runs the snapshot command, and intersects each monitor's observed PID set with the known workload PIDs. A detection rate is `matched workload PIDs / workload PIDs × 100`. Unrelated process activity is excluded from this rate.

Reproduce the three evaluated configurations:

```bash
bash scripts/run_trials.sh 3 100 0.05 0.1
bash scripts/run_trials.sh 3 100 0.2 0.1
bash scripts/run_trials.sh 3 100 0.05 0.01
```

Each command appends new trial rows to `results/detection_trials.csv`; it does not replace previous measurements. Existing data include six short-lifetime/slow-polling trials (three earlier and three on November 18), plus three trials for each of the other configurations. Trial numbers restart at 1 for each invocation and are **not globally unique**. Identify a trial using its configuration and `result_directory`.

Each benchmark directory contains `summary.txt`, `ebpf.log`, `workload_pids.txt`, `snapshot_pids.txt`, `expected.sorted`, `snapshot.sorted`, `ebpf.sorted`, and a monitor PID file when generated. The committed CSV and detailed logs constitute the underlying data for the table below; no plotted figures are included or required to reproduce this table.

### Recorded detection results (12 trials; 100 executions per trial)

| Requested lifetime | Requested polling delay | Trials | Snapshot detections (total) | eBPF detections (total) | Mean snapshot rate | Mean eBPF rate |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 50 ms | 100 ms | 6 | 251 / 600 | 600 / 600 | 41.83% | 100% |
| 200 ms | 100 ms | 3 | 300 / 300 | 300 / 300 | 100% | 100% |
| 50 ms | 10 ms | 3 | 300 / 300 | 300 / 300 | 100% | 100% |

**How to regenerate the table:** Read `results/detection_trials.csv`, group rows by `requested_lifetime_s` and `requested_poll_interval_s`, sum `snapshot_detected`, `ebpf_detected`, and `workload_count`, and divide detected totals by workload totals. All trials have 100 expected executions, so the pooled rates equal the means of per-trial rates within each configuration. For example, the 50 ms/100 ms snapshot rate is `251 / 600 × 100 = 41.83%`. Individual per-trial counts and corresponding detailed logs are in the CSV and its `result_directory` entries.

These are **requested** sleep durations and polling delays, not independently measured exact process lifetimes or sampling intervals. The benchmark does not measure CPU or memory overhead. In this workload, slower polling missed many short-lived executions; longer lifetimes or faster polling produced full observed coverage. eBPF matched all expected workload PIDs in these trials, but that does not establish lossless event delivery under other conditions.

## Methodological limitations

- Snapshot enumeration and `exec` event collection measure different operating-system behaviors.
- The workload is sequential `sleep` processes, not representative of all real workloads.
- PID-set matching can be affected by PID reuse and repeated executions.
- The actual polling cadence and process lifetimes were not independently timed.
- The BPF implementation does not count dropped ring-buffer events.
- CPU/RSS overhead was not measured as part of these 12 controlled trials; no comparative overhead conclusion is claimed.
- The security flags are simple metadata indicators, not a malware detector.

## Final CSC 501 submission

**Deadline:** December 1, 2026, 11:59 PM. The required submission includes the final report PDF, presentation, and **GitHub Classroom repository**. This personal repository is a development workspace, not the final submission repository.

Accept the [course GitHub Classroom invitation](https://classroom50.org/ncsu-csc-501/csc-501-operating-systems/assignments/semester-project/accept), transfer the verified code, tests, CSV, and referenced raw benchmark directories, then record the Classroom repository URL and exact final commit hash in the PDF report.

**Classroom repository URL:** PENDING — fill in after Classroom repository creation  
**Final Classroom commit hash:** PENDING — record after final push

The final report includes a contribution table and an AI-use disclosure. No source-code features beyond the original proposal are required to reproduce the documented evaluation.
