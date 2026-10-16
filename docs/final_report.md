# ProcessWatch — Final Report Working Outline

**Due:** December 1, 2026, 11:59 PM on Gradescope. Solo report: at least 3 pages, 10 pt, single-spaced; contribution table and AI statement do not count toward the minimum. **This is an outline, not a finished report.**

## Abstract
[After experiments: briefly state the problem, what was actually implemented, measured comparisons, key numerical finding, and conclusion.]

## 1. Motivation and Idea
- Why Linux process visibility matters.
- Current methods: `/proc` snapshots, event-based monitoring.
- Limitations of polling for short-lived executions.
- Proposed ProcessWatch contribution and explicit research question.

## 2. Technical Details
### 2.1 Environment
[Linux distribution, kernel version, host/VCL configuration, compiler, libraries, permissions.]
### 2.2 Snapshot collector
[Numeric PID discovery, `/proc/<pid>/status` fields, `/proc/<pid>/exe`, failure handling.]
### 2.3 eBPF event collector
[Only if implemented: attach point, event struct, ring/perf buffer, user-space loader, lost events.]
### 2.4 Security heuristics
[Root UID and `/tmp` executable flags; limitations and false positives.]
### 2.5 Build and run
[Actual commands, dependencies and privilege requirements from README.]

## 3. Evaluation Results
### 3.1 Experimental setup
[Machine specs, kernel, process workload, durations, repeats, monitoring configuration.]
### 3.2 Baseline
[Unmonitored workload and/or polling reference mode, clearly defined.]
### 3.3 Detection coverage
[Measured expected, detected, missed, duplicate events, polling interval.]
### 3.4 Resource overhead
[Measured CPU and RSS; method and sampling windows.]
### 3.5 Interpretation and limitations
[What the numbers support, variability, permission and timing limitations.]

**Results table template — fill with real measurements only:**

| Mode | Interval (ms) | Executions | Detected | Missed | CPU % | RSS KB |
|---|---:|---:|---:|---:|---:|---:|
| Polling | TBD | TBD | TBD | TBD | TBD | TBD |
| eBPF (if supported) | N/A | TBD | TBD | TBD | TBD | TBD |

## 4. Conclusion
[Answer research question based only on actual results. State what remains unimplemented.]

## Contribution Table
| Member | Contribution |
|---|---|
| Solo project author | [Describe work actually completed] |

## AI Use Statement — must be last
[Record actual tools and uses (e.g., ChatGPT for outlining, scaffolding, debugging or scripts); confirm all code and report text were reviewed and understood. Update before submission.]
