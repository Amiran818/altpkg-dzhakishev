CC = gcc
CFLAGS = -O2 -Wall
LDLIBS = -lncurses
PROG = Show
OBJS = show.o

all: $(PROG)

$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(PROG) $(OBJS)

.PHONY: all clean
