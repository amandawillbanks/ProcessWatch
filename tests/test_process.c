#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "process.h"
#include "security.h"

int main(void)
{
    ProcessInfo p = {0};
    assert(is_root_process(NULL) == 0);
    assert(is_tmp_executable(NULL) == 0);
    assert(is_root_process(&p) == 1);
    p.uid = 1000;
    assert(is_root_process(&p) == 0);

    p.exe_path_valid = 1;
    strcpy(p.exe_path, "/tmp/test-app");
    assert(is_tmp_executable(&p) == 1);
    strcpy(p.exe_path, "/tmpfile/test-app");
    assert(is_tmp_executable(&p) == 0);
    strcpy(p.exe_path, "/usr/bin/sleep");
    assert(is_tmp_executable(&p) == 0);
    p.exe_path_valid = 0;
    strcpy(p.exe_path, "/tmp/test-app");
    assert(is_tmp_executable(&p) == 0);

    ProcessInfo self = {0};
    assert(read_process(getpid(), &self) == 0);
    assert(self.pid == getpid());
    assert(self.name[0] != '\0');
    assert(self.state != '?');
    assert(read_process(-1, &self) == -1);
    assert(read_process(getpid(), NULL) == -1);

    puts("PASS: security flags and /proc process reader");
    return 0;
}
