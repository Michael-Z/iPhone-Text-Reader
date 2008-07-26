NAME    := textReader
VERSION := 2.1

CC  := arm-apple-darwin9-gcc
CFLAGS = -I"/usr/include" -I "/var/include" -I"/var/root/Development/OS2.0/Frameworks" -DVERSION='"$(VERSION)"' -O3 -funroll-loops 
LD  := ${CC}
LDFLAGS = -framework Foundation \
		-framework CoreFoundation \
		-framework UIKit \
		-framework QuartzCore \
		-framework CoreGraphics \
		-framework GraphicsServices \
		-framework CoreSurface \
		-framework CoreAudio \
		-framework Celestial \
		-framework AudioToolbox \
		-lobjc \
		-lz \
		-L"/usr/lib" \
		-F"/System/Library/Frameworks" \
		-F"/System/Library/PrivateFrameworks" \
		-bind_at_load \
		-multiply_defined suppress 

all:	${NAME}


${NAME}:	UIOrientingApplication.o MyTextView.o FileTable.o UIDeletableCell.o main.o \
			PrefsTable.o DownloadTable.o ColorTable.o \
			peanut.o pdbfile.o unpluck.o txt2pdbdoc.o \
			rtfactn.o rtfreadr.o \
			chm_lib.o extract_chmLib.o lzx.o \
			${NAME}.o
	$(LD) $(LDFLAGS) -o $@ $^
	cp ${NAME} /Applications/${NAME}.app/.
	chmod a+x /Applications/${NAME}.app/${NAME}
	ldid -S /Applications/${NAME}.app/${NAME}
    
    
%.o:	%.m
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

clean:
	rm -f *.o ${NAME}

