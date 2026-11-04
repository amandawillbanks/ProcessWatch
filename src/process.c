
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <ctype.h>
#include <errno.h>
#include <limits.h>

#include "process.h"

/* Check whether a directory name contains only digits. */
static int is_pid_directory(const char *name)
{
    if (!name || !*name)
        return 0;

    for (const char *p = name; *p; p++) {
        if (!isdigit((unsigned char)*p))
            return 0;
    }

    return 1;
}

/* Read process metadata from /proc/<pid>/status. */
int read_process(pid_t pid, ProcessInfo *info)
{
    if (!info || pid <= 0)
        return -1;

    char path[64];
    char line[512];

    snprintf(path, sizeof(path),
             "/proc/%ld/status", (long)pid);

    FILE *file = fopen(path, "r");
    if (!file)
        return -1;

    memset(info, 0, sizeof(*info));
    info->pid = pid;
    info->state = '?';

    int got_name = 0;
    int got_ppid = 0;
    int got_uid = 0;
    int got_state = 0;

    while (fgets(line, sizeof(line), file)) {

        if (strncmp(line, "Name:", 5) == 0) {
            if (sscanf(line + 5, " %255[^\n]",
                       info->name) == 1)
                got_name = 1;
        }

        else if (strncmp(line, "State:", 6) == 0) {
            if (sscanf(line + 6, " %c",
                       &info->state) == 1)
                got_state = 1;
        }

        else if (strncmp(line, "PPid:", 5) == 0) {
            long value;
            if (sscanf(line + 5, " %ld", &value) == 1
                && value >= 0 && value <= INT_MAX) {
                info->ppid = (pid_t)value;
                got_ppid = 1;
            }
        }

        else if (strncmp(line, "Uid:", 4) == 0) {
            unsigned int value;
            if (sscanf(line + 4, " %u", &value) == 1) {
                info->uid = (uid_t)value;
                got_uid = 1;
            }
        }

        else if (strncmp(line, "VmRSS:", 6) == 0) {
            unsigned long value;
            if (sscanf(line + 6, " %lu", &value) == 1)
                info->rss_kb = value;
        }
    }

    fclose(file);

    if (!got_name || !got_ppid || !got_uid || !got_state)
        return -1;

    return 0;
}

/* Enumerate the running processes. */
void list_processes(void)
{
    DIR *directory = opendir("/proc");

    if (!directory) {
        perror("Unable to open /proc");
        return;
    }

    printf("%-8s %-8s %-8s %-6s %-12s %s\n",
           "PID", "PPID", "UID",
           "STATE", "RSS(KB)", "NAME");

    printf("------------------------------------------------"
           "----------------\n");

    struct dirent *entry;

    while ((entry = readdir(directory)) != NULL) {

        if (!is_pid_directory(entry->d_name))
            continue;

        errno = 0;
        char *end;
        long number = strtol(entry->d_name, &end, 10);

        if (errno != 0 || *end != '\0' ||
            number <= 0 || number > INT_MAX)
            continue;

        ProcessInfo info;

        if (read_process((pid_t)number, &info) == 0) {
            printf("%-8ld %-8ld %-8lu %-6c %-12lu %s\n",
                   (long)info.pid,
                   (long)info.ppid,
                   (unsigned long)info.uid,
                   info.state,
                   info.rss_kb,
                   info.name);
        }
    }

    closedir(directory);
}
