# ProcessWatch — Linux Setup and Verification

ProcessWatch runs on a Linux host, not inside the Xinu QEMU guest. Loading eBPF requires permission on the host; confirm your VCL environment allows it.

## Prerequisites

- Linux with mounted `/proc` and kernel BTF at `/sys/kernel/btf/vmlinux`
- GCC, make, clang with BPF target support, bpftool, pkg-config
- libbpf development headers and libraries, plus libelf and zlib dependencies
- Appropriate privileges to load and attach the eBPF tracepoint

Check availability:

```bash
uname -r
command -v gcc make clang bpftool
pkg-config --modversion libbpf
ls -l /sys/kernel/btf/vmlinux
```

## Build and unit tests

```bash
git pull --ff-only origin main
make clean
make
make test
./build/processwatch snapshot
```

`make` builds the `/proc` snapshot executable. `make test` runs C tests for process metadata and security checks and checks shell script syntax.

## eBPF build and event monitoring

```bash
make ebpf
sudo ./build/processwatch-loader
```

In another terminal, run `/bin/sleep 1` to generate an exec event. Stop the loader with Ctrl+C. The loader reads `build/process_exec.bpf.o` relative to the repository root, so start it there.

The build generates `ebpf/vmlinux.h` from your host's kernel BTF. If the build or load fails, record the error and do not bypass host restrictions.

## Controlled experiment

After building both modes, from the repository root:

```bash
bash scripts/benchmark.sh 20 0.05 0.1
bash scripts/run_trials.sh 3 100 0.05 0.1
```

The benchmark records expected workload PIDs, snapshot-observed PIDs and eBPF exec-event PIDs. Each run creates a directory under `results/` with raw data and a summary. The trial runner appends detection counts and rates to `results/detection_trials.csv`.

**Interpretation:** A snapshot observes processes that exist when polled; eBPF reports exec events. These are different observation mechanisms. Detection percentages describe this controlled workload, not general system accuracy. PID matching can be ambiguous if IDs are reused. The scripts do **not** measure CPU or memory overhead.

## Verification checklist

- [ ] `make` completes without errors
- [ ] `make test` passes
- [ ] Snapshot shows PID, PPID, UID, state, root flag and executable path (or unavailable)
- [ ] `make ebpf` builds object and loader
- [ ] Loader reports a controlled `/bin/sleep` execution
- [ ] Root and `/tmp` flags are informational, not malware verdicts
- [ ] Controlled benchmark results saved with trial parameters
- [ ] Actual results and environment recorded in final report

Do not claim a step passed until it has been run on the target Linux system.
