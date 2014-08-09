#
# Massivley simplified Makefile for building mconf, everything else
# has been stripped.
#

SHELL := /bin/bash

check-lxdialog := lxdialog/check-lxdialog.sh

HOST_EXTRACFLAGS = $(shell $(SHELL) $(check-lxdialog) -ccflags)
HOST_EXTRALIBS = $(shell $(SHELL) $(check-lxdialog) -ldflags)

lxdialog := lxdialog/checklist.o lxdialog/util.o lxdialog/inputbox.o
lxdialog += lxdialog/textbox.o lxdialog/yesno.o lxdialog/menubox.o

all:	mconf

zconf.tab.o: zconf.lex.c zconf.hash.c

mconf:	mconf.o zconf.tab.o $(lxdialog)
		gcc $(HOST_EXTRALIBS) -o $@ $^

clean:
		rm -f *.o lxdialog/*.o
		rm -f mconf
		rm -f zconf.lex.c

.c.o:
		gcc $(HOST_EXTRACFLAGS) -c -o $@ $<

zconf.%:	zconf.%_shipped
		cat $< > $@

