#!/usr/bin/env python3
"""Print Table 1 for the CSC 501 final report from the committed raw trial CSV."""
import csv
from collections import defaultdict
from pathlib import Path

csv_path = Path(__file__).resolve().parents[1] / "results" / "detection_trials.csv"
groups = defaultdict(lambda: {"trials": 0, "count": 0, "snapshot": 0, "ebpf": 0})
with csv_path.open(newline="", encoding="utf-8") as handle:
    for row in csv.DictReader(handle):
        key = (float(row["requested_lifetime_s"]), float(row["requested_poll_interval_s"]))
        g = groups[key]
        g["trials"] += 1
        g["count"] += int(row["workload_count"])
        g["snapshot"] += int(row["snapshot_detected"])
        g["ebpf"] += int(row["ebpf_detected"])

print("| Requested lifetime | Requested polling delay | Trials | Snapshot detections | eBPF detections | Snapshot rate | eBPF rate |")
print("| --- | --- | ---: | ---: | ---: | ---: | ---: |")
for (lifetime, interval), g in sorted(groups.items(), key=lambda item: (item[0][0], -item[0][1])):
    n = g["count"]
    if not n:
        raise ValueError("No expected processes for a configuration")
    print(f"| {lifetime * 1000:g} ms | {interval * 1000:g} ms | {g['trials']} | "
          f"{g['snapshot']}/{n} | {g['ebpf']}/{n} | "
          f"{g['snapshot'] / n:.2%} | {g['ebpf'] / n:.2%} |")
