
#include "security.h"
#include "process.h"
#include <stddef.h>
#include <string.h>

/*
 * Return 1 if the process is running as root.
 * Return 0 otherwise.
 */
int is_root_process(const ProcessInfo *process)
{
    if (process == NULL) {
        return 0;
    }

    return process->uid == 0;
}

int is_tmp_executable(const ProcessInfo *process)
{
    if (process == NULL || !process->exe_path_valid) {
        return 0;
    }

    return strncmp(process->exe_path, "/tmp/", 5) == 0;
}
