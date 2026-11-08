
#ifndef PROCESSWATCH_SECURITY_H
#define PROCESSWATCH_SECURITY_H

#include "process.h"

int is_root_process(const ProcessInfo *process);
int is_tmp_executable(const ProcessInfo *process);

#endif
