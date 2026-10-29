
#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <bpf/libbpf.h>

static volatile sig_atomic_t running = 1;

static void handle_signal(int sig)
{
    (void)sig;
    running = 0;
}

int main(void)
{
    struct bpf_object *obj;
    struct bpf_program *prog;
    struct bpf_link *link;

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

    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    printf("ProcessWatch monitoring started...\n");
    printf("Press Ctrl+C to stop.\n");

    while (running) {
        sleep(1);
    }

    bpf_link__destroy(link);
    bpf_object__close(obj);

    printf("ProcessWatch stopped.\n");
    return 0;
}

