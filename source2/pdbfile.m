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

#import "textReader.h"
#import "MyTextView.h"

#import "pdbfile.h"


// KLUDGE to allow use of memory mapped NSData instead of FILE * handle



// ***********************************************


int GET_DWord(pdbFILE * fin, DWord * n)
{
    if (fin->pos + sizeof(DWord) >= [fin->data length])
        return 1;

    NSRange range = {fin->pos, sizeof(DWord)};

    [fin->data getBytes:n range:range];

    fin->pos += range.length;

    *n = ntohl(*n);

    return 0;
}

int pdbfseek(pdbFILE * fin, size_t offset, int start)
{
    if (!fin)
        return -1;
        
    if (start == SEEK_END)
    {
        fin->pos = [fin->data length];
        return fin->pos;
    }
    else if (start == SEEK_SET)
    {
        fin->pos = offset;

        if (fin->pos >= [fin->data length])
            return -2;

        return fin->pos;
    }

    return -3;
}

pdbFILE * pdbfopen(NSString * fullpath)
{
    NSData * data = [[NSData dataWithContentsOfMappedFile:fullpath] retain];
    if (!data)
        return nil;

    pdbFILE * fin = (pdbFILE *)malloc(sizeof(pdbFILE));
    if (fin)
    {
        fin->pos = 0;
        fin->data = data;
    }
    else
        [data release];

    return fin;
}

void pdbfclose(pdbFILE * fin)
{
    if (fin)
    {
        [fin->data release];
        free(fin);
    }
}

int pdbfread( void *buf, size_t size, int cnt, pdbFILE * fin)
{
    NSRange range = {fin->pos, MIN(size*cnt, [fin->data length]-fin->pos)};
    [fin->data getBytes:buf range:range];

    fin->pos += range.length;

    return range.length;
}


NSUInteger pdbftell(pdbFILE * fin)
{
    if (fin)
        return fin->pos;

    return 0;
}

int pdbfstat(pdbFILE * fin, struct pdbstat * stat)
{
    stat->st_size = [fin->data length];
    return 0;
}


int pdbread(pdbFILE * fin, void *buf, size_t size)
{
    return pdbfread( buf, size, 1, fin);
}

// size_t strlen(const unsigned char * str)
// {
//  size_t len;
//  if (!str)
//     return 0;
//  for (len = 0; *str; str++, len++);
//  return len;
// }



// ***********************************************

