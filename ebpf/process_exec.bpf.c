#include "vmlinux.h"
#include <bpf/bpf_helpers.h>

char LICENSE[] SEC("license") = "GPL";

SEC("tracepoint/sched/sched_process_exec")
int trace_process_exec(void *ctx)
{
    __u32 pid = bpf_get_current_pid_tgid() >> 32;

    bpf_printk("ProcessWatch: process executed, PID=%u", pid);

    return 0;
}
