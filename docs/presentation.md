# ProcessWatch — Five-Minute Presentation Plan

**Presentation dates listed:** Nov 11, 16, 18, 2026 (in class); solo projects 5 minutes. EOL students are stated not to present; verify whether this applies to you.

## Slide 1 — Idea and motivation (0:00–0:45)
- ProcessWatch: Linux process visibility in C.
- Problem: `/proc` polling may miss short-lived processes.
- Research question: detection coverage versus overhead.

## Slide 2 — Technical approach (0:45–2:00)
- Diagram: `/proc` reader -> snapshot; eBPF exec tracepoint -> event reader.
- Fields: PID, PPID, state, name, UID, memory, executable path.
- Security review signals: root UID, executable path under `/tmp`.
- Explain that Xinu in QEMU is separate from Linux host.

## Slide 3 — Demo (2:00–3:00)
- Show actual built program on approved Linux environment.
- Demonstrate process listing and one controlled workload.
- If eBPF works, show live exec events; otherwise explain tested limitation.

## Slide 4 — Evaluation results (3:00–4:30)
- Show real detection counts by method and polling interval.
- Show measured CPU and memory overhead.
- Explain setup, baseline, repeat trials and limitations.
- **Do not invent results.** Replace placeholders after running experiments.

## Slide 5 — Conclusion (4:30–5:00)
- What was built, what numbers show, one limitation, next improvement.

## Questions to be able to answer
- What is `/proc` and why does it expose process data?
- What does eBPF run in the kernel, and what stays in user space?
- Why might polling miss short-lived processes?
- What does UID 0 mean? Why is it not automatically suspicious?
- How were detection counts, CPU and memory measured?
- Why is this Linux-specific rather than Xinu guest code?

## Presentation checklist
- [ ] Verify assigned date / EOL exemption
- [ ] Replace all results placeholders with measured data
- [ ] Rehearse to 5 minutes
- [ ] Prepare fallback screenshots if live demo fails
- [ ] Submit slides with final report
