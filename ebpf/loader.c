
#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <bpf/libbpf.h>
#include <errno.h>
#include "process_event.h"

static volatile sig_atomic_t running = 1;

static void handle_signal(int sig)
{
    (void)sig;
    running = 0;
}
/*
 * Handle process execution events received
 * from the eBPF ring buffer.
 */
static int handle_event(void *ctx, void *data, size_t data_sz)
{
    (void)ctx;

    if (data_sz < sizeof(struct process_event)) {
        return 0;
    }

    const struct process_event *event = data;

    printf("EXEC PID=%u UID=%u COMM=%s TIME=%llu\n",
           event->pid,
           event->uid,
           event->comm,
           event->timestamp_ns);

    fflush(stdout);

    return 0;
}


int main(void)
{
    struct bpf_object *obj;
    struct bpf_program *prog;
    struct bpf_link *link;
    struct ring_buffer *rb;
    int map_fd;
    int err;

    obj = bpf_object__open_file(
        "build/process_exec.bpf.o", NULL);

    if (libbpf_get_error(obj)) {
        fprintf(stderr, "Failed to open BPF object\n");
        return 1;
    }

    if (bpf_object__load(obj)) {
        fprintf(stderr, "Failed to load BPF object\n");
        bpf_object__close(obj);
        return 1;
    }

    prog = bpf_object__find_program_by_name(
        obj, "trace_process_exec");

    if (!prog) {
        fprintf(stderr, "Program not found\n");
        bpf_object__close(obj);
        return 1;
    }

    link = bpf_program__attach_tracepoint(
        prog, "sched", "sched_process_exec");

    if (libbpf_get_error(link)) {
        fprintf(stderr, "Failed to attach tracepoint\n");
        bpf_object__close(obj);
        return 1;
    }

    
    /* Find the ring buffer map created by our eBPF program. */
    map_fd = bpf_object__find_map_fd_by_name(obj, "events");

    if (map_fd < 0) {
        fprintf(stderr, "Failed to find events map\n");
        bpf_link__destroy(link);
        bpf_object__close(obj);
        return 1;
    }

    /* Connect the ring buffer to our event handler. */
    rb = ring_buffer__new(map_fd, handle_event, NULL, NULL);

    if (!rb) {
        fprintf(stderr, "Failed to create ring buffer\n");
        bpf_link__destroy(link);
        bpf_object__close(obj);
        return 1;
    }

    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    printf("ProcessWatch monitoring started...\n");
    printf("Press Ctrl+C to stop.\n");

    
    while (running) {
        err = ring_buffer__poll(rb, 100);

        if (err == -EINTR) {
            break;
        }

        if (err < 0) {
            fprintf(stderr, "Ring buffer polling failed: %d\n", err);
            break;
        }
    }

    ring_buffer__free(rb);
    bpf_link__destroy(link);
    bpf_object__close(obj);

    printf("ProcessWatch stopped.\n");
    return 0;
}

