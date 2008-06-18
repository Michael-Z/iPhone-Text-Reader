//
//   textReader.app -  kludged up by Jim Beesley
//   This incorporates inspiration, code, and examples from (among others)
//   * The iPhone Dev Team for toolchain and more!
//   * James Yopp for the UIOrientingApplication example
//   * Paul J. Lucas for txt2pdbdoc
//   * http://iphonedevdoc.com/index.php - random hints and examples
//   * mxweas - UITransitionView example
//   * thebends.org - textDrawing example
//   * Books.app - written by Zachary Brewster-Geisz (and others)
//   * "iPhone Open Application Development" by Jonathan Zdziarski - FileTable/UIDeletableCell example
//   * http://garcya.us/ - for application icons
//   * Allen Li for help with rotation lock and swipe/gestures
//
//   This program is free software; you can redistribute it and/or
//   modify it under the terms of the GNU General Public License
//   as published by the Free Software Foundation; version 2
//   of the License.
//
//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License for more details.
//
//   You should have received a copy of the GNU General Public License
//   along with this program; if not, write to the Free Software
//   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 ~ Based on the PDB Shredder version 1.02 (21 Apr 2002) open source code
 ~ Written by Algernon E Mouse
 ~
 ~ This program is copyright, (c)2002. 
 ~ Vers 1.02 (c)2002 by Total F***in' Losers
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 ~ This program is copyright, (c)2002. 
 ~
 ~ You are granted a license to use this program under the terms of the GNU
 ~ Public License. You may view the license at the following URL:
 ~      http://www.gnu.org/copyleft/gpl.html
 ~ Note that without accepting this license, you have no right to use this
 ~ code.
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
 ~ If you'd like to work on this, go ahead.  Just post your source code 
 ~ somewhere, and maybe I'll see it.  
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  
 ~ NOTE: All code to handle encrypted/protected/DRM'd files has been removed!
 ~       This version on handles unencrypted/unprotected eReader files.
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


/* !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   NOTICE:
           This code contains no proprietary algorithms, decryption code, or 
           ability to handle DRM'd files.  All it does is use the well known 
           Palm PDB layout, the XOR 0xA5 trick, and the publicly available
           zlib routines (also used for the plucker pdb format) to display 
           the text in *unencrypted* freely available eReader/Peanut Press
           PDB files.

           This code only handles unencrypted/unprotected pdb files,
           it will never contain anything to defeat the DRM protections
           of encrypted books.  
           
           Do not pirate/copy/steal protected eBooks!
           
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! */



#import "textReader.h"
#import "MyTextView.h"


#include <zlib.h>

#import "pdbfile.h"






// From pdbshred.h
#define  WORD(ptr) (((*(octet *)(ptr))<<8)|(*(octet *)((ptr)+1)))
#define DWORD(ptr) (((*(octet *)(ptr))<<24)|(*(octet *)((ptr)+1)<<16)|\
                   (*(octet *)((ptr)+2)<<8)|(*(octet *)((ptr)+3)))




typedef int (*decrypt_fn)(octet *, int, octet *);
typedef int (*decompress_fn)(octet *, int, octet *, int); 


/* PDB Header Constants */
#define PDB_HDR_CREATOR    64
#define PDB_HDR_TYPE       60
#define PDB_HDR_NUMRECORDS 76

#define PDB_SIZEOF_HDR    78
#define PDB_SIZEOF_REC     8
#define PDB_REC(i) (PDB_SIZEOF_HDR+((i)*PDB_SIZEOF_REC))


#define PP1_HDR_VERSION        0
#define PP1_HDR_BLOCKS         8
#define PP1_HDR_SIZE           105+2+7+2
#define PP1_VERSION_COMPRESSED 2

#define PP2_HDR_VERSION      0
#define PP2_HDR_BLOCKS       2
#define PP2_HDR_FLAGS        4
#define PP2_HDR_DIGEST      44
#define PP2_HDR_KEY         64

/* We have low confidence in these values... */
#define PP2_FLAG_ZLIB      0x2000
#define PP2_FLAG_ENCRYPTED 0x4000

static char pp_type[4] = {'P','N','R','d'}; 
static char pp_creat[4] = {'P','P','r','s'};

static octet * bigbuf = NULL;
static int bigsize = 64*1024; 



// octet * read_whole_file( octet * fname )
static octet * read_whole_file(FILE * fd )
{
        off_t   filesize;
        octet * fileptr;
        int     nbytes;

        filesize = lseek(fd, 0, SEEK_END);
        (void)lseek(fd, 0, SEEK_SET);
        fileptr = (octet*)malloc(filesize+4);
        if (!fileptr )
                return NULL;

        *((quartet *)(fileptr)) = filesize;
        nbytes = pdbread(fd, (fileptr)+4, filesize);
        if (nbytes != filesize) {
                free(fileptr);
                return NULL;
        }

        return fileptr;
}



// static char BM_ID[2] = {'B','M'};
// static char PNG_ID[4] = {(char)0x89,'P','N','G'};
// static char GIF_ID[3] = {'G','I','F'};
// static char JPEG_ID[4] = {(char)0xFF,(char)0xD8,(char)0xFF,(char)0xE0};



// static int identify_extra_ext(octet * p, int size, char * extension)
// {
//     strcpy(extension, "out");
//     if ((size > 12) && 
//         (!memcmp(p,BM_ID,sizeof(BM_ID))) &&
//         (*(quartet *)(p+6) == 0) ) {
//         strcpy(extension,"bmp"); return 1;
//     } 
//     if ((size > sizeof(PNG_ID)) && 
//         (!memcmp(p,PNG_ID,sizeof(PNG_ID)))) { 
//         strcpy(extension,"png"); return 1;
//     }
//     if ((size > sizeof(GIF_ID)) && 
//         (!memcmp(p,GIF_ID,sizeof(GIF_ID)))) { 
//         strcpy(extension,"gif"); return 1;
//     }
//     if ((size > sizeof(JPEG_ID)) && 
//         (!memcmp(p,JPEG_ID,sizeof(JPEG_ID)))) { 
//         strcpy(extension,"jpg"); return 1;
//     }
//     return 0;
// }


static octet * get_record(octet * fileptr, int r, int * pSize)
{
        int     nRecords;
        quartet base, next;

        if (!fileptr) return NULL;
        nRecords = WORD(fileptr + 4 + PDB_HDR_NUMRECORDS);
        if (r >= nRecords) return NULL;

        if (r == (nRecords - 1)) {
                next = *(quartet *)fileptr;
        }
        else {
                next = DWORD(fileptr + 4 + PDB_REC(r+1));
        }
        base = DWORD(fileptr + 4 + PDB_REC(r));
        if ((base >= next) || (next > (*(quartet *)fileptr))) {
                return NULL;
        }
        if (pSize) *pSize = (next-base);
        return fileptr + 4 + base;
}


// decompress using zlib
static int inflate_decompress(octet * data, int len, octet * buf, int out)
{
    z_stream zs;
    int err;

    zs.zalloc = (alloc_func)0;
        zs.zfree = (free_func)0;
        zs.opaque = (voidpf)0;
        err = inflateInit(&zs);
    if (err)
        return -1;
    
    zs.avail_in = len;
    zs.next_in = data;
    zs.next_out = buf;
    zs.avail_out = out;
    zs.total_out = 0;
    err = inflate(&zs, Z_FINISH);
    if ((err != Z_OK) && (err != Z_STREAM_END)) 
        return -1;
    
    err = inflateEnd(&zs);
    if (err) 
        return -1;
    
    return zs.total_out;
}


static int palmdoc_decompress(octet * in, int len, octet * out, int out_len)
{
    int octets;
        octet c;
        int     offset, count;

        octets = 0;
        while (len--) {
                c = *(in++);
                octets++;
                /* 1..8  - Copy 'c' octets */
                if ( c >= 1 && c <= 8 ) {
                        octets += (c-1);
                        len -= c;
                        while ( c-- ) *(out++) = *(in++);
                }
                /* 0,09-7F = self */
                else if ( c <= 0x7F ) *(out++) = c;
                /* space + ASCII char */
                else if ( c >= 0xC0 ) {
                        octets++;
                        *(out++) = ' ';
                        *(out++) = c & 0x7F;
                }
                /* 0x80 .. 0xBF -- Previous octets */
                else {
                        offset = (c << 8) + *(in++);
                        count = (offset & 0x7) + 3;
                        offset = (offset & 0x3FFF) >> 3;
                        if (offset > octets)
                                return -1;
                        
                        len--;
                        octets += (count - 1);
                        while (count--)  {
                                // *(out++) = *(out - offset);
                                *out = *(out - offset);
                                out++;
                        }
                }
                if (octets > out_len) 
                        return -1;
                
        }
        return octets;
}


/* for unencrypted PDB files */
static int a5_decrypt( octet * data, int len, octet * key )
{
    while (len--)
        *(data++) ^= 0xa5;
    return 0;
}


// Main routine to chop up the file 
char filename[120];
char extension[6];
// int shred(octet * pFile)
static int shred(octet * pFile, NSMutableData * dest)
{
    octet * pRecord;
    int  nRecords;
    int  size, r, err;
    int  version;
    int  blocks;
    octet key[32];
    decrypt_fn decrypt = NULL;
    decompress_fn decompress = NULL;

    pRecord = get_record(pFile, 0, &size);
    if ((!pRecord) || (size < 2)) {
        return 2;
    }
    nRecords = WORD(pFile+4+PDB_HDR_NUMRECORDS);
    
    if ( (!memcmp(pFile+4+PDB_HDR_TYPE,pp_type,4)) &&
         (!memcmp(pFile+4+PDB_HDR_CREATOR,pp_creat,4)) ) {
        strcpy(extension,"pml");
        version = WORD(pRecord);

        /* Unencrypted, Uses old compression algorithm? */
        /* Need to handle version 2 and version A seperately */ 
        switch (version)
        {
        case 0x02:
            blocks = WORD(pRecord+PP1_HDR_BLOCKS);
            decrypt = a5_decrypt;
            if (WORD(pRecord+PP1_HDR_VERSION) & 2) {
                decompress = palmdoc_decompress;
            }
            break;
            
        case 0x04:
            blocks = WORD(pRecord+PP1_HDR_BLOCKS);
            decrypt = a5_decrypt;
            // This is almost certainly not right, but it works for the files
            // I get from manybooks.net ...
            decompress = palmdoc_decompress;
            break;
            
        case 0xA:
            /* This header needs more work! */
            blocks = WORD(pRecord+12);
            /* ZLIB compression */
            if (version & 0x8) 
                decompress = inflate_decompress;
            break;
            
        default:
            // No clue what to do with this - return an error
            // rather than risk blowing up something ...
            // NOTE: version > 0xff probably means DES encryption,
            //       which I am not going to try to handle.
            return 2;
        }
    } 
    else {
        // Unknown pdb creator ...
        return 2;
    }



    err = 0;
    for (r = 1; r < blocks; r++) 
    {
        pRecord = get_record(pFile, r, &size);
        if (!pRecord) { 
            return 1;
        }
        if (decrypt) err = decrypt(pRecord,size, key);
        if (err < 0) {
            return 2;
        }
        if (decompress) err = decompress(pRecord,size,bigbuf,bigsize);
        else { memcpy(bigbuf, pRecord, size); err = size; }
        if (err < 0) {
            return 2;
        }

        // Write out this chunk of text ...
        [dest appendBytes:bigbuf length:err];                    
        
    }


// JIMB BUG BUG - code to write out images... Fix this!
//     err = 0;
//     filenum = 1;
//     for (r=blocks;r < nRecords;r++) {
//         pRecord = get_record(pFile, r, &size);
//         if (!pRecord) { 
// //          fprintf(stderr,"Error reading block #%d! \n",r);
//             return -1;
//         }
// 
//         /* Dammit, another Ppress hack */
//         if (memcmp(pRecord, "PNG ", 4) == 0) {
//             strncpy(filename, (char*)pRecord+4, sizeof(filename));
//             pRecord += 62;
//             if (size <= 62) {
// //              fprintf(stderr,"Bad PNG record in block #%d!\n",
// //                  r);
//                 return -1;
//             } 
//             size -= 62;
//         } else {
//             err = identify_extra_ext(pRecord,size, extension);
//             if ((!err) && (!param_all)) continue;   
// 
//             // sprintf(filename,"%.80s%03d.%s",param_base,filenum, 
//             //                 extension);
//             filenum++; 
//         }
//     
// //        err = write_whole_file((unsigned char*)filename,pRecord, size);
//         if (err) {
// //          fprintf(stderr,"   Unable to write block #%d!\n",r);
//         }
//     }

    return 0;
}


// Wrapper for shred ...
int eReader_shred(FILE * fp, NSMutableData * dest)
{
    octet * pFile = NULL;
    int     rc = 0;
    
    bigbuf = (unsigned char*)malloc(bigsize);
    if (!bigbuf)
        return 1;

    pFile = (unsigned char*)read_whole_file(fp);
    if (!pFile)
        rc = 1;
    else
    {
        int filesize = *(quartet *)pFile;

        if (filesize < PDB_SIZEOF_HDR) {
            rc = 2;
        } 
        else
            rc = shred(pFile, dest);
    }

    if (pFile)
        free(pFile); 
    if (bigbuf)
        free(bigbuf); 
    
    return rc;
    
} // eReader_shred




