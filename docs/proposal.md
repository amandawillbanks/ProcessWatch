# ProcessWatch — Project Proposal / Scope

## Motivation
Linux administrators need visibility into processes, their resource use and their executable origins. A periodic snapshot can show what is running now, but may miss short-lived programs. An event-driven approach may improve coverage at a different runtime cost.

## Problem / question
How does a lightweight C `/proc` polling monitor compare with an eBPF process-execution event monitor in detecting short-lived processes, and what overhead does each impose?

## Proposed implementation
1. **Snapshot mode:** Parse `/proc/<pid>/status` (Name, State, PPid, Uid, VmRSS when available), enumerate PID directories, optionally `readlink /proc/<pid>/exe`. Gracefully handle exited processes and permission failures.
2. **Security signals:** Annotate root-owned processes and executables with paths inside `/tmp`. These are heuristic flags, not a malware verdict.
3. **Event mode (conditional):** eBPF tracepoint for successful process exec events, user-space event reader, timestamps and counts. Verify Linux kernel, BTF, clang, libbpf, privileges and VCL policy first.
4. **Comparison:** Run a known number of process executions; collect detections, misses, monitor CPU and resident memory for polling intervals and eBPF, repeat trials.

## Minimum viable deliverable
A working C CLI process snapshot tool plus documented tests and results. If eBPF is blocked by VCL restrictions, clearly report the limitation, consult instructor, and evaluate polling interval trade-offs rather than claim eBPF results.

## Proposed evaluation metrics
- Executions detected / known executions; missed = known minus detected (define matching and deduplication).
- CPU usage of monitor (method and sampling window documented).
- Peak/average resident memory of monitor.
- Polling interval (e.g., 100 ms, 500 ms, 1000 ms), trial duration, repeat count.
- Qualitative false-positive considerations for security flags.

## Constraints / risks
- `/proc` is a changing snapshot: processes may disappear during reads.
- PID reuse and multiple execs per PID can confound counts.
- `/proc/<pid>/exe` can be inaccessible or deleted; `VmRSS` may be unavailable.
- eBPF may require kernel features, libraries and privileges not granted in VCL.
- Xinu/QEMU guest is not the Linux host where `/proc` and eBPF run.
- No measured results exist yet.

## Out of scope
Malware attribution, automatic process killing, network monitoring, graphical interface, full security hardening engine.

## Deliverables
Source and README; reproducible benchmark and CSV data; 5-minute presentation if applicable; 3+ page final report with required sections and AI-use disclosure.

## Instructor alignment
Earlier discussion indicated the ProcessWatch concept was accepted and eBPF/additional functionality suggested. Exact platform and feature requirements should still be checked against the course materials.
