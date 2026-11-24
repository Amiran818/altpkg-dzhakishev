/* seq.c - построение и вывод прогрессии */
#include <stdio.h>
#include "seq.h"

void emit(long idx, long value)
{
    printf("%ld\n", value);
    (void)idx;
}

long run(long from, long to, long step)
{
    long value, idx = 0;

    for (value = from; step > 0 ? value <= to : value >= to; value += step) {
        idx++;
        emit(idx, value);
    }
    return idx;
}
