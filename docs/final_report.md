# ProcessWatch: Linux Process Monitoring Using C and eBPF

**CSC 501: Operating Systems | NC State University | Fall 2026**  
**Individual project | Report prepared November 17, 2026**

## Abstract

ProcessWatch is a Linux process monitoring project that compares periodic snapshots of the proc filesystem with execution-event monitoring through extended Berkeley Packet Filter (eBPF). The implementation consists of a C program that enumerates processes and reports metadata, a kernel eBPF tracepoint program that captures process executions, a libbpf user-space loader, and informational security review indicators. Controlled workloads generated known process identifiers to compare detection coverage. In four recorded configurations, eBPF matched all 20 or 100 workload PIDs; snapshots detected 8 of 20 and 42 of 100 processes when requested process lifetime was 50 ms and snapshot delay was 100 ms, but detected all 100 processes when either lifetime increased to 200 ms or polling delay decreased to 10 ms. Separate idle-monitoring measurements demonstrate that more frequent polling used more CPU time. These observations illustrate monitoring trade-offs but are not a matched, repeated full-system performance comparison.

## 1. Motivation and Research Question

Linux exposes information about currently running processes through the proc filesystem. A program can enumerate numeric directories under `/proc` and read files such as `/proc/<pid>/status` to obtain process identity, ownership, state, and memory information. This approach is accessible and does not require kernel instrumentation, but each snapshot only observes processes that still exist when they are scanned. Short-lived programs may begin and exit between snapshots.

An event-driven alternative is to attach an eBPF program to a kernel tracepoint. Rather than repeatedly scanning the process table, the program receives notifications when an execution event occurs. ProcessWatch explores the following question: **How well does eBPF execution-event monitoring capture short-lived program executions compared with periodic proc snapshots, and what resource-use trade-offs are visible in the recorded observations?** This is an educational comparison of distinct observation mechanisms, not a general malware detection or production security product.

## 2. Technical Design and Implementation

### 2.1 Environment and architecture

The project was developed on an NC State VCL Ubuntu 24.04 LTS x86_64 Linux environment. The README previously recorded kernel version 6.8.0-147-generic, with GCC, Make, Clang 18, bpftool, and libbpf used for development. The exact environment of every individual experiment was not independently archived in the GitHub results directory. The snapshot executable and the eBPF loader are separate command-line tools; the latter requires a compatible host kernel, BTF information, and sufficient permissions to load and attach BPF programs. Neither tool runs inside a Xinu guest.

### 2.2 Process snapshot collector

The snapshot implementation is in `src/process.c`, with its command-line entry point in `src/main.c`. Invoking `./build/processwatch snapshot` opens `/proc`, filters directory names to numeric PIDs, and reads each process's `status` file. The reader extracts process name, parent PID, UID, state, and resident memory in kilobytes when available. It also attempts to resolve `/proc/<pid>/exe` to an executable path. The output includes PID, PPID, UID, state, RSS, name, security flags, and executable path.

A process may terminate while enumeration is in progress, and access to some proc entries may be restricted. The implementation skips unreadable processes and marks unavailable executable paths rather than assuming the missing data indicates a threat. A zero RSS display can also indicate that the VmRSS field was unavailable.

### 2.3 Event-driven eBPF collector

The kernel component in `ebpf/process_exec.bpf.c` attaches to the `sched_process_exec` tracepoint. For each observed execution it obtains the PID, parent PID, UID, command name, and a monotonic kernel timestamp in nanoseconds. A BPF ring buffer transports the structured `process_event` record to user space. The libbpf loader in `ebpf/loader.c` opens and loads the compiled BPF object, attaches the tracepoint program, polls the ring buffer, and prints event records.

This event stream describes execution activity, whereas a proc snapshot describes processes present at a particular time. An `exec` operation replaces the executable image without changing the PID, so a PID may appear in more than one execution event. The event timestamp is not a wall-clock timestamp. The current implementation does not expose a ring-buffer dropped-event counter.

### 2.4 Informational security indicators

`src/security.c` implements two review flags. `ROOT` identifies a process whose UID is zero, and `TMP_EXEC` identifies an executable path beginning with `/tmp/`. These signals provide simple examples of how process metadata may support review. Neither root execution nor execution from a temporary directory proves malicious behavior. A path that cannot be resolved cannot be reliably classified by the temporary-path check.

### 2.5 Build, execution, and tests

On the documented Ubuntu host, required packages include GCC/build-essential, Make, Clang/LLVM, bpftool, libbpf development files, libelf, zlib, and pkg-config. From the repository root:

```bash
make
make ebpf
make test
./build/processwatch snapshot
sudo ./build/processwatch-loader
```

The default Make target builds the proc snapshot executable. The `make ebpf` target generates a `vmlinux.h` header from the host's BTF data when necessary and compiles the kernel object and loader. The `make test` target runs C assertions for process reading and security flag behavior and checks shell syntax. The project records prior successful test execution, but this report preparation did not rerun tests on the VCL host.

## 3. Experimental Evaluation

### 3.1 Workload and detection method

The controlled workload script `tests/workload.sh` launches a specified number of sequential `/bin/sleep` child programs and records their PIDs. The benchmark script starts the eBPF loader and a background loop that repeatedly invokes the snapshot executable. It then runs the workload, collects the observed PID sets, and intersects each set with the known workload PID list. Detection rate is calculated as matched workload PIDs divided by expected workload PIDs. Unrelated background processes are excluded from the final counts.

The reported sleep durations and polling intervals are **requested** delays, not independently measured exact process lifetimes or start-to-start snapshot intervals. Matching solely on PID is also imperfect in the presence of PID reuse or repeated execution within one process.

### 3.2 Recorded detection results

The repository README records the following individual experiments from November 8, 2026:

| Configuration | Workload | Requested lifetime | Requested snapshot delay | Snapshot detected | eBPF detected |
|---|---:|---:|---:|---:|---:|
| 1 | 20 | 50 ms | 100 ms | 8/20 (40%) | 20/20 (100%) |
| 2 | 100 | 50 ms | 100 ms | 42/100 (42%) | 100/100 (100%) |
| 3 | 100 | 200 ms | 100 ms | 100/100 (100%) | 100/100 (100%) |
| 4 | 100 | 50 ms | 10 ms | 100/100 (100%) | 100/100 (100%) |

These four rows are **different individual configurations**, not four repetitions of the same experiment. They should not be combined into a pooled mean or treated as a statistical estimate of reliability. The underlying benchmark directories were referenced in user-reported terminal output but were not present in the GitHub `results/` directory during documentation review. The committed `results/measurements.csv` contains a header only, not a populated measurement dataset.

The first two configurations demonstrate a sampling limitation: a requested 100 ms delay allowed many short-lived 50 ms processes to disappear before the snapshot captured them. In configuration 3, longer process lifetime improved snapshot coverage. In configuration 4, shorter requested polling delay improved coverage for the short-lived workload. The event-driven collector matched all expected workload PIDs in these four observations. This does not prove lossless eBPF event delivery under arbitrary load.

### 3.3 Additional active-workload observation

The README also records a separate manual eBPF trial in which 89 of 100 workload PIDs matched the log, followed by a synchronized trial in which all 100 matched. The unmatched PIDs in the earlier run were clustered near the end of the workload, consistent with the monitoring window ending too soon. This is a plausible timing explanation, not proof of a specific cause. A total count of 210 logged execution lines in a separate run included unrelated activity and potentially multiple execution events per PID; it must not be interpreted as 210 distinct workload processes.

### 3.4 Recorded CPU time and memory observations

The README records separate approximately 15-second **idle-monitoring** measurements using GNU time:

| Monitoring command | Elapsed time | User CPU | System CPU | Combined CPU | Reported peak RSS |
|---|---:|---:|---:|---:|---:|
| Snapshot loop, 10 ms requested sleep | 14.78 s | 1.91 s | 5.01 s | 6.92 s | 3,584 KB |
| Snapshot loop, 100 ms requested sleep | 14.82 s | 0.32 s | 0.91 s | 1.23 s | 3,584 KB |
| Timed eBPF loader command | 15.03 s | 0.01 s | 0.03 s | 0.04 s | 35,424 KB |

For the polling loops, combined CPU time divided by elapsed time is approximately 46.8% of one CPU core for the 10 ms delay and 8.3% for the 100 ms delay. The timed eBPF command's corresponding figure is approximately 0.27%. The 10 ms loop completed 796 snapshots in 14.78 seconds, and the 100 ms loop completed 136 snapshots in 14.82 seconds. These counts imply average completed-cycle durations of approximately 18.6 ms and 109.0 ms, respectively, which are not equal to the requested sleep delays.

The measurements are **not matched active-workload comparisons**. Polling measurements include shell and subprocess overhead; the timed eBPF measurement includes a timeout wrapper and does not fully account for kernel-side BPF memory. The reported RSS values have different process-accounting boundaries and must not be compared as total memory footprints. The eBPF timeout exit status of 124 was consistent with the intentional time limit and does not independently establish successful startup. A separate one-shot snapshot measurement recorded 0.01 s elapsed and 1,664 KB maximum RSS; its user and system CPU values rounded to 0.00 s and should not be interpreted as zero resource use.

### 3.5 Interpretation and limitations

The observations support three limited conclusions. First, periodic snapshots can miss short-lived programs when their lifetime is short relative to the sampling cycle. Second, more frequent polling can recover those processes in this workload, at a greater observed CPU-time cost in the idle polling loops. Third, eBPF execution events matched all expected workload PIDs in the four recorded controlled configurations, although this does not establish universal delivery guarantees.

Limitations include single trials for the four listed configurations, a sequential sleep workload rather than diverse production activity, PID-only matching, unmeasured exact sampling cadence, different observation semantics, absent event-loss accounting, and unmatched resource measurement boundaries. A stronger overhead comparison would require repeated synchronized workloads, monitor-specific resource accounting, and kernel memory measurements. No such additional experiments are claimed in this report.

## 4. Conclusion

ProcessWatch demonstrates two complementary Linux monitoring mechanisms. The C snapshot tool exposes process metadata through the proc filesystem and applies simple informational security review indicators. The eBPF program observes process execution at a kernel tracepoint and delivers structured events to a user-space loader through a ring buffer. The recorded detection experiments show why short-lived processes are difficult to capture with slower snapshots, while the faster polling configuration illustrates that snapshot coverage can improve. Separate idle-monitoring measurements suggest that increasing snapshot frequency raises CPU-time consumption, but they do not justify a definitive matched performance ranking between eBPF and polling. Future extensions could include repeated matched trials, dropped-event accounting, and a unified interface; these are not presented as completed features.

## Contribution Table

| Contributor | Contribution |
|---|---|
| Individual project author | Project concept and scope; C proc snapshot and security indicators; eBPF/libbpf event monitor; controlled workload and benchmark methodology; experimental test execution and interpretation; documentation and final review. |

## AI Use Statement

ChatGPT was used as a supplementary tool during the development and documentation of this project. All experimental testing was conducted by me, and the results presented in this report reflect actual observations and recorded measurements. I reviewed the final work and take responsibility for its accuracy and content.
