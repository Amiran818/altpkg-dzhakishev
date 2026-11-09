# Makefile проекта dzhargs (ЛР3, Джакишев А.М.)
CC      = gcc
CFLAGS  = -O2 -Wall
LDFLAGS =
LDLIBS  =
PROG    = dzhargs
LIB     = dzhargs
SONAME  = lib$(LIB).so.1
OBJS    = main.o output.o counter.o
LIBOBJS = output.o counter.o
PICOBJS = $(LIBOBJS:%.o=pic/%.o)
TARGETS = $(PROG) $(PROG)-static $(PROG)-shared

all: $(TARGETS)

# 1) из объектных файлов
$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

# 2) со статической библиотекой: члены архива собираются встроенным правилом (%): %
lib$(LIB).a: lib$(LIB).a(output.o counter.o)

$(PROG)-static: main.o lib$(LIB).a
	$(CC) $(LDFLAGS) -o $@ main.o -L. -Wl,-Bstatic -l$(LIB) -Wl,-Bdynamic $(LDLIBS)

# 3) с динамической библиотекой из позиционно-независимого кода
pic/%.o: %.c prog.h
	@mkdir -p pic
	$(CC) $(CFLAGS) -fPIC -c -o $@ $<

lib$(LIB).so: $(PICOBJS)
	$(CC) $(LDFLAGS) -shared -Wl,-soname,$(SONAME) -o $(SONAME) $^ $(LDLIBS)
	ln -sf $(SONAME) $@

$(PROG)-shared: main.o lib$(LIB).so
	$(CC) $(LDFLAGS) -o $@ main.o -L. -l$(LIB) $(LDLIBS)

%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

$(OBJS): prog.h

# объектные файлы - члены архива не удалять как промежуточные
.SECONDARY: $(LIBOBJS)

run-shared: $(PROG)-shared
	LD_LIBRARY_PATH=. ./$(PROG)-shared $(ARGS)

clean:
	rm -f *.o $(PICOBJS)

distclean: clean
	rm -rf pic lib$(LIB).a lib$(LIB).so $(SONAME) $(TARGETS)

.PHONY: all clean distclean run-shared
