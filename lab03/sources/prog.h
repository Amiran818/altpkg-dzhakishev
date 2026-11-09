/* prog.h - общие объявления проекта dzhargs (ЛР3, Джакишев А.М.) */
#ifndef PROG_H
#define PROG_H

#define PROG_VERSION "1.0"

extern int counter;              /* счётчик выведенных параметров (counter.c) */
extern char mark_begin[];        /* метка начала вывода (output.c) */

void print_arg(const char *arg); /* вывести параметр с порядковым номером */
void print_help(const char *name); /* справка в поток диагностики */

#endif
