NAME	:= textReader
VERSION := 0.1

CC	:= arm-apple-darwin-gcc
CFLAGS	:= -Wall -pipe  -O3 -I/usr/local/arm-apple-darwin/include/Foundation
LD	:= ${CC}
LDFLAGS	:= -lobjc -framework CoreFoundation -framework Foundation -framework UIKit -framework LayerKit \
		   -framework CoreGraphics -framework GraphicsServices 

all:	${NAME}

${NAME}:	UIOrientingApplication.o MyTextView.o FileTable.o UIDeletableCell.o main.o ${NAME}.o
	$(LD) $(LDFLAGS) -o $@ $^

%.o:	%.m
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

clean:
	rm -f *.o ${NAME}

