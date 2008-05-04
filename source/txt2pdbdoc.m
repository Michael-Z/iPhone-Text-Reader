/*
**	Text to Doc converter for Palm Pilots
**	txt2pdbdoc.c
**
**	Copyright (C) 1998  Paul J. Lucas
**
**	This program is free software; you can redistribute it and/or modify
**	it under the terms of the GNU General Public License as published by
**	the Free Software Foundation; either version 2 of the License, or
**	(at your option) any later version.
**
**	This program is distributed in the hope that it will be useful,
**	but WITHOUT ANY WARRANTY; without even the implied warranty of
**	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**	GNU General Public License for more details.
**
**	You should have received a copy of the GNU General Public License
**	along with this program; if not, write to the Free Software
**	Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/


#import "textReader.h"
#import "MyTextView.h"


// ----------------------------------------------------------
// Begin palm.h defines
// ----------------------------------------------------------
/* standard */
#include <time.h>

/*****************************************************************************
 *
 *	Define integral type Byte, Word, and DWord to match those on the
 *	Pilot being 8, 16, and 32 bits, respectively.
 *
 *****************************************************************************/

typedef unsigned char Byte;

typedef uint16_t Word;
typedef uint32_t DWord;


/********** Other stuff ******************************************************/

#define	dmDBNameLength	32		/* 31 chars + 1 null terminator */
#define RECORD_SIZE_MAX	4096		/* Pilots have a max 4K record size */

#ifdef	HAVE_TIME_H
#define	palm_date()	(DWord)(time(0) + 2082844800ul)
#else
#define	palm_date()	0
#endif

/*****************************************************************************
 *
 * SYNOPSIS
 */
	struct RecordEntryType
/*
 * DESCRIPTION
 *
 *	Every record has one of these headers.
 *
 * SEE ALSO
 *
 *	Christopher Bey and Kathleen Dupre.  "Palm File Format Specification,"
 *	Document Number 3008-003, Palm, Inc., May 16, 2000.
 *
 *****************************************************************************/
{
	DWord	localChunkID;		/* offset to where record starts */
	struct {
		unsigned delete   : 1;
		unsigned dirty    : 1;
		unsigned busy     : 1;
		unsigned secret   : 1;
		unsigned category : 4;
	} attributes;
	Byte	uniqueID[3];
};
typedef struct RecordEntryType RecordEntryType;

/*
** Some compilers pad structures out to DWord boundaries so using sizeof()
** doesn't give the right result.
*/
#define	RecordEntrySize		8

/*****************************************************************************
 *
 * SYNOPSIS
 */
	struct RecordListType		/* 6 bytes total */
/*
 * DESCRIPTION
 *
 *	This is a PDB database header as currently defined by Palm, Inc.
 *
 * SEE ALSO
 *
 *	Ibid.
 *
 *****************************************************************************/
{
	DWord	nextRecordListID;
	Word	numRecords;
};
typedef struct RecordListType RecordListType;

#define	RecordListSize		6

/*****************************************************************************
 *
 * SYNOPSIS
 */
	struct DatabaseHdrType		/* 78 bytes total */
/*
 * DESCRIPTION
 *
 *	This is a PDB database header as currently defined by Palm, Inc.
 *
 *****************************************************************************/
{
	char		name[ dmDBNameLength ];
	Word		attributes;
	Word		version;
	DWord		creationDate;
	DWord		modificationDate;
	DWord		lastBackupDate;
	DWord		modificationNumber;
	DWord		appInfoID;
	DWord		sortInfoID;
	char		type[4];
	char		creator[4];
	DWord		uniqueIDSeed;
	RecordListType	recordList;
};
typedef struct DatabaseHdrType DatabaseHdrType;

#define DatabaseHdrSize		78
// ----------------------------------------------------------
// End
// ----------------------------------------------------------







/* types */
#ifdef	bool
#undef	bool
#endif
#define	bool		int

#ifdef	false
#undef	false
#endif
#define	false		0

#ifdef	true
#undef	true
#endif
#define	true		1

/* constants */
#define	BUFFER_SIZE	6000		/* big enough for uncompressed record */
#define	COMPRESSED	2
#define	COUNT_BITS	3		/* why this value?  I don't know */
#define	DISP_BITS	11		/* ditto */
#define	DOC_CREATOR	"REAd"
#define	DOC_TYPE	"TEXt"
#define	UNCOMPRESSED	1

/* exit status codes */
enum {
	Exit_Success			= 0,
	Exit_Usage			= 1,
	Exit_No_Open_Source		= 2,
	Exit_No_Open_Dest		= 3,
	Exit_No_Read			= 4,
	Exit_No_Write			= 5,
	Exit_Not_Doc_File		= 6,
	Exit_Unknown_Compression	= 7
};

/* macros */
#define	NEW_BUFFER(b)	(b)->data = malloc( (b)->len = BUFFER_SIZE )

#define	FREE_BUFFER(b)	((b)->data ? free( (b)->data ) : 0)

//#define	GET_DWord(f,n) 	{ if ( fread( &n, 4, 1, f ) != 1 ) read_error(); n = ntohl(n); }
int GET_DWord(	FILE * fin, DWord * n) 	
{ 
	if ( fread( n, 4, 1, fin ) != 1 ) 
		return 1;
	
	*n = ntohl(*n); 
	return 0;
}


#define	SEEK_REC_ENTRY(f,i) \
	fseek( f, DatabaseHdrSize + RecordEntrySize * (i), SEEK_SET )

/*****************************************************************************
 *
 * SYNOPSIS
 */
	struct doc_record0		/* 16 bytes total */
/*
 * DESCRIPTION
 *
 *	Record 0 of a Doc file contains information about the document as a
 *	whole.
 *
 *****************************************************************************/
{
	Word	version;		/* 1 = plain text, 2 = compressed */
	Word	reserved1;
	DWord	doc_size;		/* in bytes, when uncompressed */
	Word	num_records; 		/* PDB header numRecords - 1 */
	Word	rec_size;		/* usually RECORD_SIZE_MAX */
	DWord	reserved2;
};
typedef struct doc_record0 doc_record0;

/*****************************************************************************
 *
 *	Globals
 *
 *****************************************************************************/

typedef struct {
	Byte	*data;
	unsigned len;
} buffer;


void		uncompress( buffer* );



// 0 == success
// 1 == error 
// 2 == invalid format
int decodeToString(NSString * src, NSMutableData ** dest, NSString ** type)
{
	buffer			buf = {0};
	int		    	compression;
	DWord			file_size, offset, rec_size;
	FILE			*fin = NULL;
	DatabaseHdrType	header;
	int				num_records, rec_num;
	doc_record0		rec0;
	
	int             rc = 2; // Assume invalid format ...

	*type = @"Unable to open file!";

	/********** open files, read header, ensure source is a Doc file *****/

	fin = fopen([src cString], "rb");
	if (!fin)
	   rc = 1;
	   
	while (fin)
	{
		if ( fread( &header, DatabaseHdrSize, 1, fin ) != 1 )
			break;

		// Return the type and creator ...
		if (!strncmp( header.type, DOC_TYPE, 4 ) )
			*type = [[NSString alloc] initWithBytesNoCopy:header.type length:8 encoding:kCGEncodingMacRoman freeWhenDone:NO];

		else if (!strncmp( header.type, "PNRdPPrs", 8 ) )
			*type = @"eReader";

		else if (!strncmp( header.type, "ToGoToGo", 8 ) )
			*type = @"iSilo";

		else if (!strncmp( header.type, "SDocSilX", 8 ) )
			*type = @"iSilo 3";

		else if (!strncmp( header.type, "DataPlkr", 8 ) )
			*type = @"Plucker";

		else if (!strncmp( header.type, "ToRaTRPW", 8 ) )
			*type = @"TomeRaider";

		else if (!strncmp( header.type, "BDOCWrdS", 8 ) )
			*type = @"WordSmith";

		else if (!strncmp( header.type, "BOOKMOBI", 8 ) )
			*type = @"MobiPocket";

		else if (!strncmp( header.type, "zTXTGPlm", 8 ) )
			*type = @"Weasel zTXT";

		else if (!strncmp( header.type, "DB99DBOS", 8 ) )
			*type = @"DB (Database)";

		else if (!strncmp( header.type, "JbDbJBas", 8 ) )
			*type = @"JFile";

		else if (!strncmp( header.type, "JfDbJFil", 8 ) )
			*type = @"JFile Pro";

		else if (!strncmp( header.type, "DATALSdb", 8 ) )
			*type = @"List (Database)";

		else if (!strncmp( header.type, "Mdb1Mdb1", 8 ) )
			*type = @"Mobile DB";

		else if (!strncmp( header.type, "DataSprd", 8 ) )
			*type = @"Quick Sheet";

		else if (!strncmp( header.type, "InfoTlIf", 8 ) )
			*type = @"TealInfo";

		else if (!strncmp( header.type, "dataTDBP", 8 ) )
			*type = @"ThinkDB";

		else if (!strncmp( header.type, "InfoINDB", 8 ) )
			*type = @"InfoView";

		else if (!strncmp( header.type, "SM01SMem", 8 ) )
			*type = @"SuperMemo";

		else if (!strncmp( header.type, "InfoINDB", 8 ) )
			*type = @"InfoView";

		else
			// Unknown - return type and creator
			*type = [[NSString alloc] initWithBytesNoCopy:header.type length:8 encoding:kCGEncodingMacRoman freeWhenDone:NO];
		
		// Note: Check for type=="TEXt" we will allow any creator
		//       "REAd" is the old Palm Reader, while "TlDc" is Teal doc
		if ( strncmp( header.type,    DOC_TYPE,    sizeof header.type ) 
			 /* || strncmp( header.creator, DOC_CREATOR, sizeof header.creator ) */ )
			break;

		num_records = ntohs( header.recordList.numRecords ) - 1; /* w/o rec 0 */

		/********** read record 0 ********************************************/

		SEEK_REC_ENTRY( fin, 0 );
		
		if (GET_DWord( fin, &offset ))		/* get offset of rec 0 */
			break;
		
		
		fseek( fin, offset, SEEK_SET );
		if ( fread( &rec0, sizeof rec0, 1, fin ) != 1 )
			break;

		compression = ntohs( rec0.version );
		if ( compression != COMPRESSED && compression != UNCOMPRESSED )
			break;


		*dest = [[NSMutableData alloc] initWithCapacity: rec0.rec_size * rec0.num_records];


		/********* read Doc file record-by-record ****************************/

		fseek( fin, 0, SEEK_END );
		file_size = ftell( fin );

		rc = 0;
		
		NEW_BUFFER( &buf );
		for ( rec_num = 1; !rc && rec_num <= num_records; ++rec_num ) {
			DWord next_offset;

			/* read the record offset */
			SEEK_REC_ENTRY( fin, rec_num );
			
			if (GET_DWord( fin, &offset ))
			{
				rc = 2;
				break;
			}

			/* read the next record offset to compute the record size */
			if ( rec_num < num_records ) {
				SEEK_REC_ENTRY( fin, rec_num + 1 );
				if (GET_DWord( fin, &next_offset ))
				{
					rc = 2;
					break;
				}
			} else
				next_offset = file_size;
				
			rec_size = next_offset - offset;

			/* read the record */
			fseek( fin, offset, SEEK_SET );
			buf.len = fread( buf.data, 1, rec_size, fin );
			if ( buf.len != rec_size )
			{
				rc = 2;
				break;
			}

			if ( compression == COMPRESSED )
				uncompress( &buf );

			//[dest appendString:[[NSString alloc] initWithBytesNoCopy:buf.data length:buf.len encoding:encoding freeWhenDone:NO]];
			[*dest appendBytes:buf.data length:buf.len];
		}

		FREE_BUFFER( &buf );
		
		rc = 0;
		break;
	}
	
	if (fin)
		fclose( fin );

	return rc;
	
} // decodeToString



/*****************************************************************************
 *
 * SYNOPSIS
 */
	void uncompress( register buffer *b )
/*
 * DESCRIPTION
 *
 *	Replace the given buffer with an uncompressed version of itself.
 *
 * PARAMETERS
 *
 *	b	The buffer to be uncompressed.
 *
 *****************************************************************************/
{
	Byte *const new_data = malloc( BUFFER_SIZE );
	int i, j;

	for ( i = j = 0; i < b->len; ) {
		register unsigned c = b->data[ i++ ];

		if ( c >= 1 && c <= 8 )
			while ( c-- )			/* copy 'c' bytes */
				new_data[ j++ ] = b->data[ i++ ];

		else if ( c <= 0x7F )			/* 0,09-7F = self */
			new_data[ j++ ] = c;

		else if ( c >= 0xC0 )			/* space + ASCII char */
			new_data[ j++ ] = ' ', new_data[ j++ ] = c ^ 0x80;

		else {					/* 80-BF = sequences */
			register int di, n;
			c = (c << 8) + b->data[ i++ ];
			di = (c & 0x3FFF) >> COUNT_BITS;
			for ( n = (c & ((1 << COUNT_BITS) - 1)) + 3; n--; ++j )
				new_data[ j ] = new_data[ j - di ];
		}
	}
	free( b->data );
	b->data = new_data;
	b->len = j;
}

