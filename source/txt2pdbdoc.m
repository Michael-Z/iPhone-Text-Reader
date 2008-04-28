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


/* local */
#include "palm.h"

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

void		compress( buffer* );
Byte*		mem_find( Byte *t, int t_len, Byte *m, int m_len );
void		remove_binary( buffer* );
void		uncompress( buffer* );



// 0 == success
// 1 == error 
// 2 == invalid format
int decodeToString(NSString * src, NSMutableString * dest)
{
	buffer			buf = {0};
	int		    	compression;
	DWord			file_size, offset, rec_size;
	FILE			*fin = NULL;
	DatabaseHdrType	header;
	int				num_records, rec_num;
	doc_record0		rec0;
	
	int             rc = 2;


	/********** open files, read header, ensure source is a Doc file *****/

	fin = fopen([src cString], "rb");
	if (!fin)
	   rc = 1;
	   
	while (fin)
	{
		if ( fread( &header, DatabaseHdrSize, 1, fin ) != 1 )
			break;

		if ( strncmp( header.type,    DOC_TYPE,    sizeof header.type ) ||
			 strncmp( header.creator, DOC_CREATOR, sizeof header.creator ) )
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

			[dest appendString:[[NSString alloc] initWithBytesNoCopy:buf.data length:buf.len encoding:kCGEncodingMacRoman freeWhenDone:NO]];
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

/*****************************************************************************
 *
 *	Miscellaneous function(s)
 *
 *****************************************************************************/

/* replacement for strstr() that deals with 0's in the data */
Byte* mem_find( register Byte *t, int t_len, register Byte *m, int m_len ) {
	register int i;
	for ( i = t_len - m_len + 1; i > 0; --i, ++t )
		if ( *t == *m && !memcmp( t, m, m_len ) )
			return t;
	return 0;
}


