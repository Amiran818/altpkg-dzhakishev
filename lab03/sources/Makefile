# Makefile проекта dzhargs (ЛР3, Джакишев А.М.)
CC      = gcc
CFLAGS  = -O2 -Wall
LDFLAGS =
LDLIBS  =
PROG    = dzhargs
LIB     = dzhargs
OBJS    = main.o output.o counter.o
LIBOBJS = output.o counter.o
TARGETS = $(PROG) $(PROG)-static

all: $(TARGETS)

# 1) из объектных файлов
$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

# 2) со статической библиотекой: члены архива собираются встроенным правилом (%): %
lib$(LIB).a: lib$(LIB).a(output.o counter.o)

$(PROG)-static: main.o lib$(LIB).a
	$(CC) $(LDFLAGS) -o $@ main.o -L. -Wl,-Bstatic -l$(LIB) -Wl,-Bdynamic $(LDLIBS)

%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

$(OBJS): prog.h

# объектные файлы - члены архива не удалять как промежуточные
.SECONDARY: $(LIBOBJS)

clean:
	rm -f *.o

distclean: clean
	rm -f lib$(LIB).a $(TARGETS)

.PHONY: all clean distclean
