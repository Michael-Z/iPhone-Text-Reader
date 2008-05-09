//
//
//   textReader.app -  kludged up by Jim Beesley 
//   This incorporates inspiration, code, and examples from (among others)
//   * http://iphonedevdoc.com/index.php - random hints
//   * jYopp - http://jyopp.com/iphone.php - UIOrientingApplication example
//   * mxweas - UITransitionView example
//   * thebends.org - textDrawing example
//   * "iPhone Open Application Development" by Jonathan Zdziarski - FileTable/UIDeletableCell example
//   * BooksApp, written by Zachary Brewster-Geisz (and others)
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
//

#import "textReader.h"
#import "MyTextView.h"

#import <UIKit/UIKit.h>

// NOTE: This adds about 16K to the program!
// JIMB BUG BUG - look into a better way to "band" the conversion data
// Can we use the "add 160" algorithm?
#import "gb2312.h"

typedef unsigned int NSUInteger;




// *****************************************************************************
@implementation MyTextView


-(id) init {
	struct CGRect rect = [UIHardware fullScreenApplicationContentRect];
    rect.origin.x = rect.origin.y = 0.0f;

	return [self initWithFrame:rect];	
};

-(id) initWithFrame:(CGRect)rect {
	text       = nil;
	
    screenLock = [[NSLock alloc] init];

	wait     = nil;
	color    = 0;
	ignoreNewLine = false;
	padMargins = false;
	
	gsFont   = nil;
	font     = TEXTREADER_DFLT_FONT;
	fontSize = TEXTREADER_DFLT_FONTSIZE;
	
	encoding = TEXTREADER_DFLT_ENCODING;

	// Kind of a kludge, but we need to get the gb2312 encoding somehow ...
	const NSStringEncoding * enc = [NSString availableStringEncodings];
	while (enc && *enc)
	{
		NSString * gb2312name = @"Simplified Chinese (EUC)";
		if ([gb2312name compare:[NSString localizedNameOfStringEncoding:*enc]] == NSOrderedSame)
		   break;
		enc++;
	}
	gb2312enc = (enc && *enc) ? *enc : 0;
	
	start = end = 0;
	trApp = nil;
	pageUp = false;
	fileName = nil;
	filePath = [TEXTREADER_DEF_PATH copy];
	
//	// Make sure default directory exists
//	BOOL dir = true;
//	if (![[NSFileManager defaultManager] fileExistsAtPath:TEXTREADER_DEF_PATH isDirectory:&dir])
		[[NSFileManager defaultManager] createDirectoryAtPath:TEXTREADER_DEF_PATH attributes:nil];
	
    return [super initWithFrame:rect];
} // initWithFrame


- (void) setTextReader:(textReader*)tr {
	trApp = tr;
} // setTextReader


// 0 = black text on white
// 1 = white text on black
- (void) setColor:(int)newColor {
	color = newColor ? 1 : 0;
	[self setNeedsDisplay];
} // setColor


- (void) setIgnoreNewLine:(bool)ignore {
	ignoreNewLine = ignore;
	[self setNeedsDisplay];
}

- (void) setPadMargins:(bool)pad {
	padMargins = pad;
	[self setNeedsDisplay];
}

- (int) getColor { return color; }
- (bool) getIgnoreNewLine { return ignoreNewLine; }
- (bool) getPadMargins { return padMargins; }
- (NSMutableString *) getText  { return text; }
- (int) getStart { return start; }
- (int) getEnd   { return end; }
- (NSString*) getFileName { return fileName; }
- (NSString*) getFilePath { return filePath; }

// Last page movement was a page up?
- (void) pageUp {
	pageUp = true;

	// Force a screen update ...
	[self setNeedsDisplay];
} // pageUp


// Last page movement was a page down?
- (void) pageDown {
	pageUp = false;
	
	// Reset start pos
	[self setStart:[self getEnd]];
} // pageUp


- (void) setStart:(int)newStart {
	if (text)
	{
		start = MIN([text length], MAX(0, newStart));
		
		// Force a screen update ...
		[self setNeedsDisplay];
	}
} // setStart


// Fill in background with proper color, and then set the text colors
- (void)fillBkgGroundRect:(CGContextRef)context rect:(CGRect)rect {

	// Blank out the rect
	if (color)
		CGContextSetRGBFillColor(context, 0, 0, 0, 1); // black
	else
		CGContextSetRGBFillColor(context, 1, 1, 1, 1); // white
	CGContextFillRect(context, rect);

	// Restore text colors
	if (color)
	{
		CGContextSetRGBFillColor(context, 1, 1, 1, 1); // white
		CGContextSetRGBStrokeColor(context, 1, 1, 1, 1); // white
	}
	else
	{
		CGContextSetRGBFillColor(context, 0, 0, 0, 1);  // black    
		CGContextSetRGBStrokeColor(context, 0, 0, 0, 1); // black 
	}
	
} // fillBkgGroundRect


typedef enum _Direction {
	kDirectionDone     = 0,
	kDirectionForward  = 1,
	kDirectionBackward = 2
} Direction;

- (unichar) currentChar:(int)current direction:(Direction)dir {
	
	unichar c = 0x00;	
	
	if (dir==kDirectionBackward)
	{
		if (current >= 0)
			c = [text characterAtIndex:current];
	}
	else
	{
		if (current < [text length])
			c = [text characterAtIndex:current];
	}
	return c;
	
} // currentChar


// Missing Prototypes ...
struct __GSFont * GSFontCreateWithName( const char * fontname, int style, float ptsize);
// bool CGFontGetGlyphsForUnichars(CGFontRef, unichar[], CGGlyph[], size_t);
// extern CGFontRef CGContextGetFont(CGContextRef);
// extern CGFontRef CGFontCreateWithFontName (CFStringRef name);


- (void)drawRect:(struct CGRect)rect
{
	// These are used below to blank bkgrnd and draw text
	CGSize          used;
	NSString      * x;
    struct CGRect   lineRect;
	
	// If no text, nothing to do ...
	if (!text || !trApp || !gsFont)
	   return [super drawRect:rect];

	[screenLock lock];
	
	CGPoint currentPt = CGPointMake(0,0);
	CGSize viewSize = [trApp getOrientedViewSize];

  	CGContextRef context = UICurrentContext();

	// Get font metrics instead of this kludge!!!
	// No idea how to get info from a GSFont tho ...

   int lineHeight = fontSize * 1.25+1; // Blech!!! Figure this properly!!!
   int lines      = viewSize.height / lineHeight;
   int width      = viewSize.width;
   int hpad       = padMargins ? 10 : 0;
   int vpad       = (viewSize.height - lineHeight*lines) / 2;
   int line, current;
   Direction dir;

   // Handle pageup by looping twice
   dir = pageUp ? kDirectionBackward : kDirectionForward;

   // Blank the top "pad" portion of the screen
   lineRect = CGRectMake(0, 0, width, vpad);
   [self fillBkgGroundRect:context rect:lineRect];

   // First loop is invisible going backwards figuring a new start for pageUp
   // Second loop writes text
   while (dir)	
   {
  	   struct CGPoint lastBlankPoint;
	   int            lastBlankIndex;
	   int            afterCrLf = false;
	   
	   current = dir==kDirectionBackward ? MAX(0,start-1) : start;

// JIMB BUG BUG - optimize this!  Only draw lines that are in the visible rect!
// (Too much trouble for now, plus it seems fast enough as is ...)
	  for (line = 0; line < lines; line++) 
	  {
		bool           emptyLine = true;
		
		// Keep track of the last blank in this line 
		lastBlankIndex = -1;

// JIMB BUG BUG - clean up the rect calculations  	
// We really want this to cover the writing for this line (with descenders), but 
// not take out the descenders from the line above.
		// Update lineRect - it can get munged when we blank the end of the line
		lineRect = CGRectMake(0, vpad + line * lineHeight, width, lineHeight);

  	    if (dir==kDirectionForward)
			[self fillBkgGroundRect:context rect:lineRect];

		currentPt = CGPointMake(hpad, vpad + line * lineHeight);

		while  ( (dir==kDirectionBackward && (current > 0)) || 
		         (dir==kDirectionForward && (current < [text length])))
		{
			struct CGPoint beginPoint = currentPt;
			unichar c = [self currentChar:current direction:dir];

			// Move backwards or forwards as needed
			current = dir==kDirectionBackward ? MAX(0,current-1) : current+1;

			// Find the next character
			unichar nextc = [self currentChar:current direction:dir];
			
			// Special case for Windows CRLF x0d0a- only use one
			if (dir==kDirectionBackward)
			{
				if (c == 0x0a && nextc == 0x0d)
				{
					current--;
					nextc = [self currentChar:current direction:dir];
				}
			}
			else
			{
				if (c == 0x0d && nextc == 0x0a)
				{
					current++;
					nextc = [self currentChar:current direction:dir];
				}
			}

			// Handle ignore single LF option
			if (ignoreNewLine && (c == '\n' || c == 0x0d || c == 0x0a))
			{
				if (nextc != '\n' && nextc != 0x0d && nextc != 0x0a)
				{
				   afterCrLf = true;
				   if (nextc == ' ' || nextc == '\t')
				   	  continue;
				   c = ' ';
				}
			}
			   
			// Special case for white space chars
			if (c == '\n' || c == 0x0d || c == 0x0a)
			{
			   afterCrLf = true;
			   break;
			}

			// Eat leading blanks on a new line, unless they follow a CR/LF
			if (c == ' ' && emptyLine && !afterCrLf)
			   continue;

// JIMB BUG BUG - allow breaking a line of text at a '-' as well
			// Remember blanks - we will back up to 
			// here when we run out of space (tabs should work correctly ... I hope)
			if (c == ' ' || c == '\t')
			{
				lastBlankIndex = current; // this is actually 1 past ...
				lastBlankPoint = currentPt;
			}

			// At this point, we are going to try to write something ...
			emptyLine = false;
			afterCrLf = false;

			// Get the substring we want to draw ...
			// special case a tab as 4 blanks (should we do "real" tab stops?!?!?)
			if (c == '\t')
				x = @"   ";
			else
				x = [NSString stringWithCharacters:&c length:1];

			// Draw the text, or just get bounding box if we are looping ...
			if (dir==kDirectionBackward)
				used = [x sizeWithFont:gsFont];
			else
			{
				CGPoint tmpPt = currentPt;
				tmpPt.y++;
				used = [x drawAtPoint:tmpPt withFont:gsFont];
			}

			// Update the current position at the end of the text we drew
			currentPt.x += used.width;
		
			struct CGPoint endPoint = currentPt;
			if (endPoint.x > (width-hpad))
			{
				// Can we back up to a blank?
				if (lastBlankIndex > 0)
				{
					// plus one skips this space
					current    = dir==kDirectionBackward ? MAX(0,lastBlankIndex-1) : lastBlankIndex+1; 
					beginPoint = lastBlankPoint;
				}
				else
				{
// JIMB BUG BUG - add a trailing '-' when we are forced to break a word?!?!
// This is tricy to calculate - we probably ought to calc the size needed above
// and save it so we know how far to back up - it might be several characters,
// but I suspect 1 character plus whatever partial char put us past the edge will
// probably be enough.  Two plus partial ought to always be sufficient ...
				}

				// No need to erase if going backwards
				if (dir==kDirectionForward)
				{
					// Erase the last partial character(s) (back to last blank if possible)
					lineRect.origin.x = beginPoint.x;
					[self fillBkgGroundRect:context rect:lineRect];
				}
				
				// Save the new current position 
				// (i.e. before the one that put us past the edge)
				current = dir==kDirectionBackward ? MAX(0,current+1) : current-1;
				break;
			}

		} // while space on this line

	  } // for each line
	
	  // reset the start of the previous page we just calculated
	  if (dir==kDirectionBackward)
	  {  	
	    // Make sure we are starting after the last blank space
	    if (lastBlankIndex > 0)
	    	current = lastBlankIndex+1;
	  	
	    // save this as our new start position
		start = MIN(MAX(0,current),[text length]);
      }
      
      // We are done with this direction ... any more?
      dir--;
		
   } // while direction

   // Blank any remaining space at the bottom of the screen
   lineRect = CGRectMake(0, vpad + line * lineHeight, width, lineHeight);
   [self fillBkgGroundRect:context rect:lineRect];

   // Remember the last text we display
   end = current;
  
   // Reset pageup flag - one way or the other it is done now ...
   pageUp = false;

   [screenLock unlock];
  
   return [super drawRect:rect];
  
} // drawRect



- (void)mouseDown:(struct __GSEvent*)event {
	[ [self tapDelegate] mouseDown: event ];
	[ super mouseDown: event ];
} // mouseDown
 
 
- (void)mouseUp:(struct __GSEvent *)event {
	[ [self tapDelegate] mouseUp: event ];
	[ super mouseUp: event ];
} // mouseUp



// Set the new text for this view
- (void) setText:(NSMutableString  *)newText; {

	[screenLock lock];
	
	if (text)
		[text release];
	text = newText;
	
	[screenLock unlock];

	[self setNeedsDisplay];	

} // newText
			
	
// Convert an NSData with "invalid" GB2312 data into a UTF16 string
static NSMutableString * convertGB2312Data(NSData * data) {
	int 			      i;
	unichar 		      c[8096];
	int                   cL = 0;
	const unsigned char * p = [data bytes];
	
	// Add characters to the mutable string in 8K chunks to speed up the transcoding
	NSMutableString * newText = [[NSMutableString alloc] initWithCapacity:[data length]/2];
	
	for (i = 0; i < [data length]; i++, p++)
	{
		if (*p < 0xA1)
			c[cL++] = *p;
		else if (i+1==[data length])
			c[cL++] = 0x00; // Encoding error! - last byte (or more) got chopped off!
		else if (*p > 0xF7)
		{
			// Encoding error!
			// What to do?!?!? Skip next character ...
			// JIMB BUG BUG - should we treat as an ASCII char instead ?!?!?
			c[cL++] = 0x00;
			p++; i++;
		}
		else
		{
			c[cL++] = gb2312map[(p[0]-0xA1)*0x60 + p[1]-0xA1];
			p++; i++;
		}
		if (cL == sizeof(c)/sizeof(*c))
		{
			[newText appendFormat:@"%*S", cL, c];
			cL = 0;
		}
	}
	
	// Add any remaining characters
	if (cL)
	{
		[newText appendFormat:@"%*S", cL, c];
		cL = 0;
	}
	
	return newText;
	
} // convertGB2312

// Load the specified file into NSData and convert to string
static NSMutableString * loadGB2312(NSString * fullpath) {

	NSMutableString * str = nil;
	
	NSData * data = [NSData dataWithContentsOfMappedFile:fullpath];
	if (!data)
		return nil;
	
	str = convertGB2312Data(data);
	
	return str;
} // loadGB2312
	
	
	
	
// ---------------------------------------------
// Thread specific code ...
// ---------------------------------------------


// findChar
// Returns offset of char or 0 if not found
NSUInteger getTag(NSString * str, NSUInteger start, NSUInteger end, char * upTag, char * lowTag)
{
	NSUInteger i, j;

	// 0 means search to the end	
	if (!end)
		end = [str length];

	// search to the end ...
	while (true)
	{
		// Special case mixed case search
		if (lowTag)
		{
			for (i = start; i < end; i++)
			{
				unichar c = [str characterAtIndex:i];
				if (c==*upTag || c==*lowTag)
					break;
			}
		}
		else
		{
			for (i = start; i < end; i++)
			{
				if ([str characterAtIndex:i]==*upTag)
					break;
			}
		}

		// End of string ... not found ...
		if (i >= end)
			break;

		// Found first char - the rest must follow
		// Special case mixed case search
		if (lowTag)
		{
			for (j = 1; upTag[j]; j++)
			{
				unichar c = [str characterAtIndex:i+j];
				if (c!=upTag[j] && c!=lowTag[j])
					break;
			}
		}
		else
		{
			for (j = 1; upTag[j]; j++)
			{
				if ([str characterAtIndex:i+j]!=upTag[j])
					break;
			}
		}
		
		// If we hit the end of the pattern, we found it!
		if (!upTag[j])
			return i;
		
		// Otherwise, we keep looking ...
		start = i+1;
	}
	
	// Return found position
	return 0;
	
} // findTag


// JIMB BUG BUG - rewrite this so it is sorted table driven!
// There are way more than I planned to support ...


// Adds the specified block of text from src to dest
// Removes CR/LF
// Converts &nbsp; &copy; &ndash; &mdash; &amp; &eacute; 
// Adds other text "as-is"
void addHTMLText(NSString * src, NSRange rtext, NSMutableString * dest) {

	NSRange added = {[dest length], 1};
	
	[dest appendString:[src substringWithRange:rtext]];
	
	while (added.location < [dest length])
	{
		unichar c = [dest characterAtIndex:added.location];
		if (c==0x0a || c==0x0d)
			[dest deleteCharactersInRange:added];
		else if (c=='&')
		{
			// Expand Character Entities
// JIMB BUG BUG - will this cause problems for fb2 ?!?!?!?!?			
			// look for the ending ';'
			added.length = getTag(dest, added.location+1, added.location+16, ";", NULL);
			if (added.length)
			{
				UniChar entity = 0x0000;
				
				added.length -= added.location-1;

				switch (added.length) 
				{
					case 4:
						// gt		003E
						if (getTag(dest, added.location, added.location+added.length, "GT;", "gt;"))
							entity = 0x003E;
						// lt		003C
						else if (getTag(dest, added.location, added.location+added.length, "LT;", "lt;"))
							entity = 0x003C;
					break;

					case 5:
						// amp		0026
						if (getTag(dest, added.location, added.location+added.length, "AMP;", "amp;"))
							entity = 0x0026;
						// reg    	00AE
						else if (getTag(dest, added.location, added.location+added.length, "REG;", "reg;"))
							entity = 0x00AE;
						// uml		00A8
						else if (getTag(dest, added.location, added.location+added.length, "UML;", "uml;"))
							entity = 0x00A8;
						// yen		00A5
						else if (getTag(dest, added.location, added.location+added.length, "YEN;", "yen;"))
							entity = 0x00A5;
					break;

					case 6:
						// copy	  	00A9 
						if (getTag(dest, added.location, added.location+added.length, "COPY;", "copy;"))
							entity = 0x00A9;
						// cent		00A2	
						else if (getTag(dest, added.location, added.location+added.length, "CENT;", "cent;"))
							entity = 0x00A2;
						// emsp		2003
						else if (getTag(dest, added.location, added.location+added.length, "EMSP;", "emsp;"))
							entity = 0x2003;
						// ensp		2002
						else if (getTag(dest, added.location, added.location+added.length, "ENSP;", "ensp;"))
							entity = 0x2002;
						// euro		20ac
						else if (getTag(dest, added.location, added.location+added.length, "EURO;", "euro;"))
							entity = 0x20AC;
						// nbsp   	00A0
						else if (getTag(dest, added.location, added.location+added.length, "NBSP;", "nbsp;"))
							entity = 0x00A0;
						// quot		0022	
						else if (getTag(dest, added.location, added.location+added.length, "QUOT;", "quot;"))
							entity = 0x0022;
					break;

					case 7:
						// acute	00B4
						if (getTag(dest, added.location, added.location+added.length, "ACUTE;", "acute;"))
							entity = 0x00B4;
						// bdquo	201E
						else if (getTag(dest, added.location, added.location+added.length, "BDQUO;", "bdquo;"))
							entity = 0x201E;
						// iexcl    00A1
						else if (getTag(dest, added.location, added.location+added.length, "IEXCL;", "iexcl;"))
							entity = 0x00A1;
						// ldquo	201C
						else if (getTag(dest, added.location, added.location+added.length, "LDQUO;", "ldquo;"))
							entity = 0x201C;
						// lsquo	2018
						else if (getTag(dest, added.location, added.location+added.length, "LSQUO;", "lsquo;"))
							entity = 0x2018;
						// mdash	2014
						else if (getTag(dest, added.location, added.location+added.length, "MDASH;", "mdash;"))
							entity = 0x2014;
						// ndash	2013
						else if (getTag(dest, added.location, added.location+added.length, "NDASH;", "ndash;"))
							entity = 0x2013;
						// pound	00A3
						else if (getTag(dest, added.location, added.location+added.length, "POUND;", "pound;"))
							entity = 0x00A3;
						// rdquo	201D
						else if (getTag(dest, added.location, added.location+added.length, "RDQUO;", "rdquo;"))
							entity = 0x201D;
						// rsquo	2019
						else if (getTag(dest, added.location, added.location+added.length, "RSQUO;", "rsquo;"))
							entity = 0x2019;
						// sbquo	201A
						else if (getTag(dest, added.location, added.location+added.length, "SBQUO;", "sbquo;"))
							entity = 0x201A;
						// tilde	00C3
						else if (getTag(dest, added.location, added.location+added.length, "TILDE;", "tilde;"))
							entity = 0x00C3;
							
						// Blech forgot about these ... Why do people do this ?!?!?!?
						// #8212
						else if (getTag(dest, added.location, added.location+added.length, "#8212;", NULL))
							entity = 0x2014;
						// #8216
						else if (getTag(dest, added.location, added.location+added.length, "#8216;", NULL))
							entity = 0x2018;
						// #8217
						else if (getTag(dest, added.location, added.location+added.length, "#8217;", NULL))
							entity = 0x2019;
						// #8220
						else if (getTag(dest, added.location, added.location+added.length, "#8220;", NULL))
							entity = 0x201C;
						// #8221
						else if (getTag(dest, added.location, added.location+added.length, "#8221;", NULL))
							entity = 0x201D;
					break;

					case 8:
						// curren	00A4
						if (getTag(dest, added.location, added.location+added.length, "CURREN;", "curren;"))
							entity = 0x00A4;
						// eacute	00C9
						else if (getTag(dest, added.location, added.location+added.length, "EACUTE;", "eacute;"))
							entity = 0x00C9;
						// iquest	00BF
						else if (getTag(dest, added.location, added.location+added.length, "IQUEST;", "iquest;"))
							entity = 0x00BF;
						// middot	00B7
						else if (getTag(dest, added.location, added.location+added.length, "MIDDOT;", "middot;"))
							entity = 0x00B7;
					break;
				}
				
				// Pick something better than this ?!?!?
				if (!entity)
					entity = 0x00BF;
					
				[dest replaceCharactersInRange:added withString:[NSString stringWithFormat:@"%C", entity]];
				//[dest replaceCharactersInRange:added withString:[NSString stringWithFormat:@"[len=%d]", added.length]];
			}
			// Reset position and skip this character
			added.length = 1;
			added.location++;
		}
		else
			// must be OK ...
			added.location++;
	}
	
} // addHTMLText


bool isBlank(unichar c) {

	if (c==' '||c=='\t'||c==0x0a||c==0x0d||c=='>')
		return true;
	else
		return false;
		
} // isBlank

// Honor <br and <p and <h#... everything else, well ...
void addHTMLTag(NSString * src, NSRange rtag, NSMutableString * dest) 
{
   	unichar c[4] = {0};
   	
   	// Skip leading blanks
   	while (rtag.length && isBlank([src characterAtIndex:rtag.location]))
   	{
   		rtag.location++;
   		rtag.length--;
   	}
	
	// Get the first few characters in the tag
	if (rtag.length > 0)
		c[0] = [src characterAtIndex:rtag.location];
	if (rtag.length > 1)
		c[1] = [src characterAtIndex:rtag.location+1];
	if (rtag.length > 2)
		c[2] = [src characterAtIndex:rtag.location+2];
	if (rtag.length > 3)
		c[3] = [src characterAtIndex:rtag.location+3];
	
	// Brute force since there are only a few we care about
	
	// Ignore trailing white space
	if (isBlank(c[3]))
		c[3] = 0x00;
	if (isBlank(c[2]))
		c[2] = 0x00;
	if (isBlank(c[1]))
		c[1] = 0x00;
	
	// <P - Begin Paragraph
	if (!c[1] && (c[0]=='p'||c[0]=='P'))
		[dest appendString:@"\n\t"];
		
//	// </P - End Paragraph
//	if (!c[2] && (c[1]=='/')&& (c[1]=='p'||c[1]=='P'))
//		[dest appendString:@"\n"];
		
	// <BR - Line Break
	else if (!c[2] && (c[0]=='b'||c[0]=='B') && (c[1]=='r'||c[1]=='R'))
		[dest appendString:@"\n"];	
	
	// <H# - Begin Heading
	else if (!c[2] && (c[0]=='h'||c[0]=='H') && (c[1] > '0' && c[1] <= '9'))
		[dest appendString:@"\n\n"];

	// </H# - End Heading
	else if (!c[3] && c[0] == '/' && (c[1]=='h'||c[1]=='H') && (c[2] > '0' && c[2] <= '9'))
		[dest appendString:@"\n\n"];
	
} // addHTMLTag


// Quickie thread helper funcs
- (void) threadShowSaving:(NSString*)s {
	[wait setTitle:@"Saving ..."];
	[wait setBodyText:[NSString stringWithFormat:@"Saving %@", s]];
} // threadShowSaving


- (void) threadReleaseWait {
	if (wait)
	{
		//[trApp unlockUIOrientation];
		[wait dismissAnimated:YES];
		[wait release];
		wait = nil;
	}
} // threadReleaseWait


// Strips out HTML tags and produces ugly text for reading enjoyment ...
- (void)stripHTML:(NSMutableString  *)newText; {

	NSMutableString  *src   = newText;
	NSRange 	  	  rtext = {0};
	NSRange 		  rtag  = {0};
	
	
	
	//			//struct CGRect rect = [trApp getOrientedViewRect];
	//
	//			// This could take a while ... warn user
	//			//[trApp lockUIOrientation];
	//			wait = [[UIAlertSheet alloc] initWithFrame:rect];
	//			[wait setTitle:@"Building Text File"];
	//			[wait setBodyText:@"Converting HTML to Text ...\nPlease wait\n"];
	//			[wait setDelegate:self];
	//			//[wait addButtonWithTitle:@"OK"];
	//			[wait popupAlertAnimated:YES];

	
	
    // Look for the start of the body tag - we ignore everything before it
 	rtag.location = getTag(src, 0, 0, "<BODY", "<body");
 	if (rtag.location)
 	{
		// Looks like we are going to do some stripping ... wild guess at final size		
		newText = [[NSMutableString alloc] initWithCapacity:[src length]/2];

		// Ignore everything up to <BODY
		rtext.location = rtag.location;

		while (true)
		{ 	
			// Dump text here !!!
			// rtext.location is the start of the last text
			// rtag.location is the start of the current tag
			rtext.length = rtag.location-rtext.location;

			// Add the text portion to newText		
			addHTMLText(src, rtext, newText);

			// Find end of current tag
			rtag.location++;
			rtag.length = getTag(src, rtag.location, 0, ">", NULL);
			if (!rtag.length)
				break;
			rtag.length -= rtag.location;

			// rtag now has the start/end of the tag

			// Exit if this is the end of the BODY> (start 1 char early to avoid 0 index)
			if (rtag.length > 4 && getTag(src, rtag.location-1, rtag.length+1, "/BODY", "/body"))
				break;

			// Process the tag - we "honor" <br and <p
			addHTMLTag(src, rtag, newText);

			// Save the start of the next block of text
			rtext.location = rtag.location+rtag.length+1;

			// Find start of the next tag
			rtag.location = getTag(src, rtag.location+rtag.length+1, 0, "<", NULL);
			if (!rtag.location)
				break;
		}

		[src release];
	}

	// Get rid of the wait msg
	[self threadReleaseWait];
	//[self performSelectorOnMainThread:@selector(threadShowSaving) 
	//						withObject:nil waitUntilDone:YES];
							
	//[self performSelectorOnMainThread:@selector(threadReleaseWait) 
	//						withObject:nil waitUntilDone:YES];

	// Replace the open text with this new text and refresh the screen
	[self setText:newText];
	//[self performSelectorOnMainThread:@selector(setText) 
	//						withObject:newText waitUntilDone:YES];
	
	// Save the HTML as a text file!
	NSString *fullpath = [[filePath stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:TEXTREADER_CACHE_EXT];
	
	if ([newText writeToFile:fullpath atomically:YES encoding:encoding error:NULL])
	{
		// If we cached it, change the file name so we will reload it automatically
		NSString * tmp = [[fileName stringByAppendingPathExtension:TEXTREADER_CACHE_EXT] copy];
		[fileName release];
		fileName = tmp;
	}
		
	
} // stripHTML


// ---------------------------------------------
// Thread specific code ...
// ---------------------------------------------


// Open specified file and display
- (bool) openFile:(NSString *)name path:(NSString*)path {
	NSMutableString * newText = nil;
    NSError         * error   = nil;

    // Load the text ...
    if (!path)
    	path = TEXTREADER_DEF_PATH;
    	
    if (!name)
    	name = @"";
    else
    {
    	// Build the full path
	    NSString *fullpath = [path stringByAppendingPathComponent:name];
	    TextFileType ftype = [trApp getFileType:fullpath];

		// Read in the requested file ...
		if (ftype == kTextFileTypePDB)
		{
			NSMutableData   * data = nil;
			NSString        * type = nil;
			
			int rc = decodePDB(fullpath, &data, &type);
			if (rc)
			{
				if (data)
					[data release];
				data = nil;

				// Handle invalid format ...				
				if (rc == 2)
				{
					NSString *errorMsg = [NSString stringWithFormat:
												   @"The format of \"%@\" is \"%@\".\n%@ is only able to open Text files and PalmDoc PDB files.\nSorry ...", 
												   fullpath, type, TEXTREADER_NAME];
					CGRect rect = [[UIWindow keyWindow] bounds];
					UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:CGRectMake(0,rect.size.height-240,rect.size.width,240)];
					[alertSheet setTitle:@"Unable to Open PDB File!"];
					[alertSheet setBodyText:errorMsg];
					[alertSheet addButtonWithTitle:@"OK"];
					[alertSheet setDelegate:self];
					[alertSheet popupAlertAnimated:YES];
					
					return false;
				}
			}
			else
			{
				newText = [[NSMutableString alloc] initWithData:data encoding:encoding];
				
				// Double clutch for GB2312
				if (!newText && encoding == gb2312enc)
					newText = convertGB2312Data(data);	
			}
				
			if (data)
				[data release];
				
			// Check the PDB for HTML - look for <HEAD in the first 512 bytes
			if (newText && getTag(newText, 0, 512, "<HEAD", "<head"))
			   ftype = kTextFileTypeHTML;
		}
		else
		{
			// Read in the text file - let NSMutableString do the work
			newText = [[NSMutableString 
						stringWithContentsOfFile:fullpath
						encoding:encoding
						error:&error] retain];
						
			// Double clutch for GB2312
			if (!newText && encoding == gb2312enc)
				newText = loadGB2312(fullpath);
		}
		
		// An empty string probably meant it didn't get loaded properly ...
		if (newText && ![newText length])
		{
			[newText release];
			newText = nil;
		}
		
		// If we have text, save the new file name
		if (newText)
		{		
			if (text && fileName)
				// Save the current position for the book being closed
				[trApp setDefaultStart:fileName start:start];
		
			if (fileName)
				[fileName release];
			fileName = [[name copy] retain];

			if (filePath)
				[filePath release];
			filePath = [[path copy] retain];
				
			start = [trApp getDefaultStart:name];
			end   = 0;		

			// Strip the HTML into UGLY text if needed
			if (ftype == kTextFileTypeHTML || ftype == kTextFileTypeFB2)
			{

//				// This could take a while ... warn user
//				//[trApp lockUIOrientation];
//				struct CGRect rect = [trApp getOrientedViewRect];
//				wait = [[UIAlertSheet alloc] initWithFrame:rect];
//				[wait setTitle:@"Building Text File"];
//				[wait setBodyText:@"Converting HTML to Text ...\nPlease wait\n"];
//				[wait setDelegate:self];
//				//[wait addButtonWithTitle:@"OK"];
//				[wait popupAlertAnimated:YES];
//
				//[self setText:@"This is a test"];
				[self stripHTML:newText];			
				
				//[NSTimer scheduledTimerWithTimeInterval:0.0f target:self selector:@selector(stripHTML:) userInfo:newText repeats:NO];
				
				// Start the load thread
				//[NSThread detachNewThreadSelector:@selector(stripHTML:)
				//						 toTarget:self
				//					   withObject:newText];

				// All done - file will be reopened when stripHTML finishes
				return true;
			}

			// Save the new text for view
			[self setText:newText];

			return true;
		}
	}

	NSString *errorMsg = [NSString stringWithFormat:
	                               @"Unable to open file \"%@\" in directory \"%@\".\nPlease make sure the directory and file exist, the read permissions for are set, and the file is really in %@ encoding.", 
	                               name, path, [NSString localizedNameOfStringEncoding:encoding]];
	CGRect rect = [[UIWindow keyWindow] bounds];
	UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:CGRectMake(0,rect.size.height-240,rect.size.width,240)];
	[alertSheet setTitle:@"Error opening file"];
	[alertSheet setBodyText:errorMsg];
	[alertSheet addButtonWithTitle:@"OK"];
	[alertSheet setDelegate:self];
	[alertSheet popupAlertAnimated:YES];

	return false;
	
} // openFile


// This view's alert sheets are just informational ...
// Dismiss them without doing anything special
- (void)alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button 
{
  [sheet dismissAnimated:YES];
  [sheet release];
} // alertSheet


- (NSString *)getFont {
	return font;
} // getFont


- (NSStringEncoding)getEncoding {
	return encoding;
} // getEncoding


- (bool)setEncoding:(NSStringEncoding)enc {
	
	if (!enc)
		enc = kCGEncodingMacRoman;
		
	encoding = enc;
	
// JIMB BUG BUG reopen the book!!!!???!!!

	[self setNeedsDisplay];
	
	return true;
} // setEncoding


// typedef enum {
//     kGSFontTraitNone = 0,
//     kGSFontTraitItalic = 1,
//     kGSFontTraitBold = 2,
//     kGSFontTraitBoldItalic = (kGSFontTraitBold | kGSFontTraitItalic)
// } GSFontTrait;


- (bool)setFont:(NSString*)newFont size:(int)size {

	struct __GSFont * newgsFont;
	
	if (!newFont || [newFont length] < 1)
		newFont = @"arialuni";
	if (size < 8)
		size = 8;
	if (size > 32)
		size = 32;
	
 	newgsFont = GSFontCreateWithName([newFont cStringUsingEncoding:kCGEncodingMacRoman], 0, size);
	if (newgsFont)
	{
		font = [newFont copy];
		fontSize = size;
		gsFont = newgsFont;
		
		[self setNeedsDisplay];
		
		return true;
	}
	
	CGRect rect = [[UIWindow keyWindow] bounds];
	UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:CGRectMake(0,rect.size.height-240,rect.size.width,240)];
	[alertSheet setTitle:@"Error"];
	[alertSheet setBodyText:[NSString stringWithFormat:@"Unable to create font %@", font]];
	[alertSheet addButtonWithTitle:@"OK"];
	[alertSheet setDelegate:self];
	[alertSheet popupAlertAnimated:YES];

	return false;
	
} // setFont


- (int)getFontSize {
	return fontSize;
} // getFontSize


@end // @implementation MyTextView

