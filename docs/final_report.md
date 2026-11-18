# ProcessWatch: Linux Process Monitoring Using C and eBPF

**CSC 501 — Operating Systems | North Carolina State University | Fall 2026**  
**Author:** Amanda Willbanks | **Individual project**  
**Report status:** Final manuscript for PDF formatting; Classroom repository URL and final commit hash remain to be filled in after submission repository creation.

## Abstract

ProcessWatch is a lightweight Linux process-monitoring application written in C. In accordance with the project proposal, it combines point-in-time process information from the Linux `/proc` filesystem with real-time execution-event monitoring using eBPF and libbpf. It also provides informational flags for processes with root privileges and executables located under `/tmp/`. A controlled evaluation compared periodic snapshots against eBPF events using known-PID workloads. Across 12 trials containing 1,200 total process executions, snapshot monitoring detected 251 of 600 short-lived processes (41.83%) at a requested 100 ms polling delay, while eBPF detected 600 of 600. When processes remained alive for a requested 200 ms, or polling delay was reduced to 10 ms, both approaches matched all 300 expected PIDs in each configuration. These results demonstrate the sampling limitations of periodic monitoring under the tested conditions without implying that eBPF delivery is universally lossless.

## 1. Introduction and objectives

Linux provides different interfaces for observing processes. The `/proc` filesystem exposes information about processes currently present, while kernel tracepoints can notify instrumentation programs about specific events. The ProcessWatch project was proposed to explore both approaches in one C application and connect classroom topics to a functioning Linux system.

The original project objectives were to (1) build a C process monitor; (2) retrieve active-process information from `/proc`; (3) detect process execution through eBPF; (4) identify UID 0 processes; (5) inspect executable locations and flag paths under `/tmp`; and (6) demonstrate communication from a kernel-level eBPF program to user space. The completed implementation addresses these objectives. Optional extensions such as CPU utilization and process termination tracing were not part of the required implementation.

## 2. System design and implementation

### 2.1 Architecture and command-line interface

ProcessWatch provides two subcommands in the same executable:

```bash
./build/processwatch snapshot
sudo ./build/processwatch monitor
```

The `snapshot` mode invokes the process enumerator in `src/process.c`. The `monitor` mode invokes the libbpf loader in `ebpf/loader.c`, which loads the compiled eBPF object and streams execution records. These modes share a command-line entry point but collect different types of observations; they are not a simultaneous unified display.

### 2.2 Process information through /proc

The snapshot collector opens `/proc`, identifies numeric process directories, and reads `/proc/<pid>/status`. It extracts the process name, PID, parent PID (PPID), state, UID, and resident memory (`VmRSS`, when available). It also attempts to resolve the `/proc/<pid>/exe` symbolic link to the executable path.

The displayed columns are PID, PPID, UID, state, RSS in KB, name, security flags, and executable path. Processes that terminate during enumeration or cannot be read may be skipped; an executable path that cannot be resolved is displayed as `[unavailable]`. This behavior reflects the changing process table and access restrictions of Linux.

### 2.3 eBPF execution monitoring and kernel-to-user communication

The eBPF source `ebpf/process_exec.bpf.c` attaches to the `sched_process_exec` tracepoint. On an execution event, the BPF program records PID, PPID, UID, command name, and a monotonic nanosecond timestamp. It places the event into a BPF ring buffer. The user-space loader opens and loads the BPF object, attaches the tracepoint, polls the ring buffer through libbpf, and prints each received event.

The event format is `EXEC PID=... PPID=... UID=... COMM=... TIME=...`. The timestamp is monotonic kernel time, not a human-readable calendar time. Execution events are distinct from process creation: an existing PID may execute a different program, and the same PID may generate more than one `exec` event.

### 2.4 Informational security checks

The snapshot applies two flags implemented in `src/security.c`:

| Flag | Rule | Interpretation |
| --- | --- | --- |
| `ROOT` | Process UID equals 0 | Indicates root privileges; not inherently suspicious |
| `TMP_EXEC` | Resolved executable path begins with `/tmp/` | Indicates execution from a temporary directory; requires context |

These checks provide security-relevant process metadata but do not label a process as malicious. If the executable path is unavailable, the `TMP_EXEC` condition cannot be evaluated reliably.

### 2.5 Relationship to CSC 501 concepts

The implementation illustrates process management through PID/PPID relationships and execution behavior; process states through `/proc` metadata; kernel/user-space separation through the BPF program and user-space libbpf loader; operating-system interfaces through procfs and scheduler tracepoints; and basic security observations through UID and executable-path inspection.

## 3. Development and verification

### 3.1 Evaluation environment

The NC State Virtual Computing Lab environment recorded on November 18, 2026 was:

| Component | Configuration |
| --- | --- |
| Operating system | Ubuntu 24.04.5 LTS |
| Kernel | `6.8.0-147-generic` |
| Processor | Intel Xeon Processor (Skylake, IBRS) |
| CPU allocation | 4 virtual CPUs, x86_64 |
| Memory | 7.8 GiB RAM; 2.0 GiB swap |
| Virtualization | KVM |

Build dependencies include GCC, Make, Clang/LLVM, bpftool, libbpf development libraries, libelf, zlib, and pkg-config. Exact package version numbers were not captured for this report and should not be inferred from the operating-system release.

### 3.2 Build and functional tests

From the repository root:

```bash
make clean
make ebpf
make test
./build/processwatch snapshot
sudo ./build/processwatch monitor
```

`make ebpf` generates the host BTF-derived `vmlinux.h`, compiles the kernel-side BPF object, and builds the unified user-space executable. `make test` executes C assertions covering process reading and security checks and checks shell-script syntax. The build and tests completed successfully on the VCL host on November 18, 2026. Manual checks also confirmed that snapshot mode printed process metadata and monitor mode displayed execution events when test programs were launched.

The test suite is not a substitute for the manual eBPF attachment test because loading kernel programs requires a suitable Linux kernel and permissions.

## 4. Experimental evaluation

### 4.1 Methodology

The controlled workload in `tests/workload.sh` executes sequential `/bin/sleep` processes and records the child PIDs as the expected set. The `scripts/benchmark.sh` script starts the eBPF monitor, repeatedly invokes `./build/processwatch snapshot`, executes the workload, then stops monitoring and calculates how many expected PIDs appeared in each observation stream. The comparison uses intersections of unique observed PIDs with the expected workload PIDs, excluding unrelated background activity.

The repeated-trial wrapper `scripts/run_trials.sh` saves counts and percentages in `results/detection_trials.csv` and references the detailed logs in `results/benchmark-*/`. Requested sleep durations and polling delays are experimental settings; exact timing was not independently instrumented. Each trial includes 100 expected workload executions.

### 4.2 Detection results

The committed dataset contains 12 trials: six trials at 50 ms lifetime/100 ms polling, three at 200 ms lifetime/100 ms polling, and three at 50 ms lifetime/10 ms polling.

**Table 1. Detection rates for the three evaluated workload configurations (12 trials).**

| Requested lifetime | Requested polling delay | Trials | Snapshot detections | eBPF detections | Snapshot rate | eBPF rate |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 50 ms | 100 ms | 6 | 251/600 | 600/600 | 41.83% | 100% |
| 200 ms | 100 ms | 3 | 300/300 | 300/300 | 100% | 100% |
| 50 ms | 10 ms | 3 | 300/300 | 300/300 | 100% | 100% |

**Table 1 reproduction:** Run `python3 scripts/table_results.py` from the repository root. The raw data are in `results/detection_trials.csv`. Group the rows by requested lifetime and polling delay, sum the expected and detected counts, and compute `100 × detected / expected`. For example, the six 50 ms/100 ms trials detected 41, 42, 42, 42, 41, and 43 workload PIDs in snapshots: `251 / 600 × 100 = 41.83%`. The corresponding eBPF counts were 100 in every trial. The individual `result_directory` paths point to the raw event logs, snapshot PID lists, expected PID lists, and run summaries. The table is generated from the committed CSV by a Python standard-library script; no plotted figures are included.

### 4.3 Interpretation

As shown in Table 1, for short-lived processes at a requested 100 ms snapshot delay, the periodic snapshot monitor missed many workload PIDs. A process can execute and exit between snapshots, making it invisible to a point-in-time scan. The eBPF collector matched all expected workload PIDs in those six trials because it observes execution events rather than depending on the process still existing at a later snapshot.

Two controlled changes improved snapshot detection. Extending requested lifetime to 200 ms gave the snapshot collector more opportunity to observe each process. Reducing requested polling delay to 10 ms likewise increased observation opportunities for 50 ms processes. Under both configurations, snapshot and eBPF monitoring matched all expected PIDs in three trials each. These results illustrate a trade-off in observation strategy; they do not establish that the two mechanisms are identical or that either is infallible.

### 4.4 Limitations

The experiments use sequential `sleep` processes rather than a varied production workload. The monitors observe different semantics: `/proc` provides current process state, whereas the eBPF tracepoint reports program execution. Detection is calculated from unique PIDs, which can be affected by PID reuse and multiple executions under one PID. Exact scheduling intervals and process lifetimes were not measured. The BPF implementation does not count dropped ring-buffer events, so 100% detection in these trials is not a general losslessness guarantee. The controlled benchmark did **not** measure CPU utilization or memory overhead, so no quantitative overhead comparison is claimed.

## 5. Conclusion

ProcessWatch achieved the objectives of its CSC 501 proposal: a C-based Linux process monitor, current-process information through `/proc`, real-time execution-event observation using eBPF and libbpf, and informational root-privilege and temporary-executable flags. The controlled evaluation shows how snapshot timing affects detection of short-lived processes, while kernel event monitoring provides a complementary perspective on execution activity. The project demonstrates process management, kernel/user-space communication, and Linux system interfaces through a working command-line application.

Potential future work, beyond the original required scope, could include CPU utilization, process termination events, and more detailed resource-overhead evaluation. These are not represented as completed features.

## Individual contribution

| Contributor | Contributions |
| --- | --- |
| Amanda Willbanks | Project proposal and scope; C process snapshot and security checks; eBPF/libbpf monitoring; VCL compilation and functional testing; workload experiments and interpretation; repository and report review. |

## Submission and reproducibility

**Repository URL:** https://github.com/amandawillbanks/ProcessWatch (personal repository supplied to instructor because GitHub Classroom is retired; instructor acceptance should be retained).  
**Exact final main-branch commit hash:** PENDING — insert after final merge and verification.

The repository should contain source code, build/test instructions, experiment scripts, `results/detection_trials.csv`, and the benchmark directories referenced by the CSV. See `README.md` for installation, run commands, and table reproduction. Convert this manuscript to the required PDF and include the final repository URL and exact commit hash before submission.

## AI-use disclosure

ChatGPT (OpenAI) assisted with code drafting, debugging suggestions, benchmark scripting, README and report drafting, and review of implementation and experimental output. The project author ran the program and experiments on the NC State VCL environment, inspected the outputs, and is responsible for verifying the submitted work. AI assistance is disclosed rather than presented as independent human-only authorship.
