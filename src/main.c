
#include <stdio.h>
#include <string.h>

#include "process.h"

int main(int argc, char *argv[])
{
    if (argc != 2 ||
        strcmp(argv[1], "snapshot") != 0) {

        printf("ProcessWatch - Linux Process Monitor\n");
        printf("Usage: %s snapshot\n", argv[0]);
        return 1;
    }

    printf("\nProcessWatch - Process Snapshot\n\n");

    list_processes();

    return 0;
}
