# Architecture and Module Responsibilities

## Execution environment
Target: Linux host in NC State VCL, **subject to confirmation**. Xinu running in QEMU is a separate guest OS; do not run Linux `/proc` or eBPF code in the Xinu guest.

## Data flow
```text
                       +------------------+
 /proc/<pid>/status --->| src/process.c    |---> process record
 /proc/<pid>/exe    --->| snapshot parser  |       |
                       +------------------+       v
                                             src/security.c
                                              root? /tmp?
                                                   |
                                                   v
                                               src/main.c
                                              CLI / summary
 Linux sched_process_exec --> ebpf/process_exec.bpf.c
                                      |
                                  event buffer
                                      |
                                ebpf/loader.c
                                      |
                                  event counts
                                      |
                          scripts/benchmark.sh --> results/
```

## Proposed C record (design only)
- pid (process ID), ppid (parent ID)
- name, state
- uid and `is_root = (uid == 0)`
- resident memory in kB (VmRSS, if present)
- executable path (if readable)
- flag for executable under `/tmp/` (path boundary matters)
- validity indicators for missing fields

## Module responsibilities
- `src/main.c`: parse CLI options, select snapshot mode, print table and flags; eventual integration with event mode.
- `src/process.c`: enumerate numeric PID dirs, parse status safely, read executable symlink, handle ESRCH/EACCES.
- `include/process.h`: process struct and snapshot interface.
- `src/security.c`: review-only heuristics; do not label a process malicious solely due to UID or path.
- `include/security.h`: flags and evaluation interface.
- `ebpf/process_exec.bpf.c`: optional kernel-side exec tracepoint hook, minimal event payload.
- `ebpf/loader.c`: optional user-space libbpf setup, attach, poll event buffer and clean up.
- `tests/`: parsing tests, synthetic execution workload.
- `scripts/benchmark.sh`: repeat trials and record machine-readable metrics.

## Planned CLI (not implemented)
```text
./processwatch snapshot
./processwatch snapshot --show-flags
./processwatch events
```
Actual commands may change during implementation.

## Edge cases to design for
- Processes exit between enumeration and reading.
- PID reuse; PID alone is not a stable event identifier.
- Spaces and parentheses in process names; prefer `status` parsing for fields.
- Unreadable `exe` links; deleted binaries; kernel threads.
- `VmRSS` may be absent, approximate, or change during scan.
- Permissions, eBPF verifier constraints, kernel-version differences.
- Lost events in buffers under high workload.

## Security boundaries
Read-only observation; no process termination or privilege escalation. Only test controlled workloads with permission on VCL.
