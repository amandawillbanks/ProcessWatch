# ProcessWatch Architecture

## Scope

The project implements the original proposal using C on Linux: a `/proc` process snapshot, real-time eBPF exec-event observation, and informational security flags.

## Snapshot path (user space)

```text
/proc/<pid>/status ─┐
                    ├─> src/process.c ─> ProcessInfo ─> src/security.c
/proc/<pid>/exe ────┘                                  │
                                                       v
                                          build/processwatch snapshot
```

`src/process.c` enumerates numeric directories under `/proc`, reads process name, PID, PPID, state, UID, and optional RSS, and attempts to resolve the executable symlink. A process can exit during scanning, or the executable symlink may be inaccessible; these conditions are handled without declaring the process malicious.

`src/security.c` flags UID 0 as `ROOT` and executable paths beginning with `/tmp/` as `TMP_EXEC`. These are informational indicators, not evidence of compromise. The `/tmp/` boundary avoids incorrectly flagging `/tmpfile`.

## Real-time execution path (kernel to user space)

```text
Linux sched_process_exec tracepoint
              |
              v
ebpf/process_exec.bpf.c  [kernel eBPF program]
              |
              v
         BPF ring buffer
              |
              v
ebpf/loader.c            [user-space libbpf]
              |
              v
     EXEC PID/PPID/UID/COMM/TIME output
```

The eBPF program sends execution event metadata through a ring buffer. The user-space loader attaches to the tracepoint and polls the buffer using libbpf. The timestamp is a monotonic kernel timestamp in nanoseconds, not a wall-clock date.

## Command-line interface

Two executable entry points are currently used:

```bash
./build/processwatch snapshot
sudo ./build/processwatch-loader
```

Both are command-line programs. The event monitor is separate because it requires libbpf and privileges to attach the kernel tracepoint; the snapshot mode does not.

## Testing

- `make test`: C unit checks for `/proc` reading and security rules
- `tests/workload.sh`: controlled short-lived executable launches
- `scripts/benchmark.sh`: one paired observation trial with raw logs
- `scripts/run_trials.sh`: repeated trials with detection-rate CSV

## Limitations

- Snapshots can miss short-lived processes between scans.
- Process metadata may change while `/proc` is read.
- PID-only matching is imperfect if PIDs are reused.
- Ring-buffer delivery may drop events under pressure; the current program does not report dropped-event counts.
- Root privilege and `/tmp` location alone do not establish malicious activity.
- CPU and memory overhead are not measured by the current benchmark scripts.
