

#import "textReader.h"
#import "MyTextView.h"



// KLUDGE to allow use of memory mapped NSData instead of FILE * handle

/*****************************************************************************
 *
 *	Define integral type Byte, Word, and DWord to match those on the
 *	Pilot being 8, 16, and 32 bits, respectively.
 *
 *****************************************************************************/

typedef unsigned char Byte;

typedef uint16_t Word;
typedef uint32_t DWord;


// ***********************************************
typedef unsigned int NSUInteger;

typedef  struct _pdbFILE {
	NSData     * data;
	NSUInteger   pos;
} pdbFILE;

int GET_DWord(pdbFILE * fin, DWord * n);

int pdbfseek(pdbFILE * fin, size_t offset, int start);

pdbFILE * pdbfopen(NSString * fullpath);

void pdbfclose(pdbFILE * fin);

int pdbfread( void *buf, size_t size, int cnt, pdbFILE * fin);


NSUInteger pdbftell(pdbFILE * fin);

struct pdbstat {
	NSUInteger st_size;
};

int pdbfstat(pdbFILE * fin, struct pdbstat * stat);

int pdbread( pdbFILE * fin, void *buf, size_t size );



// Forcibly correct unsignedness for crt calls
// size_t strlen(const unsigned char * str);
// int strncmp ( const char * str1, const char * str2, size_t num );

#define strlen(a) strlen((char*)a)
#define strncmp(a,b,c) strncmp((char*)a,(char*)b,c)

// ***********************************************

#define FILE pdbFILE
#define stat pdbstat

#define open(a,b)  pdbfopen(a)
#define close(a) pdbfclose(a)
#define lseek(a,b,c) pdbfseek(a,b,c)

#define fopen(a,b) pdbfopen(a)
#define fclose(a) pdbfclose(a)
#define ftell(a) pdbftell(a)
#define fread(a,b,c,d) pdbfread(a,b,c,d)
#define fseek(a,b,c) pdbfseek(a,b,c)
#define fileno(a)    (a)
#define fstat(a,b)   pdbfstat(a,b)

