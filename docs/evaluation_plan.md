# Evaluation Plan — Measurements Before Claims

## Research question
Can eBPF exec-event monitoring capture more short-lived process executions than periodic `/proc` polling, at acceptable CPU and memory overhead?

## Baselines
1. **No monitor**: controlled workload runtime and system load.
2. **Polling monitor**: `/proc` snapshots at fixed intervals (suggested: 100, 500, 1000 ms).
3. **eBPF monitor**: successful exec events, **only if environment supports it**.

## Controlled workload
Launch a known number of short-lived child programs from a script/test binary. Record start/end timestamps and expected successful executions independently of ProcessWatch. Include a longer-running workload as a sanity check. Avoid treating shell built-ins as exec events; verify which commands actually call exec.

## Trial procedure
1. Record OS/kernel, machine type, CPU count, tool versions and privileges.
2. Run baseline without monitoring.
3. Run each polling interval under the same workload and conditions.
4. Run eBPF mode if supported.
5. Repeat each configuration at least 3 times; record trial IDs and raw data.
6. Calculate summary statistics and make a simple comparison chart.

## Metrics and definitions
- **Known executions:** number of successful executable launches by the workload (not merely fork calls).
- **Detected:** unique workload executions matched by PID plus time/start identity where possible.
- **Missed:** known executions minus unique detected executions; do not allow negative misses.
- **Detection rate:** detected / known executions × 100%.
- **CPU overhead:** monitor process CPU consumption over a documented time window; separate system-wide from per-process measures.
- **Memory overhead:** peak RSS of monitor process in kB; include loader for eBPF.
- **Dropped events:** report if available from event transport.

## Experimental controls
Keep workload count, machine, other activity, and measurement duration comparable. Polling observes process *existence*, while eBPF observes *exec events*; define how the comparison is normalized and explain that not every fork performs an exec.

## CSV data plan
`results/measurements.csv` is a placeholder; before testing add trial ID, mode, interval, workload count, detections, misses, CPU, RSS, duration and notes. Never enter illustrative values as real results.

## Interpretation
Look for trade-offs rather than asserting eBPF always wins. If eBPF cannot run in VCL, record exactly why and consult the instructor; complete a meaningful polling interval experiment and disclose the change.

## Suggested charts
- Detection rate by monitoring mode / polling interval.
- CPU overhead by mode.
- Peak RSS by mode.

## Reporting
Describe setup, baseline, measured numbers, variation, limitations and reproducibility. Keep raw logs or command transcripts where practical.
