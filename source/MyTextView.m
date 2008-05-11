
//
//   textReader.app -  kludged up by Jim Beesley
//   This incorporates inspiration, code, and examples from (among others)
//	 * The iPhone Dev Team for toolchain and more!
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
	// pageUp = false;
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

// Deleted by Allen Li
/*
// Last page movement was a page up?
- (void) pageUp {
	pageUp = true;

	// Force a screen update ...
	[self setNeedsDisplay];
} // pageUp
*/

//Modified by Allen Li
- (void) pageUp {
	CGSize viewSize = [trApp getOrientedViewSize];

	// Get font metrics instead of this kludge!!!
	// No idea how to get info from a GSFont tho ...

   int lineHeight = fontSize * 1.25+1; // Blech!!! Figure this properly!!!
   int lines      = viewSize.height / lineHeight;
   
   [self moveUp:lines];
}


// Last page movement was a page down?
- (void) pageDown {
	// pageUp = false;
	
	// Reset start pos
	[self setStart:[self getEnd]];
} // pageDown


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

/* Deleted by Allen Li
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
*/


//Modified by Allen Li
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
   dir =  kDirectionForward;

   // Blank the top "pad" portion of the screen
   lineRect = CGRectMake(0, 0, width, vpad);
   [self fillBkgGroundRect:context rect:lineRect];

	   struct CGPoint lastBlankPoint;
   int            lastBlankIndex;
   int            afterCrLf = false;
   
   current = start;

// JIMB BUG BUG - optimize this!  Only draw lines that are in the visible rect!
// (Too much trouble for now, plus it seems fast enough as is ...)
  for (line = 0; line < lines; line++) 
  {
	bool           emptyLine = true;

	// Remember the start position of each line
	lineStart[line] = current;
	
	// Keep track of the last blank in this line 
	lastBlankIndex = -1;

// JIMB BUG BUG - clean up the rect calculations  	
// We really want this to cover the writing for this line (with descenders), but 
// not take out the descenders from the line above.
	// Update lineRect - it can get munged when we blank the end of the line
	lineRect = CGRectMake(0, vpad + line * lineHeight, width, lineHeight);

	[self fillBkgGroundRect:context rect:lineRect];

	currentPt = CGPointMake(hpad, vpad + line * lineHeight);

	while  (current < [text length])
	{
		struct CGPoint beginPoint = currentPt;
		unichar c = [self currentChar:current direction:dir];

		// Move backwards or forwards as needed
		current = current+1;

		// Find the next character
		unichar nextc = [self currentChar:current direction:dir];
		
		// Special case for Windows CRLF x0d0a- only use one
		if (c == 0x0d && nextc == 0x0a)
		{
			current++;
			nextc = [self currentChar:current direction:dir];
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

		// Draw the text - 1 below the current pt to avoid artifacts
		used = [x drawAtPoint:CGPointMake(currentPt.x,currentPt.y+1) withFont:gsFont];

		// Update the current position at the end of the text we drew
		currentPt.x += used.width;
	
		struct CGPoint endPoint = currentPt;
		if (endPoint.x > (width-hpad))
		{
			// Can we back up to a blank?
			if (lastBlankIndex > 0)
			{
				// plus one skips this space
				current    =  lastBlankIndex+1; 
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
			current =  current-1;
			break;
		}

	} // while space on this line

  } // for each line
	     
   // Blank any remaining space at the bottom of the screen
   lineRect = CGRectMake(0, vpad + line * lineHeight, width, lineHeight);
   [self fillBkgGroundRect:context rect:lineRect];

   // Remember the last text we display
   end = current;

  // Remember the next virtual line
  lineStart[lines] = current+1;

   // Reset pageup flag - one way or the other it is done now ...
   // pageUp = false;

   [screenLock unlock];
  
   return [super drawRect:rect];
  
} // drawRect


//Added by Allen Li -- Handle moving up
-(void) moveUp:(int)moveLines
{
	// These are used below to blank bkgrnd and draw text
	CGSize          used;
	NSString      * x;
    struct CGRect   lineRect;
	
	CGPoint currentPt = CGPointMake(0,0);
	CGSize viewSize = [trApp getOrientedViewSize];

	// Get font metrics instead of this kludge!!!
	// No idea how to get info from a GSFont tho ...

   int lineHeight = fontSize * 1.25+1; // Blech!!! Figure this properly!!!
   int lines      = viewSize.height / lineHeight;
   int width      = viewSize.width;
   int hpad       = padMargins ? 10 : 0;
   int vpad       = (viewSize.height - lineHeight*lines) / 2;
   int line, current;
   Direction dir;

	if( (moveLines <= 0) || (moveLines >lines))
		return;
	
   // Handle pageup by looping twice
   dir = kDirectionBackward;

   // Blank the top "pad" portion of the screen
   lineRect = CGRectMake(0, 0, width, vpad);

  	   struct CGPoint lastBlankPoint;
	   int            lastBlankIndex;
	   int            afterCrLf = false;
	   
	   current = lineStart[0]-1;


	//Cut the line from: (lines - moveLines) to lines-1, so the end is lineStart[lines-moveLines]-1;
	//Keep the lines from 0 to (moveLines-1), just move it down to the bottom: (lines-moveLines) to (lines-1);
	  for (line = moveLines-1; line >=0; line--) 
	  {
		bool       emptyLine   = true;
		int		   timesOfCRLF = 0;
		
		// Keep track of the last blank in this line 
		lastBlankIndex = -1;

// JIMB BUG BUG - clean up the rect calculations  	
// We really want this to cover the writing for this line (with descenders), but 
// not take out the descenders from the line above.
		// Update lineRect - it can get munged when we blank the end of the line
		lineRect = CGRectMake(0, vpad + line * lineHeight, width, lineHeight);
		currentPt = CGPointMake(hpad, vpad + line * lineHeight);

		while  ( current >= 0)
		{
			unichar c = [self currentChar:current direction:dir];

			// Move backwards
			current = MAX(0,current-1);

			// Find the next character
			unichar nextc = [self currentChar:current direction:dir];
			
			// Special case for Windows CRLF x0d0a- only use one
			if (c == 0x0a && nextc == 0x0d)
			{
				current--;
				nextc = [self currentChar:current direction:dir];
			}

/*
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
*/

			// Special case for white space chars
			if (c == '\n' || c == 0x0d || c == 0x0a)
			{
				timesOfCRLF++;
				if(timesOfCRLF ==1)
				{
					afterCrLf = true;
					continue;
				}
				else if(timesOfCRLF == 2)
				{
					if ( c =='\n' )
					{
						current++;
					}
					else
					{
						current=current+2;
					}
					break;
				}
			}

			// Eat leading blanks on a new line, unless they follow a CR/LF
			if (c == ' ' && emptyLine && (timesOfCRLF == 0))
			{
				//Something wrong here
			  	continue;
			}

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

			// Get the substring we want to draw ...
			// special case a tab as 4 blanks (should we do "real" tab stops?!?!?)
			if (c == '\t')
				x = @"   ";
			else
				x = [NSString stringWithCharacters:&c length:1];

			// Draw the text, or just get bounding box if we are looping ...
			used = [x sizeWithFont:gsFont];

			// Update the current position at the end of the text we drew
			currentPt.x += used.width;
		
			if (currentPt.x > (width-hpad))
			{
				// Can we back up to a blank?
				if (lastBlankIndex > 0)
				{
					// plus one skips this space
					current    = MAX(0,lastBlankIndex-1) ; 
				}
				else
				{
// JIMB BUG BUG - add a trailing '-' when we are forced to break a word?!?!
// This is tricy to calculate - we probably ought to calc the size needed above
// and save it so we know how far to back up - it might be several characters,
// but I suspect 1 character plus whatever partial char put us past the edge will
// probably be enough.  Two plus partial ought to always be sufficient ...
				}

				
				// Save the new current position 
				// (i.e. before the one that put us past the edge)
				current = MAX(0,current+1);
				break;
				
			}

		} // while space on this line

	  } // for each line
	
// KLUDGE - handle first few characters
if (current < 32)
	current = -1;

	// Set this as our new start position
	[self setStart:MAX(0,current+1)];
}


//Added by Allen Li
-(void) moveDown:(int)moveLines
{
	CGSize viewSize = [trApp getOrientedViewSize];

	// Get font metrics instead of this kludge!!!
	// No idea how to get info from a GSFont tho ...

   int lineHeight = fontSize * 1.25+1; // Blech!!! Figure this properly!!!
   int lines      = viewSize.height / lineHeight;

   if ((moveLines <= 0) || (moveLines > lines))
   	return;

   [self setStart:lineStart[moveLines]];
}


//Added by Allen Li
-(void) dragText:(int)offset
{
	// Get font metrics instead of this kludge!!!
	// No idea how to get info from a GSFont tho ...

   int lineHeight = fontSize * 1.25+1; // Blech!!! Figure this properly!!!

	if(offset > 0)
	{
		[self moveUp:(offset/lineHeight)];
	}
	else
	{
		offset = -offset;
		[self moveDown:(offset/lineHeight)];
	}
}


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
	

// findChar
// Returns offset of char or 0 if not found
NSUInteger getTag(NSString * str, NSUInteger start, NSUInteger end, char * upTag, char * lowTag)
{
	NSUInteger i, j;

	// 0 means search to the end	
	if (!end)
		end = [str length];

	// search to the end ...
	// (but change length since it has to fit)
	while (true)
	{
		// Look for first character
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
			    if (i+j >= end)
			    	return 0;
				unichar c = [str characterAtIndex:i+j];
				if (c!=upTag[j] && c!=lowTag[j])
					break;
			}
		}
		else
		{
			for (j = 1; upTag[j]; j++)
			{
			    if (i+j >= end)
			    	return 0;
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

	NSRange addedBlanks = {[dest length], 1};
	NSRange added       = {[dest length], 1};
	
	// Add new text to the dest - we'll patch it up in place
	[dest appendString:[src substringWithRange:rtext]];
	
	// Convert /n to blank
	// Convert all consecutive blanks to a single blank
	while (addedBlanks.location < [dest length])
	{
		unichar c = [dest characterAtIndex:addedBlanks.location];
		if (c==0x0a || c==0x0d || c == '\t' || c == ' ')
		{
			// If previous character is blankspace, delete this character
			// We only add a single blank at a time
			c = [dest characterAtIndex:addedBlanks.location-1];
			if (c==0x0a || c==0x0d || c == '\t' || c == ' ')
				// delete this chacater
				[dest deleteCharactersInRange:addedBlanks];
			else
				addedBlanks.location++;
		}
		else
			addedBlanks.location++;
    }

	// Expand all character entities
	while (added.location < [dest length])
	{
		unichar c = [dest characterAtIndex:added.location];
		if (c=='&')
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
 						switch([dest characterAtIndex:added.location+1])
 						{
 							case 'G': case 'g':
								// gt		003E
								if (getTag(dest, added.location, added.location+added.length, "GT;", "gt;"))
									entity = '>';
								break;
								
 							case 'L': case 'l':
								// lt		003C
								if (getTag(dest, added.location, added.location+added.length, "LT;", "lt;"))
									entity = '<';
								break;

 							case '#':
								// #34 == "
								if (getTag(dest, added.location, added.location+added.length, "#34;", NULL))
									entity = '"';
								break;
 						}
 					break;
 
 					case 5:
 						switch([dest characterAtIndex:added.location+1])
 						{
 							case 'A': case 'a':
								// amp		0026
								if (getTag(dest, added.location, added.location+added.length, "AMP;", "amp;"))
									entity = '&';
								break;
								
 							case 'R': case 'r':
								// reg    	00AE
								if (getTag(dest, added.location, added.location+added.length, "REG;", "reg;"))
									entity = 0x00AE;
								break;
								
 							case 'U': case 'u':
								// uml		00A8
								if (getTag(dest, added.location, added.location+added.length, "UML;", "uml;"))
									entity = 0x00A8;
								break;
								
 							case 'Y': case 'y':
								// yen		00A5
								if (getTag(dest, added.location, added.location+added.length, "YEN;", "yen;"))
									entity = 0x00A5;
								break;
						}
 					break;
 
 					case 6:
 						switch([dest characterAtIndex:added.location+1])
 						{
 							case 'C': case 'c':
								// copy	  	00A9 
								if (getTag(dest, added.location, added.location+added.length, "COPY;", "copy;"))
									entity = 0x00A9;
								// cent		00A2	
								else if (getTag(dest, added.location, added.location+added.length, "CENT;", "cent;"))
									entity = 0x00A2;
								break;
								
 							case 'E': case 'e':
								// emsp		2003
								if (getTag(dest, added.location, added.location+added.length, "EMSP;", "emsp;"))
									entity = ' '; // entity = 0x2003;
								// ensp		2002
								else if (getTag(dest, added.location, added.location+added.length, "ENSP;", "ensp;"))
									entity = ' '; //entity = 0x2002;
								// euro		20ac
								else if (getTag(dest, added.location, added.location+added.length, "EURO;", "euro;"))
									entity = 0x20AC;
								break;
								
 							case 'N': case 'n':
								// nbsp   	00A0
								if (getTag(dest, added.location, added.location+added.length, "NBSP;", "nbsp;"))
									entity = ' '; //entity = 0x00A0;
								break;
								
 							case 'Q': case 'q':
								// quot		0022	
								if (getTag(dest, added.location, added.location+added.length, "QUOT;", "quot;"))
									entity = '"'; //entity = 0x0022;
								break;
						}
 					break;
 
 					case 7:
 						switch([dest characterAtIndex:added.location+1])
 						{
 							case 'A': case 'a':
								// acute	00B4
								if (getTag(dest, added.location, added.location+added.length, "ACUTE;", "acute;"))
									entity = '\''; //entity = 0x00B4;
								break;
								
 							case 'B': case 'b':
								// bdquo	201E
								if (getTag(dest, added.location, added.location+added.length, "BDQUO;", "bdquo;"))
									entity = 0x201E;
								break;
								
 							case 'I': case 'i':
								// iexcl    00A1
								if (getTag(dest, added.location, added.location+added.length, "IEXCL;", "iexcl;"))
									entity = 0x00A1;
								break;
								
 							case 'L': case 'l':
								// ldquo	201C
								if (getTag(dest, added.location, added.location+added.length, "LDQUO;", "ldquo;"))
									entity = '"'; //entity = 0x201C;
								// lsquo	2018
								else if (getTag(dest, added.location, added.location+added.length, "LSQUO;", "lsquo;"))
									entity = '\''; //entity = 0x2018;
								break;
								
 							case 'M': case 'm':
								// mdash	2014
								if (getTag(dest, added.location, added.location+added.length, "MDASH;", "mdash;"))
									entity = '-'; //entity = 0x2014;
								break;
								
 							case 'N': case 'n':
								// ndash	2013
								if (getTag(dest, added.location, added.location+added.length, "NDASH;", "ndash;"))
									entity = '-'; //entity = 0x2013;
								break;
								
 							case 'P': case 'p':
								// pound	00A3
								if (getTag(dest, added.location, added.location+added.length, "POUND;", "pound;"))
									entity = '#'; //entity = 0x00A3;
								break;
								
 							case 'R': case 'r':
								// rdquo	201D
								if (getTag(dest, added.location, added.location+added.length, "RDQUO;", "rdquo;"))
									entity = '"'; //entity = 0x201D;
								// rsquo	2019
								else if (getTag(dest, added.location, added.location+added.length, "RSQUO;", "rsquo;"))
									entity = '\''; //entity = 0x2019;
								break;
								
 							case 'S': case 's':
								// sbquo	201A
								if (getTag(dest, added.location, added.location+added.length, "SBQUO;", "sbquo;"))
									entity = 0x201A;
								break;
								
 							case 'T': case 't':
								// tilde	00C3
								if (getTag(dest, added.location, added.location+added.length, "TILDE;", "tilde;"))
									entity = '~'; //entity = 0x00C3;
								break;
								
 							case '#':
 								if ([dest characterAtIndex:added.location+2] != '8' || 
 								    [dest characterAtIndex:added.location+3] != '2')
 									break;
 									
								// Blech forgot about these ... Why do people do this ?!?!?!?
								// #8212
								if (getTag(dest, added.location, added.location+added.length, "#8212;", NULL))
									entity = '"'; //entity = 0x2014;
								// #8216
								else if (getTag(dest, added.location, added.location+added.length, "#8216;", NULL))
									entity = '\''; //entity = 0x2018;
								// #8217
								else if (getTag(dest, added.location, added.location+added.length, "#8217;", NULL))
									entity = '\''; //entity = 0x2019;
								// #8220
								else if (getTag(dest, added.location, added.location+added.length, "#8220;", NULL))
									entity = '"'; //entity = 0x201C;
								// #8221
								else if (getTag(dest, added.location, added.location+added.length, "#8221;", NULL))
									entity = '"'; //entity = 0x201D;
								break;
						}
 					break;
 
 					case 8:
 						switch([dest characterAtIndex:added.location+1])
 						{
 							case 'C': case 'c':
								// curren	00A4
								if (getTag(dest, added.location, added.location+added.length, "CURREN;", "curren;"))
									entity = 0x00A4;
								break;
								
 							case 'E': case 'e':
								// eacute	00C9
								if (getTag(dest, added.location, added.location+added.length, "EACUTE;", "eacute;"))
									entity = 0x00C9;
								break;
								
 							case 'I': case 'i':
								// iquest	00BF
								if (getTag(dest, added.location, added.location+added.length, "IQUEST;", "iquest;"))
									entity = 0x00BF;
								break;
								
 							case 'M': case 'm':
								// middot	00B7
								if (getTag(dest, added.location, added.location+added.length, "MIDDOT;", "middot;"))
									entity = 0x00B7;
								break;
						}
 					break;
 				}
 				
 				// Pick something better than this ?!?!?
 				if (!entity)
 					entity = '?';
 					
 				[dest replaceCharactersInRange:added withString:[NSString stringWithFormat:@"%C", entity]];
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


// Honor some tags - ignore most others ...
// KLUDGE!!! - move this stuff to it's own class!!!
static bool openParagraph = false;
void addHTMLTag(NSString * src, NSRange rtag, NSMutableString * dest) 
{
	// NOTE: Search always starts one early to make sure we get a non0 index 
	// This means we also need to make length +1 to find tag
	
	// Ignore NULL tags
	if (!rtag.length)
		return;
		   	
	unichar c = [src characterAtIndex:rtag.location];

	switch (c)
	{
 		case 'B': case 'b':
 			// <br
 			if (getTag(src, rtag.location, 2+rtag.location+1, "R>", "r>") ||
 				getTag(src, rtag.location, 2+rtag.location+1, "R ", "r "))
 				[dest appendString:@"\n"];	
 				
 			// <book-title - treat like H1
 			else if (getTag(src, rtag.location, 10+rtag.location+1, "OOK-TITLE>", "ook-title>") ||
 			         getTag(src, rtag.location, 10+rtag.location+1, "OOK-TITLE ", "ook-title "))
 				[dest appendString:@"\n\n\n"];	
 			break;
 
//  		case 'D': case 'd':
//  			// <div
//  			if (getTag(src, rtag.location, 3+rtag.location+1, "IV>", "iv>") ||
//  				getTag(src, rtag.location, 3+rtag.location+1, "IV ", "iv "))
//  				[dest appendString:@"\n"];
//  			break;

 		case 'H': case 'h':
 			// <H1
 			if (getTag(src, rtag.location, 2+rtag.location+1, "1>", "1 "))
 				[dest appendString:@"\n\n\n"];	
 			
 			// <H2 to <H6
 			else if (getTag(src, rtag.location, 2+rtag.location+1, "2>", "2 ") ||
  					 getTag(src, rtag.location, 2+rtag.location+1, "3>", "3 ") ||
 				 	 getTag(src, rtag.location, 2+rtag.location+1, "4>", "4 ") ||
 					 getTag(src, rtag.location, 2+rtag.location+1, "5>", "5 ") ||
 					 getTag(src, rtag.location, 2+rtag.location+1, "6>", "6 "))
 				[dest appendString:@"\n\n"];
 			break;

 		case 'P': case 'p':
 			// <p
 			if (getTag(src, rtag.location, 1+rtag.location+1, ">", ">") ||
 				getTag(src, rtag.location, 1+rtag.location+1, " ", " "))
 			{
 				// MOBI books often have double open paragraphs ...
 				// Ignore extras that are not closed
 				if (!openParagraph)
 				{
 					[dest appendString:@"\n"];
 					openParagraph = true;
 				}
 			}
 			break;

		case 'S': case 's':
 			// <section - treat like H2
 			if (getTag(src, rtag.location, 7+rtag.location+1, "ECTION>", "ection>") ||
 				getTag(src, rtag.location, 7+rtag.location+1, "ECTION ", "ection "))
 				[dest appendString:@"\n\n"];
 
 			// <subtitle - treat like H3
 			else if (getTag(src, rtag.location, 8+rtag.location+1, "UBTITLE>", "ubtitle>") ||
 				     getTag(src, rtag.location, 8+rtag.location+1, "UBTITLE ", "ubtitle "))
 				[dest appendString:@"\n\n"];
 			break;
 			
 		case 'T': case 't':
 			// <title - same as <H2
 			if (getTag(src, rtag.location, 5+rtag.location+1, "ITLE>", "itle>") ||
 				getTag(src, rtag.location, 5+rtag.location+1, "ITLE ", "itle "))
 				[dest appendString:@"\n\n"];
 			break;
			
		case '/':
			if (rtag.length < 2)
				return;
			c = [src characterAtIndex:rtag.location+1];
			switch (c)
			{
 				case 'B': case 'b':
 					// </book-title - treat like H1
 					if (getTag(src, rtag.location+1, 10+rtag.location+1, "OOK-TITLE>", "ook-title>") ||
 						getTag(src, rtag.location+1, 10+rtag.location+1, "OOK-TITLE ", "ook-title "))
 						[dest appendString:@"\n\n\n"];	
 					break;
 
//  				case 'D': case 'd':
//  					// </div
//  					if (getTag(src, rtag.location+1, 4+rtag.location+1, "DIV>", "div>") ||
//  						getTag(src, rtag.location+1, 4+rtag.location+1, "DIV ", "div "))
//  						[dest appendString:@"\n"];
//  					break;
 
 				case 'H': case 'h':
 					// <H1
 					if (getTag(src, rtag.location+1, 2+rtag.location+1, "1>", "1 "))
 						[dest appendString:@"\n\n\n"];	
 					break;
 
 					// </H2 to </H6
 					if (getTag(src, rtag.location+1, 2+rtag.location+1, "2>", "2 ") ||
 						getTag(src, rtag.location+1, 2+rtag.location+1, "3>", "3 ") ||
 						getTag(src, rtag.location+1, 2+rtag.location+1, "4>", "4 ") ||
 						getTag(src, rtag.location+1, 2+rtag.location+1, "5>", "5 ") ||
 						getTag(src, rtag.location+1, 2+rtag.location+1, "6>", "6 "))
 						[dest appendString:@"\n\n"];	
 					break;
 
 				case 'P': case 'p':
 					// </p
 					if (getTag(src, rtag.location+1, 2+rtag.location+1, "P>", "p>") ||
 						getTag(src, rtag.location+1, 2+rtag.location+1, "P ", "p "))
 					{
 						[dest appendString:@"\n"];
 						openParagraph = false;
 					}
 					break;
 
 				case 'S': case 's':
 					// </section - treat like /H2
 					if (getTag(src, rtag.location+1, 7+rtag.location+1, "ECTION>", "ection>") ||
 						getTag(src, rtag.location+1, 7+rtag.location+1, "ECTION ", "ection "))
 						[dest appendString:@"\n\n"];
 
 					// </subtitle - treat like /H3
 					else if (getTag(src, rtag.location+1, 8+rtag.location+1, "UBTITLE>", "ubtitle>") ||
 							 getTag(src, rtag.location+1, 8+rtag.location+1, "UBTITLE ", "ubtitle "))
 						[dest appendString:@"\n\n"];
 					break;						
 
 				case 'T': case 't':
 					// </title - same as </H2
 					if (getTag(src, rtag.location+1, 5+rtag.location+1, "ITLE>", "itle>") ||
 						getTag(src, rtag.location+1, 5+rtag.location+1, "ITLE ", "itle "))
 						[dest appendString:@"\n\n"];	
 					break;
 
				// default: // debug only
				// 	[dest appendString:@"[[["];
				// 	[dest appendString:[src substringWithRange:rtag]];
				// 	[dest appendString:@"]]]"];
				// 	break;
			}
			break;

		// default: // debug only
		// 	[dest appendString:@"[[["];
		// 	[dest appendString:[src substringWithRange:rtag]];
		// 	[dest appendString:@"]]]"];
		// 	break;
				
	} // switch on first char of tag
	
} // addHTMLTag



// KLUDGE - fix this !!!!

// Strips out HTML tags and produces ugly text for reading enjoyment ...
- (void) stripHTML:(NSMutableString  *)newText type:(TextFileType)ftype {

	NSMutableString  *src   = newText;
	NSRange 	  	  rtext = {0};
	NSRange 		  rtag  = {0};
	
	if (!newText || ![newText length])
		return;
	
	// KLUDGE - put HTML stuff in it's own class !!!!
	openParagraph = false;

	// Special case a check for the document starting with <BODY
	// The check below wouldn't find it because the offset would be 0
	
    // Look for the start of the body tag - we ignore everything before it
 	rtag.location = getTag(src, 0, 0, "<BODY", "<body");
 	
 	// Always strip .html and .fb2 files (people like to produce HTML w/o a <body>
 	// We only want to strip PDBs if they have a body
 	if (rtag.location || ftype == kTextFileTypeHTML || ftype == kTextFileTypeFB2)
 	{
		// Looks like we are going to do some stripping ... wild guess at final size		
		newText = [[NSMutableString alloc] initWithCapacity:[src length]/2];
		[newText appendString:@"\n"];

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

			// Process the tag - we "honor" some, ignore most
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

	// Replace the open text with this new text and refresh the screen
	[self setText:newText];
	
	// Save the HTML as a text file!
	// This keeps us from having to go through this again
	// NOTE: Some times, directory permissions will make this impossible
	//       Don't pop a dialog since that will annoy people even more
	NSString *fullpath = [[filePath stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:TEXTREADER_CACHE_EXT];
	
	if ([newText writeToFile:fullpath atomically:NO encoding:encoding error:NULL])
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
				
			// Check the PDB for HTML - We'll consider anything with 
			// a < and a > in the first 128 characters an HTML doc
			if ( newText && 
				 ([newText characterAtIndex:0] == '<' ||
			      (getTag(newText, 0, 256, "<", NULL) && 
			       getTag(newText, 0, 256, ">", NULL))) )
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
				[self stripHTML:newText type:ftype];			
				
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

//Added by Allen Li
- (int) getFontHeight{
	return fontSize * 1.25+1;
}


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

