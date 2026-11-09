/* main.c - головной модуль: точка входа */
#include <stdio.h>
#include "prog.h"

int main(int argc, char *argv[])
{
    int i;

    if (argc < 2) {
        print_help(argv[0]);
        return 1;
    }
    puts(mark_begin);
    for (i = 1; i < argc; i++)
        print_arg(argv[i]);
    printf("=== end: %d ===\n", counter);
    return 0;
}
