
#ifndef PROCESSWATCH_PROCESS_H
#define PROCESSWATCH_PROCESS_H

#include <sys/types.h>

#define PROCESS_NAME_SIZE 256
#define PROCESS_PATH_SIZE 4096


typedef struct {
    pid_t pid;
    pid_t ppid;
    uid_t uid;
    char name[PROCESS_NAME_SIZE];
    char state;
    unsigned long rss_kb;

    char exe_path[PROCESS_PATH_SIZE];
    int exe_path_valid;
} ProcessInfo;


/* Read information about a single process. */
int read_process(pid_t pid, ProcessInfo *info);

/* Display all accessible running processes. */
void list_processes(void);

#endif
