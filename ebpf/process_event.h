
#ifndef PROCESS_EVENT_H
#define PROCESS_EVENT_H

#define PROCESS_COMM_LEN 16

struct process_event {
    unsigned int pid;
    unsigned int ppid;
    unsigned int uid;
    unsigned int reserved;
    unsigned long long timestamp_ns;
    char comm[PROCESS_COMM_LEN];
};

#endif
