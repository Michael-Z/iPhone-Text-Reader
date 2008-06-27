NAME	:= textReader
VERSION := 0.1

CC	:= arm-apple-darwin-gcc
CFLAGS	:= -Wall -pipe  -O3 -I/opt/local/include  -I/usr/local/arm-apple-darwin/include/Foundation
LD	:= ${CC}
LDFLAGS	:= -lz -lobjc -framework CoreFoundation -framework Foundation -framework UIKit -framework LayerKit \
		   -framework CoreGraphics -framework GraphicsServices \
		   -framework CoreAudio -framework AudioToolbox -framework Celestial 
		   
all:	${NAME}


${NAME}:	UIOrientingApplication.o MyTextView.o FileTable.o UIDeletableCell.o main.o \
            PrefsTable.o DownloadTable.o ColorTable.o \
            peanut.o pdbfile.o unpluck.o txt2pdbdoc.o \
            rtfactn.o rtfreadr.o \
            chm_lib.o extract_chmLib.o lzx.o \
            ${NAME}.o
	$(LD) $(LDFLAGS) -o $@ $^
	scp ${NAME} root@192.168.1.69:/Applications/${NAME}.app/.
#	scp English.lproj/Localizable.strings   root@192.168.1.69:/Applications/${NAME}.app/English.lproj/.
#	scp German.lproj/Localizable.strings    root@192.168.1.69:/Applications/${NAME}.app/German.lproj/.
#	scp Greek.lproj/Localizable.strings     root@192.168.1.69:/Applications/${NAME}.app/Greek.lproj/.
#	scp Russian.lproj/Localizable.strings   root@192.168.1.69:/Applications/${NAME}.app/Russian.lproj/.
#	scp zh_CN.lproj/Localizable.strings     root@192.168.1.69:/Applications/${NAME}.app/zh_CN.lproj/.
	
	
%.o:	%.m
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

clean:
	rm -f *.o ${NAME}

