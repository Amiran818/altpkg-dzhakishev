/* main.c - генератор арифметической прогрессии (ЛР5, Джакишев А.М.)
 *   progression N        0, 1, ..., N
 *   progression A B      A, A+1, ..., B
 *   progression A B S    A, A+S, ..., B
 */
#include <stdio.h>
#include <stdlib.h>
#include "seq.h"

static void usage(const char *name)
{
    fprintf(stderr, "Usage: %s TO | FROM TO | FROM TO STEP\n", name);
}

static long parse(const char *s, int *ok)
{
    char *end;
    long v = strtol(s, &end, 10);

    if (*s == '\0' || *end != '\0')
        *ok = 0;
    return v;
}

int main(int argc, char *argv[])
{
    long from = 0, to, step = 1;
    int ok = 1;

    if (argc < 2 || argc > 4) {
        usage(argv[0]);
        return 1;
    }
    if (argc == 2) {
        to = parse(argv[1], &ok);
    } else {
        from = parse(argv[1], &ok);
        to = parse(argv[2], &ok);
        if (argc == 4)
            step = parse(argv[3], &ok);
    }
    if (!ok || step == 0) {
        fprintf(stderr, "%s: invalid argument\n", argv[0]);
        return 2;
    }
    run(from, to, step);
    return 0;
}
