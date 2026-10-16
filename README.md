# ProcessWatch
CSC501 Operating Systems — solo project (Fall 2026)

**Status: design and starter scaffolding; implementation and measurements are NOT complete.**

## Project idea
ProcessWatch is a proposed Linux command-line process monitoring and security-analysis tool written primarily in C. It combines a snapshot of running processes from Linux `/proc` with a proposed event-driven eBPF process-execution monitor, then evaluates detection coverage and overhead.

**Research question:** Compared with periodic `/proc` polling, can eBPF-based process-execution monitoring detect short-lived process executions more reliably with acceptable monitoring overhead?

## Scope
- **MVP:** Enumerate numeric `/proc/<pid>` directories; show PID, PPID, command name, state, resident memory, UID/root status; optionally resolve executable path.
- **Security heuristics:** Flag UID 0 and executable paths under `/tmp` as **review signals, not proof of compromise**.
- **eBPF extension:** Capture process execution events (e.g. `sched_process_exec`) using a kernel-side program and a user-space loader, if the VCL Linux kernel, permissions and libraries allow it.
- **Evaluation:** Compare polling and eBPF on a controlled workload, detection count, missed short-lived executions, CPU overhead and memory overhead. Report limitations and repeat trials.
- **Stretch:** CPU usage, event timestamps, filters, CSV export.

## Architecture
```text
Linux host (NOT Xinu guest)
  /proc/<pid>/status, stat, exe ----> C snapshot reader ---+
                                                            +--> terminal summary / flags
  kernel exec tracepoint --> eBPF program --> user loader --+
                               |
                     benchmark event counts
```

Xinu runs in QEMU for other CSC501 work; Linux `/proc` and Linux eBPF are **not** APIs inside the Xinu guest. Confirm with the instructor whether the project should run on the VCL Linux host.

## Repository
```text
src/        main.c, process.c, security.c
include/    process.h, security.h
ebpf/       process_exec.bpf.c, loader.c
tests/      test_process.c, workload.sh
scripts/    benchmark.sh
results/    measurements.csv
docs/       proposal.md, architecture.md, evaluation_plan.md,
            setup.md, milestones.md, presentation.md, final_report.md
Makefile    build targets (currently placeholders)
```

## Build and run
**Not yet implemented.** The Makefile currently prints a placeholder message. Actual dependencies, compile commands, privileges and run instructions will be documented after testing the VCL environment. Do not assume eBPF works until verified.

## Course deliverables
- **Presentation window:** Nov 11, 16, 18, 2026; 5 minutes for solo projects. Course notice says EOL students do not present; confirm your section and presentation assignment.
- **Final report:** Dec 1, 2026 at 11:59 PM, Gradescope. Solo: 3+ single-spaced pages, 10-point font, excluding contribution table and AI statement.
- **Code:** GitHub repository with reproducible build/run instructions.
- **Report sections:** abstract; motivation and idea; technical detail; evaluation (setup, baseline, measured numbers); contribution table; AI-use statement.

## AI-use and academic integrity
AI assistance is allowed for boilerplate, build/plot scripts and debugging, **not** as a substitute for understanding. All final submitted code and text must be understood and explainable line by line. Document actual tool use in the report.

See [proposal](docs/proposal.md), [architecture](docs/architecture.md), [evaluation plan](docs/evaluation_plan.md), and [milestones](docs/milestones.md).
