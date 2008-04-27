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

// JIMB BUG BUG - read from preferences	
	color    = 0;
	font     = TEXTREADER_DFLT_FONT;
	fontSize = TEXTREADER_DFLT_FONTSIZE;
	
	start = end = 0;
	trApp = nil;
	pageUp = false;
	fileName = nil;
	
	// Make sure text directory exists
	BOOL dir = true;
	if (![[NSFileManager defaultManager] fileExistsAtPath:TEXTREADER_PATH isDirectory:&dir])
		[[NSFileManager defaultManager] createDirectoryAtPath:TEXTREADER_PATH attributes:nil];
	
    return [super initWithFrame:rect];
} // initWithFrame


// JIMB BUG BUG - Add get/set methods for font, size, encoding, etc.

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

- (int) getColor { return color; }
- (bool) getIgnoreNewLine { return ignoreNewLine; }
- (NSMutableString *) getText  { return text; }
- (int) getStart { return start; }
- (int) getEnd   { return end; }
- (NSString*) getFileName { return fileName; }

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


- (char) currentChar:(int)current loops:(int)loops{
	char nextc = 0x00;			
	if (loops)
	{
		if (current >= 0)
			nextc = [text characterAtIndex:current];
	}
	else
	{
		if (current+1 < [text length])
			nextc = [text characterAtIndex:current];
	}
	return nextc;
} // currentChar


- (void)drawRect:(struct CGRect)rect
{
	// If no text, nothing to do ...
	if (!text || !trApp)
	   return [super drawRect:rect];

	[screenLock lock];
	
	CGSize viewSize = [trApp getOrientedViewSize];

  	CGContextRef context = UICurrentContext();

  	CGContextSelectFont(context, 
	  				    [font cStringUsingEncoding:kCGEncodingMacRoman], 
	 				    fontSize,
	 				    kCGEncodingMacRoman);

   CGAffineTransform myTextTransform;

   // Flip text, for some reason its written upside down by default
   myTextTransform = CGAffineTransformMake(1, 0, 0, -1, 0, viewSize.height/30);
   CGContextSetTextMatrix(context, myTextTransform);

   int lineHeight = fontSize * 1.2; // Blech!!! Figure this properly!!!
   int lines      = viewSize.height / lineHeight;
   int width      = viewSize.width;
   int line, loops, current;
  
   // Handle pageup by looping twice
   loops = pageUp ? 2 : 1;

   // First loop is invisible going backwards figuring a new start for pageUp
   // Second loop writes text
   while (loops--)	
   {
  	   struct CGPoint lastBlankPoint;
	   int            lastBlankIndex;
	   int afterCrLf  = false;
	   
	   current = loops ? MAX(0,start-1) : start;

   	   // First loop is just for calculating, so don't draw the text
	   CGContextSetTextDrawingMode(context, loops ? kCGTextInvisible : kCGTextFill);
	   
	  // Blank the first line so we can get creative on avoiding cutting off
	  // descenders ... 
	  struct CGRect lineRect = CGRectMake(0, 0, width, lineHeight);
	  
	  if (!loops)
	  	 [self fillBkgGroundRect:context rect:lineRect];

// JIMB BUG BUG - change the code to allow drawing a single line at a time
// (in either direction - we just need to set a member var and use it to control
// the line along with the 2pass loops code below to calculate the new start position
// This will allow us to change this to a UIScroller and allow us to get the fancy scrolling
// in addition to the current stuff

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
		lineRect = CGRectMake(0, line * lineHeight, width, lineHeight);

		// Fudge this a bit to preserve descenders written above this line
  	    if (!loops)
			[self fillBkgGroundRect:context 
				  rect:CGRectMake(lineRect.origin.x, lineRect.origin.y + fontSize, 
								  lineRect.size.width, lineRect.size.height)];

		CGContextSetTextPosition(context, 0, (line + 1) * lineHeight);

		while  ( (loops && (current > 0)) || 
		         (!loops && (current < [text length])))
		{
			struct CGPoint beginPoint = CGContextGetTextPosition(context);
			char c = [self currentChar:current loops:loops];

			// Move backwards or forwards as needed
			current = loops ? MAX(0,current-1) : current+1;

			// Find the next character
			char nextc = [self currentChar:current loops:loops];
			
			// Special case for Windows CRLF x0d0a- only use one
			if (loops)
			{
				if (c == 0x0a && nextc == 0x0d)
				{
					current--;
					nextc = [self currentChar:current loops:loops];
				}
			}
			else
			{
				if (c == 0x0d && nextc == 0x0a)
				{
					current++;
					nextc = [self currentChar:current loops:loops];
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
			if (c == ' ' || c == '\t' /* || c == '-' */)
			{
				lastBlankIndex = current; // this is actually 1 past ...
				lastBlankPoint = CGContextGetTextPosition(context);
			}

			// At this point, we are going to try to write something ...
			emptyLine = false;
			afterCrLf = false;

			if (c == '\t')		
				CGContextShowText(context, "    ", 4);	
			else if (c)
				CGContextShowText(context, &c, 1);
			
			struct CGPoint endPoint = CGContextGetTextPosition(context);
			if (endPoint.x > width)
			{
				// Can we back up to a blank?
				if (lastBlankIndex > 0)
				{
					// plus one skips this space
					current    = loops ? MAX(0,lastBlankIndex-1) : lastBlankIndex+1; 
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

				// Extend lineRect down to make sure we clean up any descenders
				lineRect.size.height += fontSize;

// JIMB BUG BUG - use font metrics to figure this out properly
// - then we can clean up the lineRect definition and use the same 
// y-origin and height throughout this routine
				// KLUDGE: For now, just add a percentage of fontSize to 
				// origin-y and hope for the best ...
				lineRect.origin.y += fontSize * 0.2;

				// Erase the last partial character(s) (back to last blank if possible)
				lineRect.origin.x = beginPoint.x;
				if (!loops)
					[self fillBkgGroundRect:context rect:lineRect];
				current = loops ? MAX(0,current+1) : current-1;
				break;
			}

		} // while space on this line

	  } // for each line
	
	  // reset the start of the previous page we just calculated
	  if (loops)
	  {  	
	    // Make sure we are starting after the last blank space
	    // for this line (32 is arbitrary)
	    if (lastBlankIndex > 0)
	    	current = lastBlankIndex+1;
	  	
	    // save this as our new start position
		start = MIN(MAX(0,current),[text length]);
      }
		
   } // while loops

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


int decodeToString(NSString * src, NSMutableString * dest);



// Open specified file and display
- (bool) openFile:(NSString *)name start:(int)startChar {
	NSMutableString * newText = nil;
    NSError         * error   = nil;
    
    // Load the text ...
    if (name)
    {
    	// Build the full path
		NSString *path = [NSString stringWithFormat:@"%@%@", TEXTREADER_PATH, name];

		// Read in the requested file ...
		if ([trApp getFileType:path] == kTextFileTypePDB)
		{
			newText = [[NSMutableString alloc] initWithString:@""];
			
			int rc = decodeToString(path, newText);
			if (rc)
			{
				[newText release];
				newText = nil;

				// Handle invalid format ...				
				if (rc == 2)
				{
					NSString *errorMsg = [NSString stringWithFormat:
												   @"Invalid PDB format for file \"%@\".", 
												   name];
					CGRect rect = [[UIWindow keyWindow] bounds];
					UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:CGRectMake(0,rect.size.height-240,rect.size.width,240)];
					[alertSheet setTitle:@"Invalid Format"];
					[alertSheet setBodyText:errorMsg];
					[alertSheet addButtonWithTitle:@"OK"];
					[alertSheet setDelegate:self];
					[alertSheet popupAlertAnimated:YES];

					return false;
				}				
			}
		}
		else
			// Read in the text file - let NSMutableString do the work
			newText = [[NSMutableString 
						stringWithContentsOfFile:path
						encoding:kCGEncodingMacRoman
						error:&error] retain];

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

			start = [trApp getDefaultStart:name];
			end   = 0;
			[self setNeedsDisplay];

			return true;
		}
	}

	NSString *errorMsg = [NSString stringWithFormat:
	                               @"Unable to open file \"%@\" in directory \"%@\".\nPlease make sure the directory and file exist and the read permissions for user \"mobile\" are set.", 
	                               name, TEXTREADER_PATH];
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


- (bool)setFont:(NSString*)newFont {
	// JIMB BUG BUG - implement this!!!
	font = [newFont copy];
	[self setNeedsDisplay];

	return true;
} // setFont


- (int)getFontSize {
	return fontSize;
} // getFontSize


- (bool)setFontSize:(int)newSize {
	// JIMB BUG BUG - implement this!!!
	fontSize = newSize;
	[self setNeedsDisplay];

	return true;
} // setFontSize


@end // @implementation MyTextView

