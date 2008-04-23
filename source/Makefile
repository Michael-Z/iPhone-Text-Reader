NAME	:= textReader
VERSION := 0.1

CC	:= arm-apple-darwin-gcc
CFLAGS	:= -Wall -pipe  -O3 -I/opt/local/include  -I/usr/local/arm-apple-darwin/include/Foundation
LD	:= ${CC}
LDFLAGS	:= -lobjc -framework CoreFoundation -framework Foundation -framework UIKit -framework LayerKit \
		   -framework CoreGraphics -framework GraphicsServices 
		   
all:	${NAME}

${NAME}:	UIOrientingApplication.o MyTextView.o FileTable.o UIDeletableCell.o main.o txt2pdbdoc.o ${NAME}.o
	$(LD) $(LDFLAGS) -o $@ $^
	scp ${NAME} root@192.168.1.69:/Applications/${NAME}.app/.
	
%.o:	%.m
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

clean:
	rm -f *.o ${NAME}

