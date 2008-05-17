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


#import "pdbfile.h"

#include "unpluck.h"

// ----------------------------------------------------------
// Begin palm.h defines
// ----------------------------------------------------------
/* standard */
//#include <time.h>



/********** Plucker stuff ******************************************************/


typedef struct {
  int   size;
  int   attributes;
} ParagraphInfo;

static ParagraphInfo *ParseParagraphInfo(unsigned char* bytes, int len, int* nparas) {
  ParagraphInfo*  paragraph_info;
  int             j;
  int             n;
  
  n =(bytes[2] << 8) + bytes[3];
  paragraph_info =(ParagraphInfo *) malloc(sizeof(ParagraphInfo) * n);
  for(j = 0; j < n; j++) {
    paragraph_info[j].size =
    (bytes[8 +(j * 4) + 0] << 8) + bytes[8 +(j * 4) + 1];
    paragraph_info[j].attributes =
      (bytes[8 +(j * 4) + 2] << 8) + bytes[8 +(j * 4) + 3];
  }
  *nparas = n;
  return paragraph_info;
}


#define GET_FUNCTION_CODE_DATALEN(x)((x) & 0x7)



// Handle the plucker file ...
int decodePlucker(NSString * src, NSMutableData ** dest, NSString ** type)
{
	plkr_Document *  doc;
	unsigned char *  text;
	int              textL;
	int              rec;
	
 	doc = plkr_OpenDBFile(src);
 	if (!doc)
 		return 1;
 		
	*dest = [[NSMutableData alloc] initWithCapacity:4096];

	// Do stuff here ...

	[*dest appendBytes:"<html><head><body>" length:18];

	text  = plkr_GetName(doc);
	textL = strlen(text);
	[*dest appendBytes:"<book-title>" length:12];
	[*dest appendBytes:text length:textL];
	[*dest appendBytes:"</book-title>" length:13];
		
	for (rec = 0; rec <= plkr_GetRecordCount(doc); rec++)
	{
		plkr_DataRecordType   type;
		unsigned char       * data, * para_start;
		int                   data_len, fctype, fclen;

		ParagraphInfo * paragraphs;
		int             nparagraphs;
		int 			para_index, para_len;
		unsigned char * run;
		unsigned char * start; 
		unsigned char * ptr; 
		
		int             uid = plkr_GetRecordUid(doc, rec);

		// data = plkr_GetRecordBytes(doc, rec, &data_len, &type);
		data = plkr_GetRecordBytes(doc, uid, &data_len, &type);
		if (!data || 
			(type != PLKR_DRTYPE_TEXT_COMPRESSED && type != PLKR_DRTYPE_TEXT))

			continue;

		paragraphs = ParseParagraphInfo(data, data_len, &nparagraphs);
		start = data + 8 + ((data[2] << 8) + data[3]) * 4;
	
	
		for(para_index = 0, ptr = start, run = start; para_index < nparagraphs; para_index++) 
		{	
			[*dest appendBytes:"<p>" length:3];

			para_len = paragraphs[para_index].size;

			for (para_start = ptr; ((ptr - para_start) < para_len) && (ptr < data + data_len);) 
			{

			if (!*ptr) 
			{
				/* function code */

				if ((ptr - run) > 0) 
				   // append run, (ptr-run)
				   [*dest appendBytes:run length:ptr-run];

				ptr++;

				fctype = PLKR_FC_CODE(*ptr);
				fclen  = GET_FUNCTION_CODE_DATALEN(*ptr);
				ptr++;

				switch (fctype)
				{
					// Missing the following functions
					// PLKR_FC_CODE(0x0B) // Targeted page link begins 3 record ID, target 
					// PLKR_FC_CODE(0x0C) // Paragraph link begins 4 record ID, paragraph number 
					// PLKR_FC_CODE(0x0D) // Targeted paragraph link begins 5 record ID, paragraph number, target 
					// PLKR_FC_CODE(0x08) // Link ends 0 no data 
					// PLKR_FC_CODE(0x85) 32-bit Unicode character 5 alternate text length, 32-bit unicode character 
					// PLKR_FC_CODE(0x9A) Exact link modifier 2 Paragraph Offset 
					//      (The Exact Link Modifier modifies a Paragraph Link or Targeted Paragraph 
					//       Link function to specify an exact byte offset within the paragraph. 
					//       This function must be followed immediately by the function it modifies). 


					// PLKR_FC_CODE(0x0A) // Page link begins 2 record ID 
					case PLKR_TFC_LINK:
						switch(fclen) {
							case 4:        /* ANCHOR_BEGIN */
							{
							  // int              record_id = (ptr[2] << 8) + ptr[3];
							  // plkr_DataRecordType   type = (plkr_DataRecordType)plkr_GetRecordType(doc, record_id);
              
							  //  if(type == PLKR_DRTYPE_IMAGE || type == PLKR_DRTYPE_IMAGE_COMPRESSED)
							  // 		???
							  //  else
							  // 		???
							  //  Do something with this record_id
							}
							break;

							case 2:        /* ANCHOR_END */
							  // Ignore ...
							break;
						}
						break;
						
					// PLKR_FC_CODE(0x38) // New line 0 no data 
					case PLKR_TFC_NEWLINE:
						[*dest appendBytes:"<br />" length:6];
						break;
						
					// PLKR_FC_CODE(0x33) Horizontal rule 3 8-bit height, 8-bit width (pixels), 8-bit width (%, 1-100) 
					case PLKR_TFC_HRULE:
						[*dest appendBytes:"<br /><br />" length:12];
						break;
						
					// PLKR_FC_CODE(0x83) // 16-bit Unicode character 3 alternate text length, 16-bit unicode character 
					case PLKR_TFC_UCHAR:
						{
							char tmp[16] = {0};
							
							if(fclen == 3)
								sprintf(tmp, "&#%d;", (ptr[1] << 8) + ptr[2]);
							else if(fclen == 5)
								sprintf(tmp, "&#%d;", (ptr[3] << 8) + ptr[4]);
							[*dest appendBytes:tmp length:strlen(tmp)];
					  	}
					  	
			            // skip over alternate text
           			    ptr += ptr[0];
           			    break;
						
					default:
					    // Ignore ...
					    break;
				}

				ptr += fclen; // Should this be fclen-1 since we already ++'d earlier???
				run = ptr;
      		}
	  		else 
		        ptr++;

	    } // for para_start = ptr

		// Write out remaining text ...
    	if ((ptr - run) > 0) 
		{
		  // append run, (ptr-run)
		  [*dest appendBytes:run length:ptr-run];
      	  run = ptr;
    	}
    	
		[*dest appendBytes:"</p>" length:4];
		
	} // for each paragraph in the record

	free(paragraphs);

	} // for each record
	
	[*dest appendBytes:"</body></head></html>" length:21];	
	
 	plkr_CloseDoc(doc);	
	
	return 0;
	
} // decodePlucker




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


void		pdbuncompress( buffer* );


// 0 == success
// 1 == error 
// 2 == invalid format
int decodePDB(NSString * src, NSMutableData ** dest, NSString ** type)
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

	fin = fopen(src, "rb");
	if (!fin)
	   rc = 1;
	   
	while (fin)
	{
		if ( fread( &header, DatabaseHdrSize, 1, fin ) != DatabaseHdrSize )
			break;

		// Return the type and creator ...
		if (!strncmp( header.type, "DataPlkr", 8 ) )
		{
			// We handle plucker below
			*type = @"Plucker";
			rc = 0;
			break;
		}
		
		else if (!strncmp( header.type, DOC_TYPE, 4 ) )
			*type = [[NSString alloc] initWithBytesNoCopy:header.type length:8 encoding:kCGEncodingMacRoman freeWhenDone:NO];

		else if (!strncmp( header.type, "PNRdPPrs", 8 ) )
			*type = @"eReader";

		else if (!strncmp( header.type, "ToGoToGo", 8 ) )
			*type = @"iSilo";

		else if (!strncmp( header.type, "SDocSilX", 8 ) )
			*type = @"iSilo 3";

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
		// 		 "BOOKMOBI" is MobiPocket HTML ...
		if ( strncmp( header.type,    DOC_TYPE,    sizeof header.type ) 
			 && strncmp( header.type, "BOOKMOBI", sizeof header.type ) )
			break;

		num_records = ntohs( header.recordList.numRecords ) - 1; /* w/o rec 0 */

		/********** read record 0 ********************************************/

		SEEK_REC_ENTRY( fin, 0 );
		
		if (GET_DWord( fin, &offset ))		/* get offset of rec 0 */
			break;
		
		
		fseek( fin, offset, SEEK_SET );
		if ( fread( &rec0, sizeof rec0, 1, fin ) != sizeof rec0 )
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
		for ( rec_num = 1; !rc && rec_num <= num_records; ++rec_num ) 
		{
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

			// Ignore records larger than BUFFER_SIZE - they are pictures, etc. we will ignore
            if (rec_size > BUFFER_SIZE)
               break;

			/* read the record */
			fseek( fin, offset, SEEK_SET );

			buf.len = fread( buf.data, 1, rec_size, fin );
			if ( buf.len != rec_size )
			{
				rc = 2;
				break;
			}

			if ( compression == COMPRESSED )
				pdbuncompress( &buf );			
	
			[*dest appendBytes:buf.data length:buf.len];					
		}

		FREE_BUFFER( &buf );
		
		rc = 0;
		break;
	}
	
	if (fin)
		fclose( fin );
		
	// Handle Plucker files ...
	if (!rc && !strncmp( header.type, "DataPlkr", 8 ))
		rc = decodePlucker(src, dest, type);
		
	return rc;
	
} // decodePDBToString



/*****************************************************************************
 *
 * SYNOPSIS
 */
	void pdbuncompress( register buffer *b )
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

