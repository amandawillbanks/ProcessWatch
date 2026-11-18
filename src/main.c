#include <stdio.h>
#include <string.h>
#include "process.h"

int run_ebpf_monitor(void);

static void usage(const char *program)
{
    fprintf(stderr, "ProcessWatch - Linux Process Monitor\n");
    fprintf(stderr, "Usage: %s <snapshot|monitor>\n", program);
    fprintf(stderr, "  snapshot  Show processes from /proc\n");
    fprintf(stderr, "  monitor   Stream process exec events via eBPF (requires root and make ebpf)\n");
}

int main(int argc, char *argv[])
{
    if (argc != 2) {
        usage(argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "snapshot") == 0) {
        printf("\nProcessWatch - Process Snapshot\n\n");
        list_processes();
        return 0;
    }

    if (strcmp(argv[1], "monitor") == 0)
        return run_ebpf_monitor();

    usage(argv[0]);
    return 1;
}
