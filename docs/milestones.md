# Project Milestones and Definition of Done

Dates are planning targets, not additional instructor-imposed deadlines.

## Oct 16–20 — Environment and design
- [ ] Confirm Linux host versus Xinu guest
- [ ] Confirm persistent working directory and Git clone
- [ ] Check compiler, libbpf, kernel and VCL policy
- [ ] Review proposed architecture and evaluation plan

## Oct 21–25 — Snapshot MVP
- [ ] Implement process struct and safe `/proc` parser
- [ ] List PID, PPID, name, state, RSS and UID
- [ ] Handle disappearing processes and permissions
- [ ] Test build and basic output

## Oct 26–Nov 1 — Security flags and eBPF feasibility
- [ ] Resolve executable paths where permitted
- [ ] Add root UID and `/tmp` path flags with careful wording
- [ ] Test eBPF loading/attachment with instructor-approved permissions
- [ ] Implement event mode if feasible, otherwise document blocker and alternative

## Nov 2–7 — Experiments
- [ ] Build deterministic workload
- [ ] Establish no-monitor baseline
- [ ] Compare polling intervals and eBPF if available
- [ ] Repeat trials and record raw data

## Nov 8–10 — Presentation readiness
- [ ] Prepare idea / approach / measured results slides
- [ ] Rehearse a 5-minute explanation and demo
- [ ] Confirm EOL status and assigned presentation date

## Nov 11, 16, 18 — Presentation window
- [ ] Present if required (solo: 5 minutes)

## Nov 19–30 — Final report and reproducibility
- [ ] Complete technical description and measured evaluation
- [ ] Finalize README build/run instructions
- [ ] Ensure GitHub source matches reported results
- [ ] Add contribution table and accurate AI-use statement
- [ ] Submit slides with report

## Dec 1, 11:59 PM — Final report deadline
- [ ] Submit report to Gradescope
- [ ] Submit source via GitHub as instructed

## Definition of done
- A reproducibly buildable and runnable Linux C tool.
- A clear explanation of every submitted function and relevant OS concept.
- Honest evaluation with baseline, setup and actual numerical results.
- Complete README, source code, report, AI disclosure, and slides if required.
