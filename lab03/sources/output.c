/* output.c - вывод строки и выдача справки */
#include <stdio.h>
#include "prog.h"

char mark_begin[] = "=== begin ===";   /* инициализированные данные (.data) */

void print_arg(const char *arg)
{
    counter++;
    printf("%d: %s\n", counter, arg);
}

void print_help(const char *name)
{
    fprintf(stderr, "dzhargs %s - print command line arguments\n", PROG_VERSION);
    fprintf(stderr, "Usage: %s ARG...\n", name);
}
