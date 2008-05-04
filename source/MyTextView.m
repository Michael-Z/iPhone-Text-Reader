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
	gsFont   = nil;
	font     = TEXTREADER_DFLT_FONT;
	fontSize = TEXTREADER_DFLT_FONTSIZE;
	
	encoding = TEXTREADER_DFLT_ENCODING;
	
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
		if (current+1 < [text length])
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

   int lineHeight = fontSize * 1.25; // Blech!!! Figure this properly!!!
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
				used = [x drawAtPoint:currentPt withFont:gsFont];

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



// Prototype for the PDB decode function
int decodeToString(NSString * src, NSMutableData ** dest, NSString ** type);



// Open specified file and display
- (bool) openFile:(NSString *)name path:(NSString*)path start:(int)startChar {
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

		// Read in the requested file ...
		if ([trApp getFileType:fullpath] == kTextFileTypePDB)
		{
			NSMutableData   * data = nil;
			NSString        * type = nil;
			
			int rc = decodeToString(fullpath, &data, &type);
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
				newText = [[NSMutableString alloc] initWithData:data encoding:encoding];
				
			if (data)
				[data release];
		}
		else
		{
			// Read in the text file - let NSMutableString do the work
			newText = [[NSMutableString 
						stringWithContentsOfFile:fullpath
						encoding:encoding
						error:&error] retain];			
		}
		
		// An empty string probably meant it didn't get loaded properly ...
		if (newText && ![newText length])
		{
			[newText release];
			newText = nil;
		}

		// Set up the new document
		if (newText)
		{
			// Get the new text ...
			if (text)
			{
				// Save the current position for the book being closed
				[trApp setDefaultStart:fileName start:start];
				[text release];
			}
			text = newText;
			
			if (fileName)
				[fileName release];
			fileName = [[name copy] retain];

			if (filePath)
				[filePath release];
			filePath = [[path copy] retain];
				
			start = [trApp getDefaultStart:name];
			end   = 0;
			[self setNeedsDisplay];

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

