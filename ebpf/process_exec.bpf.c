
#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include "process_event.h"

char LICENSE[] SEC("license") = "GPL";

/* Ring buffer for sending events to user space. */
struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 1 << 24);
} events SEC(".maps");

SEC("tracepoint/sched/sched_process_exec")
int trace_process_exec(void *ctx)
{
    (void)ctx;

    struct process_event *event;

    event = bpf_ringbuf_reserve(
        &events, sizeof(*event), 0);

    if (!event) {
        return 0;
    }

    __u64 pid_tgid = bpf_get_current_pid_tgid();

    event->pid = pid_tgid >> 32;
    event->ppid = 0;
    event->uid = (__u32)bpf_get_current_uid_gid();
    event->reserved = 0;
    event->timestamp_ns = bpf_ktime_get_ns();

    bpf_get_current_comm(
        &event->comm, sizeof(event->comm));

    bpf_ringbuf_submit(event, 0);

    return 0;
}
