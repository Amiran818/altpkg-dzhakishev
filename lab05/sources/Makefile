# Makefile ЛР5: сборка с отладочными ключами и проверка сценариями gdb
CC      = gcc
CFLAGS  = -O0 -g -Wall -Wextra
GDB     = gdb --batch --quiet --nx
GDBDIR  = ../gdb
CHKDIR  = ../check
PROG    = progression
OUTS    = trace.out range.out

all: $(PROG)

$(PROG): main.c seq.c seq.h
	$(CC) $(CFLAGS) -o $@ main.c seq.c

# сценарий отладчика -> строки с признаком LAB5 -> сравнение с эталоном
%.out: $(GDBDIR)/%.gdb $(PROG)
	$(GDB) -x $< ./$(PROG) < /dev/null 2>&1 | grep '^LAB5 ' > $@

check: $(OUTS)
	diff trace.out $(CHKDIR)/expected-trace.txt
	diff range.out $(CHKDIR)/expected-range.txt
	@echo "check: вывод сценариев gdb совпадает с эталоном"

clean:
	rm -f $(PROG) $(OUTS)

.PHONY: all check clean
