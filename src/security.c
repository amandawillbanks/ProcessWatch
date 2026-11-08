
#include "security.h"
#include "process.h"
#include <stddef.h>

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
