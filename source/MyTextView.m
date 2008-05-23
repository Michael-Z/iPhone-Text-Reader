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

#import <UIKit/UIKit.h>

// NOTE: This adds about 16K to the program!
// JIMB BUG BUG - look into a better way to "band" the conversion data
// Can we use the "add 160" algorithm?
#import "gb2312.h"

typedef unsigned int NSUInteger;
#define NSRangeMake(s,l) {s, l}




// *****************************************************************************
@implementation MyTextView


-(id) init {
    struct CGRect rect = [UIHardware fullScreenApplicationContentRect];
    rect.origin.x = rect.origin.y = 0.0f;

    return [self initWithFrame:rect];   
};

-(id) initWithFrame:(CGRect)rect {
    
    layout = &layoutbuf[16];
    
    text       = nil;
    
    screenLock = [[NSLock alloc] init];

    color    = 0;
    ignoreSingleLF = false;
    padMargins     = false;
    repeatLine     = false;
    
    isDrag = false;
    
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
    
    cStart = 0;
    yDelta = 0;
    cLayouts = 0;
    cDisplay = 0;
    lStart = 0;
    trApp = nil;
    fileName = nil;
    filePath = [TEXTREADER_DEF_PATH copy];
    
    // Make sure default directory exists
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


- (void) setIgnoreSingleLF:(bool)ignore {
    ignoreSingleLF = ignore;
    [self setNeedsDisplay];
}

- (void) setPadMargins:(bool)pad {
    padMargins = pad;
    [self setNeedsDisplay];
}

- (void) setRepeatLine:(bool)repeat {
    repeatLine = repeat;
} // setRepeastLine

- (int) getColor { return color; }
- (bool) getIgnoreSingleLF { return ignoreSingleLF; }
- (bool) getPadMargins { return padMargins; }
- (bool) getRepeatLine { return repeatLine; };
- (NSMutableString *) getText  { return text; }
- (NSString*) getFileName { return fileName; }
- (NSString*) getFilePath { return filePath; }


- (int) getStart { 
    return cStart;
}



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
        CGContextSetRGBFillColor(context, 1, 1, 1, 1);   // white
        CGContextSetRGBStrokeColor(context, 1, 1, 1, 1); // white
    }
    else
    {
        CGContextSetRGBFillColor(context, 0, 0, 0, 1);   // black    
        CGContextSetRGBStrokeColor(context, 0, 0, 0, 1); // black 
    }
    
} // fillBkgGroundRect









// ------------------------------------------------------

// IS this a blank character
static bool isBlank(unichar c)
{
    if (c == ' ' ||
        c == 0x0d)
       return TRUE;
    
    return FALSE;
    
} // isBlank


// IS this a CR/LF character
static bool isCRLF(unichar c)
{
    // Treat 0x0d as a blank
    if (c == 0x0a)
       return TRUE;
    
    return FALSE;
    
} // isCRLF


// Support ignoreSingleLF option:
// Assuming the character at start is a LF 0x0a character,
// is it the only one, or does it have a friend next to it?
- (bool) isSingleLF:(int)start {

    bool issingle = false;
    
    // if this LF is the first or last char in the 
    // text, we should return it as is
    if (start && start < (int)[text length]-1)
    {
        // What is before and after it?
        unichar after  = [text characterAtIndex:start+1];
        unichar before = [text characterAtIndex:start-1];

        // Special case following a 0x0d - we need to check one 
        // more character in front
        if (before == 0x0d &&
            (start < 2 || [text characterAtIndex:start-2] == 0x0a))
           before = 0x0a;

        // A following 0x0d means there will be a 0x0a after it 
        // so consider that sufficient proof ths is not a single
        if (before != 0x0a && after != 0x0a && after != 0x0d)
            issingle = true;
    }
        
    return issingle;

} // issingleLF


// Is this a character we can split on?
static bool isSplitChar(unichar c)
{
    // We always split on a CRLF
    if (isCRLF(c))
        return true;
        
    if (isBlank(c))
        return true;
        
    // NOTE: We currently split on tabs ...
    //       Maybe we should attach them to the char that follows?!?!?
    if (c == '\t')
       return true;
       
    // JIMB BUG BUG - should we split on '-' ?!?!?!?
    // We would really want to split on the char *after* it ... 
    
    // Anything else gets chunk'd together
    return false;
    
} // isSplitChar



// start - the start char for this line
- (bool) getFwdBlock:(NSRange *)block from:(int)start
{
    block->location = start;
    block->length   = 0;

    // Past end of text - nothing to see - move along
    if (start >= (int)[text length])
        return false;

    // Get first character to see what kind of block we want        
    unichar c = [text characterAtIndex:start];

    // JIMB BUG BUG - need to add support for ignoreSingleLF option!

    // A CR/LF is it's own block
    if (isCRLF(c))
    {
        block->length++;;
        return true;
    }
    
    // Tabs get returned by themselves just like CR/LF
    if (c == '\t')
    {
        block->length++;;
        return true;
    }
    
    // Are we looking for a block of blanks?
    if (isBlank(c))
    {
        // Get all following blanks
        while (start < (int)[text length] && isBlank([text characterAtIndex:start]))
        {
            start++;
            block->length++;
        }
        return true;
    }

    // OK we know we have one or more "real" characters to display
    // Search for the end of the block
    
    // Move forward until we hit a separator character
    while (start < (int)[text length] && !isSplitChar([text characterAtIndex:start]))
    {
        start++;
        block->length++;
    }
    
    return true;
    
} // getFwdBlock



// Inputs:
// lines - # of lines to be laid out in layouts
// layouts - portion of the layout array to fill in
// start - character to begin doing layout
// Returns:
// Number of lines laid out
// This routine lays out each line going forward begining at start
- (int) doFwdLayout:(int)lines layouts:(NSRange *)layouts start:(int)start
{
    int found = 0;
    
    if (start < 0)
        start = 0;
        
    CGSize  viewSiz = [trApp getOrientedViewSize];
    int     width   = (int)viewSiz.width - (padMargins ? TEXTREADER_MPAD * 2 : 0);
    int     line;
    
    // fill in each line until we are done or run out of space
    for (found = 0, line = 0; line < lines; line++, found++)
    {
        CGSize  lineused  = {0};
        NSRange block;
        
        // Strip leading blanks for the new line ...
        while (start < (int)[text length] && isBlank([text characterAtIndex:start]))
            start++;
            
        // If we hit the end, nothing to lay out
        if (start >= (int)[text length])
            break; // for each line
        
        // Remember the starting point for this line
        layouts[line].location = start;
        layouts[line].length   = 0;
        
        // Gather up the chunks that make up this line
        // NOTE: This could probably just be while(true) ?!?!?!?
        while (start < (int)[text length] && lineused.width < width)
        {
            // Get next chunk
            if ([self getFwdBlock:&block from:start])
            {
                // Should never happen, but ...
                if (!block.length)
                    break; // while this line
                    
                // We got here, so we know there is at least 1 character in the block
                unichar c = ([text characterAtIndex:block.location]);
                
                // Handle \n - end of the line so to speak
                // (\n is always returned all by itself)
                if (isCRLF(c))
                {
                    // This CR/LF ends the line
                    layouts[line].length = block.location + block.length - layouts[line].location;
                    
                    // Move the start past the CR/LF
                    start = block.location + block.length;
                    break; // while this line
                }

                // Figure out how large this block is
                NSString * x = [text substringWithRange:block];
                CGSize blkused = [x sizeWithFont:gsFont];

                // Does this block carry us over?
                if (lineused.width + blkused.width > width)
                {
                    // Split blocks *ALWAYS* start on their own line!
                    // If something else is on this line, end this one and go to the next
                    if (lineused.width)
                        break; // while this line
                    
                    // Use all of this block that we can, and then save the rest for the 
                    // next line (assuming there is a next line)
                    for (layouts[line].location = start, layouts[line].length = 0;
                         true;
                         layouts[line].length++, start++)
                    {
                        block.location = start;
                        block.length   = 1;
                        
                        NSString * x = [text substringWithRange:block];
                        blkused = [x sizeWithFont:gsFont];
                        
                        if (lineused.width + blkused.width > width)
                            break; // for characters in the too large block that fit on the line
                            
                        // This character fits, so remember it and keep going
                        lineused.width += blkused.width;
                        
                    } // for each character in a block being broken up
                    break; // while this line
                    
                }
                else
                {
                    // Room for this and more ... add this and keep going
                    lineused.width += blkused.width;
                    layouts[line].length = block.location + block.length - layouts[line].location;
                    start = block.location + block.length;
                    continue; // while this line
                }
            } // if we got a block
            else
                // No more text to get, so nothing more for this line
                break; // while this line
            
        } // while we are adding text to this line        
    
    } // for each line

    return found;
    
} // doFwdLayout



// Makes sure the subblock of layout is sync'd with "end"
// i.e. none of the lines in layout extend past end or include it
int tidyRevLayout(NSRange * layoutTop, int foundLines, int end)
{
    int line;
    
    // Tidy up the lines - make sure that they end before "end"
    for (line = 0; line < foundLines; line++)
    {
        if (end < (int)layoutTop[line].location)
            break;
                       
        // Make sure an individual line doesn't include "end"
        if (end < (int)layoutTop[line].location + (int)layoutTop[line].length - 1)
        {
             layoutTop[line].length = MAX(0, (end - (int)layoutTop[line].location) + 1);
        }
                
    } // for tidy up lines
    
    return line;
    
} // tidyRevLayout


// Going backwards, it tries to find a spot that marks a line end
// Right now this is when we find a 0x0a LF
// It could also be when we find a looong block of text w/o
// blanks, CR/LF, etc.
- (int) getRevStart:(int)end {

    int start;
    for (start = end; 
         start > 0 && !isCRLF([text characterAtIndex:start-1]); 
         start--);
    
    // JIMB BUG BUG - need to add support for ignoreSingleLF option!
    
    return start;
    
} // getRevStart

// Inputs:
// lines - # of lines to be laid out in layouts
// layouts - portion of the layout array to fill in
// end - last character in this layout
// Returns:
// Number of lines laid out
// This routine lays out each line going backwards begining 
// with the line that ends just before end
//
// We do this by finding a candidate point to begin a line, and then
// we lay out the line - repeating as needed
// 
- (int) doRevLayout:(int)lines layouts:(NSRange *)layouts end:(int)end
{

    // Can't do layout before the start of the text ...
    if (!lines || end < 0 || ![text length])
        return 0;
        
    // Can't end past the actual last character ...
    if (end > (int)[text length])
        end = (int)[text length]-1;
        
    // OK - we need to lay out some lines ...
    NSRange * layoutTop = layouts - (lines - 1);

    // Find a candidate begin point
    // A CR/LF will end the previous line, so stop before it
    // If there is a single CR/LF, use it as the start
    int start = [self getRevStart:end];
    
    // Lay out this chunk into the temp layout space
    int foundLines  = [self 
                       doFwdLayout:lines               // lines needed
                         layouts:layoutTop             // where to put new lines
                           start:start];
    if (!foundLines)
        return 0;   // This would be VERY unexpected ...
        
    // Tidy up the lines - make sure that they end before "end"
    foundLines = tidyRevLayout(layoutTop, foundLines, end);
    
    // OK - at this point, we have laid out foundLines lines
    
    // We either got the requested number of lines
    if (foundLines == lines)
    {
        // Ideally, we sync'd up the ending and are finished!
            
        // Otherwise - Blech!  There were more lines in start->end than we asked for
        // Layout the next line of text into a spare buffer
        // If it is past end we are done
        // Otherwise, move the layout "up" one to make room, copy the new one into the bottom,
        // and try again until we get the line just before "end"
        while ((int)layouts[0].location + (int)layouts[0].length < (int)[text length] && // JIMB BUG BUG - not really needed!!!
               (int)layouts[0].location + (int)layouts[0].length + 1 < end)
        {
            NSRange nextLayout = {0};
            
            foundLines  = [self 
                           doFwdLayout:1          // lines needed
                             layouts:&nextLayout  // where to put new lines
                               start:layouts[0].location + layouts[0].length];
                               
            // Tidy up the lines - make sure that they end before "end"
            foundLines = tidyRevLayout(&nextLayout, foundLines, end);
            
            // if we don't find any lines, it means we are done with the layout
            if (!foundLines)
                return lines;
                
            // Shouldn't happen, but ...
            if (foundLines > 1)
                foundLines = 1;
            
            // Otherwise, we need to move the block up, add the new layout, and try again
        
            // Move the block up "1"
            if (lines > 1)
                memmove(layoutTop, &layoutTop[1], sizeof(*layouts)*(lines-1));
                
            memcpy(layouts, &nextLayout, sizeof(nextLayout));
        }
        
        return lines;
    }
    
    // Or we processed all of start->end and probably still need more
    // (if it is available ...)
    else
    {
        // Move the block to the bottom
        if (foundLines && lines > 1)
            memmove(&layouts[-foundLines+1], layoutTop, foundLines * sizeof(*layouts));
        
        // Call ourselves to try to fill in the rest if possible
        // If we have hit the begining of text, we are done
        return foundLines + [self doRevLayout:lines-foundLines 
                                 layouts:&layouts[-foundLines] 
                                     end:start-1];
    }
    
    // We should never get here
    return 0;

} // doRevLayout



// Fills in the layout array based on cStart
- (void) doLayout:(int)deltaLine 
{

    if (!text || ![text length])
    {
        cDisplay = 0;
        cLayouts = 0;
        return;
    }

    [screenLock lock];
    

    CGSize  viewSiz = [trApp getOrientedViewSize];

    int lineHeight  = [self getLineHeight];
    int lines       = ((int)viewSiz.height / lineHeight) + 2;

    deltaLine -= lStart;

// We want to start drawing deltaLine lines above (neg) or below (pos) the line
// containing cStart.


    // First line to layout
    
    int first = deltaLine;

    int last  = first + lines - 1;

    int foundLines = 0;
       
    // Reuse what we can! Try to use previous layouts from the layout array

    // If first is in the valid layout array, copy the chunk so we 
    // only layout what we need
    // if (cLayouts && first >= lStart && first < lStart+cLayouts && deltaLine >= lStart)
    if (cLayouts && first >= 0 && first < cLayouts && deltaLine >= 0)
    {
        foundLines = cLayouts - first;
        
        // Copy these to the start
        memmove(&layout[0], &layout[first], sizeof(*layout)*foundLines);
        
        foundLines += [self 
                       doFwdLayout:lines-foundLines    // lines needed
                         layouts:&layout[foundLines]   // where to put new lines
                           start:(int)layout[foundLines-1].location +  // character to start new layout
                                 (int)layout[foundLines-1].length];
    }
        
    // Maybe we are going up, and a piece of the tail end of what we want is 
    // in the layout array ...
    else if (cLayouts && last >= 0 && last <= cLayouts)
    {
        foundLines = last + 1;
        
        // Copy these to the start
        memmove(&layout[lines-foundLines], &layout[0], sizeof(*layout)*foundLines);

        foundLines += [self 
                       doRevLayout:lines-foundLines      // lines needed
                           layouts:&layout[lines-(foundLines+1)]   // where to put new lines (reverse order!!!)
                               end:(int)layout[lines-foundLines].location-1];  // character to start new layout
                                   
        if (foundLines < lines)
        {
            // Tricky ... this should never happen unless we hit the top
            // Copy what we did get to the top
            memmove(&layout[0], &layout[lines-foundLines], sizeof(*layout)*foundLines);
            
            // Try to get forward layout to fix the rest 
            foundLines += [self 
                           doFwdLayout:lines-foundLines    // lines needed
                             layouts:&layout[foundLines]   // where to put new lines
                               start:(int)layout[foundLines-1].location +  // character to start new layout
                                     (int)layout[foundLines-1].length];
        }
    }
    
    // Can't use anything in the layout buffer - we have to 
    // assume the only thing we know is cStart 

    // Are we going backwards from the current position ?
    else if (deltaLine < 0)
    {
        foundLines = [self 
                      doRevLayout:lines      // lines needed
                          layouts:&layout[lines-1]   // where to put new lines (reverse order!!!)
                              end:cStart-1];  // character to start new layout                                   
        if (foundLines < lines)
        {
            int start;

            // Tricky ... this should never happen unless we hit the top
            // Copy what we did get to the top
            memmove(&layout[0], &layout[lines-foundLines], sizeof(*layout)*foundLines);
    
            if (foundLines)
                start = (int)layout[foundLines-1].location +
                        (int)layout[foundLines-1].length;
            else
                start = cStart;

            // Try to get forward layout to fix the rest 
            foundLines += [self 
                           doFwdLayout:lines-foundLines    // lines needed
                               layouts:&layout[foundLines]   // where to put new lines
                                 start:start];  // character to start new layout
        }
    }

    // Go forward from cStart ...
    else // if (deltaLine >= 0)
    {
        // Forward (layout relative to cStart on the first line)
        foundLines = [self doFwdLayout:lines
                               layouts:layout
                                 start:[self getStart]];  
                    // JIMB BUG BUG - This is almost certainly not right!!!!
                    // Handle when we have to calculate back down to get
                    // the correct starting point
    }

    // Remember how many lines are laid out in the layout array
    cLayouts = foundLines;
    
    // Remember the ma number of lines we can display ...
    cDisplay = cLayouts;

    if (cLayouts)
        cStart = MAX(0, MIN((int)layout[0].location, (int)[text length]-1));
    
    lStart += deltaLine;

    
    // Eliminate delta if we are at the top or bottom ...
    if (!cLayouts ||
        layout[0].location == 0 ||
        (int)layout[0].location+(int)layout[0].length >= (int)[text length]-1)
        yDelta = 0;
        
    // Special case page scroll - align text at the top 
    // and don't display partial lines at bottom
    if (!isDrag || ![trApp getSwipeOK])
    {
        yDelta = 0;

        // Strip out the partial line at the bottom???
        if (cDisplay >= (int)viewSiz.height / lineHeight)
            cDisplay = (int)viewSiz.height / lineHeight;
    }
    
    [screenLock unlock];
    
    // Force a redraw using the new layout
    [self setNeedsDisplay];
    
} // doLayout

// --------------------------------------------------------------


- (void) centerScrollerOffset {

    int lineHeight = [self getLineHeight];

    CGPoint offset;
    offset.x = 0;
    offset.y = SCROLLER_SIZE * lineHeight;
    [self setOffset:offset];
    lStart = 0;
    yDelta = 0;

} // centerScrollerOffset




- (void) pageUp {    

    isDrag = false;
  

    CGSize  viewSize = [trApp getOrientedViewSize];
    int lineHeight   = [self getLineHeight];

    int lines = (int)viewSize.height / lineHeight;

    lStart = 0;
    [self doLayout:repeatLine ? -(lines-1) : -lines];
    // lStart = 0;

    // Reset the scroller to the center
    [self centerScrollerOffset];
    
} // pageUp





- (void) pageDown {

    isDrag = false;


    CGSize  viewSize = [trApp getOrientedViewSize];
    int lineHeight   = [self getLineHeight];

    int lines = (int)viewSize.height / lineHeight;

    lStart = 0;
    [self doLayout:repeatLine ? (lines-1) : lines];
    // lStart = 0;
    
    // Reset the scroller to the center
    [self centerScrollerOffset];

} // pageDown



// --------------------------------------------------------------








// Blech!!! Figure this properly!!!
- (int) getLineHeight {
    return fontSize * 1.25 + 1;
} // getLineHeight


// Missing Prototypes ...
struct __GSFont * GSFontCreateWithName( const char * fontname, int style, float ptsize);
// bool CGFontGetGlyphsForUnichars(CGFontRef, unichar[], CGGlyph[], size_t);
// extern CGFontRef CGContextGetFont(CGContextRef);
// extern CGFontRef CGFontCreateWithFontName (CFStringRef name);


- (void)drawRect:(struct CGRect)rect
{
    CGRect lineRect;

    // No text means nothing to do ...
    if (!text || ![text length] || !trApp || !gsFont)
       return [super drawRect:rect];
       
    [screenLock lock];
    
    CGSize viewSize = [trApp getOrientedViewSize];

    CGContextRef context = UICurrentContext();

    int lineHeight = [self getLineHeight]; 

// JIMB BUG BUG - Figure out how to only redraw the invalid portion !!!

    // Always clear the first line ...
    lineRect = CGRectMake(0, rect.origin.y, viewSize.width, lineHeight);
    [self fillBkgGroundRect:context rect:lineRect];

    // // Figure out where we draw the text
    // // This allows us to scroll partial lines
        
    int yStart = rect.origin.y - yDelta;
    int yEnd   = yStart + rect.size.height;
    
    int line;
    
    for (line = 0; yStart <= yEnd; yStart += lineHeight, line++)
    {   
        lineRect = CGRectMake(0, yStart, viewSize.width, lineHeight);

        [self fillBkgGroundRect:context rect:lineRect];
        
        // Nothing else to do if there is no text on this line
        if (line >= cDisplay || layout[line].location >= [text length])
           continue;

        // Get the substring for this "chunk" of text
        NSString * x     = [text substringWithRange:layout[line]];
        CGPoint    pt    = CGPointMake(padMargins ? TEXTREADER_MPAD : 0, lineRect.origin.y);
        [x drawAtPoint:pt withFont:gsFont];
    }

    // Wipe any remaining text ...
    lineRect = CGRectMake(0, yStart, viewSize.width, lineHeight);
    [self fillBkgGroundRect:context rect:lineRect];
    
       
    [screenLock unlock];
    
    return [super drawRect:rect];
    
} // drawRect


- (void) sizeScroller {

    // No text - nothing to do ...
    if (!text || ![text length])
        return;
    
    CGRect fsrect = [trApp getOrientedViewRect];
    
    // [self setScrollHysteresis: 20.f];
    
    [self setAllowsFourWayRubberBanding: NO];

    // forEdges: is bitmapped 1,2,4,8 for direction
    // 2 + 8 is up/down
    // [self setRubberBand: 15.f forEdges: 10];
    
    // fsrect.size.height = (fsrect.size.height / lineHeight * lineHeight);
    // [self setGridSize:fsrect.size];

    // The thumb is misleading, so leave it off for now ...
    [self setShowScrollerIndicators:false];
    
    [self setDelegate:self];

    // Set scroller size and position   
    int lineHeight = [self getLineHeight];
    CGSize contents;
    
    // Scroll range is large enough to hold all possible lines above and below
    // See header for SCROLLER_SIZE justification
    contents.width  = fsrect.size.width;
    contents.height = SCROLLER_SIZE * 2 * lineHeight;
    [self setContentSize:contents];
       
    // Reset the scroller to the center
    [self centerScrollerOffset];   
    
    // Force new layout since we reset the offset
    cDisplay = cLayouts = 0;
    
    // Do a new layout using the current position/line
    [self doLayout:0];
    lStart = 0;

} // sizeScroller


- (void) setStart:(int)newStart {
    if (text)
    {
        // Force layout to use the new start location
        cDisplay = cLayouts = 0;

        cStart = MAX(0, MIN((int)[text length]-1, newStart));
        
        [self sizeScroller];
        // sizeScroller will do a new layout and force a redraw
    }
} // setStart



// Set the new text for this view
- (void) setText:(NSMutableString  *)newText; {

    [screenLock lock];
    
    if (text)
        [text release];
    text = newText;
    
    [screenLock unlock];

    // Size UIScroller based on the text
    [self sizeScroller];
    // sizeScroller will do a new layout and force a needsDisplay redraw
    
} // newText
            
    
// Convert an NSData with "invalid" GB2312 data into a UTF16 string
static NSMutableString * convertGB2312Data(NSData * data) {
    int                   i;
    unichar               c[8096];
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



// Replace some entities with characters more likely to be transcodable
static unichar patchEntity(unichar entity)
{
    // Quick patch job for a couple of entities
    if (entity == 0x00)
        entity = '?';   // Need to pick a better character here ...
    else if (entity == 0x2003)
        entity = ' '; // entity = 0x2003;
    else if (entity == 0x2002)
        entity = ' '; //entity = 0x2002;
    else if (entity == 0x00A0)
        entity = ' '; //entity = 0x00A0;
    else if (entity == 0x00B4)
        entity = '\''; //entity = 0x00B4;
    else if (entity == 0x2018)
        entity = '\''; //entity = 0x2018;
    else if (entity == 0x2014)
        entity = '-'; //entity = 0x2014;
    else if (entity == 0x2013)
        entity = '-'; //entity = 0x2013;
    else if (entity == 0x201D)
        entity = '"'; //entity = 0x201D;
    else if (entity == 0x2019)
        entity = '\''; //entity = 0x2019;
        
    return entity;
    
} // patchEntity


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
            // look for the ending ';'
            added.length = getTag(dest, added.location+1, added.location+16, ";", NULL);
            if (added.length)
            {
                UniChar entity = 0x0000;
                
                added.length -= added.location-1;
                
                // Handle &#????; entities
                if ([dest characterAtIndex:added.location+1] == '#')
                {
                    // Convert the number to a unicode character - no validation!
                    int i;
                    for (i = 2; i < added.length; i++)
                    {
                        c = [dest characterAtIndex:added.location+i];
                        if (c == ';')
                            break;
                            
                        if (c < '0' || c > '9')
                            break;
                            
                        entity = entity * 10 + c - '0';
                    }
                    // Whatever it is, it is ...                    
                }
                else
                {
                
                    // Currently using a series of switch statements to speed things up
                    // This should probably be table driven instead, but ...

                    // Start by keying off of the entity length
                    switch (added.length) 
                    {
                        case 4:
                            switch([dest characterAtIndex:added.location+1])
                            {
                                case 'G': case 'g':
                                    // gt       003E
                                    if (getTag(dest, added.location, added.location+added.length, "GT;", "gt;"))
                                        entity = 0x003E;
                                    break;

                                case 'L': case 'l':
                                    // lt       003C
                                    if (getTag(dest, added.location, added.location+added.length, "LT;", "lt;"))
                                        entity = 0x003C;
                                    break;
                            }
                        break;

                        case 5:
                            switch([dest characterAtIndex:added.location+1])
                            {
                                case 'A': case 'a':
                                    // amp      0026
                                    if (getTag(dest, added.location, added.location+added.length, "AMP;", "amp;"))
                                        entity = 0x0026;
                                    break;

                                case 'R': case 'r':
                                    // reg      00AE
                                    if (getTag(dest, added.location, added.location+added.length, "REG;", "reg;"))
                                        entity = 0x00AE;
                                    break;

                                case 'U': case 'u':
                                    // uml      00A8
                                    if (getTag(dest, added.location, added.location+added.length, "UML;", "uml;"))
                                        entity = 0x00A8;
                                    break;

                                case 'Y': case 'y':
                                    // yen      00A5
                                    if (getTag(dest, added.location, added.location+added.length, "YEN;", "yen;"))
                                        entity = 0x00A5;
                                    break;
                            }
                        break;

                        case 6:
                            switch([dest characterAtIndex:added.location+1])
                            {
                                case 'C': case 'c':
                                    // copy     00A9 
                                    if (getTag(dest, added.location, added.location+added.length, "COPY;", "copy;"))
                                        entity = 0x00A9;
                                    // cent     00A2    
                                    else if (getTag(dest, added.location, added.location+added.length, "CENT;", "cent;"))
                                        entity = 0x00A2;
                                    break;

                                case 'E': case 'e':
                                    // emsp     2003
                                    if (getTag(dest, added.location, added.location+added.length, "EMSP;", "emsp;"))
                                        entity = 0x2003;
                                    // ensp     2002
                                    else if (getTag(dest, added.location, added.location+added.length, "ENSP;", "ensp;"))
                                        entity = 0x2002;
                                    // euro     20ac
                                    else if (getTag(dest, added.location, added.location+added.length, "EURO;", "euro;"))
                                        entity = 0x20AC;
                                    break;

                                case 'N': case 'n':
                                    // nbsp     00A0
                                    if (getTag(dest, added.location, added.location+added.length, "NBSP;", "nbsp;"))
                                        entity = 0x00A0;
                                    break;

                                case 'Q': case 'q':
                                    // quot     0022    
                                    if (getTag(dest, added.location, added.location+added.length, "QUOT;", "quot;"))
                                        entity = 0x0022;
                                    break;
                            }
                        break;

                        case 7:
                            switch([dest characterAtIndex:added.location+1])
                            {
                                case 'A': case 'a':
                                    // acute    00B4
                                    if (getTag(dest, added.location, added.location+added.length, "ACUTE;", "acute;"))
                                        entity = 0x00B4;
                                    break;

                                case 'B': case 'b':
                                    // bdquo    201E
                                    if (getTag(dest, added.location, added.location+added.length, "BDQUO;", "bdquo;"))
                                        entity = 0x201E;
                                    break;

                                case 'I': case 'i':
                                    // iexcl    00A1
                                    if (getTag(dest, added.location, added.location+added.length, "IEXCL;", "iexcl;"))
                                        entity = 0x00A1;
                                    break;

                                case 'L': case 'l':
                                    // ldquo    201C
                                    if (getTag(dest, added.location, added.location+added.length, "LDQUO;", "ldquo;"))
                                        entity = 0x201C;
                                    // lsquo    2018
                                    else if (getTag(dest, added.location, added.location+added.length, "LSQUO;", "lsquo;"))
                                        entity = 0x2018;
                                    break;

                                case 'M': case 'm':
                                    // mdash    2014
                                    if (getTag(dest, added.location, added.location+added.length, "MDASH;", "mdash;"))
                                        entity = 0x2014;
                                    break;

                                case 'N': case 'n':
                                    // ndash    2013
                                    if (getTag(dest, added.location, added.location+added.length, "NDASH;", "ndash;"))
                                        entity = 0x2013;
                                    break;

                                case 'P': case 'p':
                                    // pound    00A3
                                    if (getTag(dest, added.location, added.location+added.length, "POUND;", "pound;"))
                                        entity = 0x00A3;
                                    break;

                                case 'R': case 'r':
                                    // rdquo    201D
                                    if (getTag(dest, added.location, added.location+added.length, "RDQUO;", "rdquo;"))
                                        entity = 0x201D;
                                    // rsquo    2019
                                    else if (getTag(dest, added.location, added.location+added.length, "RSQUO;", "rsquo;"))
                                        entity = 0x2019;
                                    break;

                                case 'S': case 's':
                                    // sbquo    201A
                                    if (getTag(dest, added.location, added.location+added.length, "SBQUO;", "sbquo;"))
                                        entity = 0x201A;
                                    break;

                                case 'T': case 't':
                                    // tilde    00C3
                                    if (getTag(dest, added.location, added.location+added.length, "TILDE;", "tilde;"))
                                        entity = 0x00C3;
                                    break;
                            }
                        break;

                        case 8:
                            switch([dest characterAtIndex:added.location+1])
                            {
                                case 'C': case 'c':
                                    // curren   00A4
                                    if (getTag(dest, added.location, added.location+added.length, "CURREN;", "curren;"))
                                        entity = 0x00A4;
                                    break;

                                case 'E': case 'e':
    // JIMB BUG BUG - Should this be upper or lower case ?!?!?!? is 0xC9 correct ?!?!?                    
                                    // eacute   00C9
                                    if (getTag(dest, added.location, added.location+added.length, "EACUTE;", "eacute;"))
                                        entity = 0x00C9;
                                    break;

                                case 'I': case 'i':
                                    // iquest   00BF
                                    if (getTag(dest, added.location, added.location+added.length, "IQUEST;", "iquest;"))
                                        entity = 0x00BF;
                                    break;

                                case 'M': case 'm':
                                    // middot   00B7
                                    if (getTag(dest, added.location, added.location+added.length, "MIDDOT;", "middot;"))
                                        entity = 0x00B7;
                                    break;
                            }
                        break;
                    }
                }
                
                // Do entity patch up as needed
                entity = patchEntity(entity);
                    
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
 
//          case 'D': case 'd':
//              // <div
//              if (getTag(src, rtag.location, 3+rtag.location+1, "IV>", "iv>") ||
//                  getTag(src, rtag.location, 3+rtag.location+1, "IV ", "iv "))
//                  [dest appendString:@"\n"];
//              break;

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
 
//                  case 'D': case 'd':
//                      // </div
//                      if (getTag(src, rtag.location+1, 4+rtag.location+1, "DIV>", "div>") ||
//                          getTag(src, rtag.location+1, 4+rtag.location+1, "DIV ", "div "))
//                          [dest appendString:@"\n"];
//                      break;
 
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
                //  [dest appendString:@"[[["];
                //  [dest appendString:[src substringWithRange:rtag]];
                //  [dest appendString:@"]]]"];
                //  break;
            }
            break;

        // default: // debug only
        //  [dest appendString:@"[[["];
        //  [dest appendString:[src substringWithRange:rtag]];
        //  [dest appendString:@"]]]"];
        //  break;
                
    } // switch on first char of tag
    
} // addHTMLTag



// KLUDGE - fix this !!!!

// Strips out HTML tags and produces ugly text for reading enjoyment ...
- (void) stripHTML:(NSMutableString  *)newText type:(TextFileType)ftype {

    NSMutableString  *src   = newText;
    NSRange           rtext = {0};
    NSRange           rtag  = {0};
    
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
            if (rc || !data || ![data length])
            {
                if (data)
                    [data release];
                data = nil;

                // Handle invalid format ...                
                if (rc == 2)
                {
                    NSString *errorMsg = [NSString stringWithFormat:
                                                   @"The format of \"%@\" is \"%@\".\n%@ is only able to open unencrypted Mobipocket, Plucker, and Palm Doc PDB files.\nSorry ...", 
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
                [trApp setDefaultStart:fileName start:cStart];
        
            if (fileName)
                [fileName release];
            fileName = [[name copy] retain];

            if (filePath)
                [filePath release];
            filePath = [[path copy] retain];
                
            cStart = [trApp getDefaultStart:name];

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


- (NSStringEncoding)getEncoding {
    return encoding;
} // getEncoding


- (bool)setEncoding:(NSStringEncoding)enc {
    
    if (!enc)
        enc = kCGEncodingMacRoman;
        
    encoding = enc;
    
// JIMB BUG BUG reopen the book!!!!???!!!

    // [self setNeedsDisplay];
    
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
        
        [self sizeScroller];
        // SizeScroller will force a redraw
        
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

- (NSString *)getFont {
    return font;
} // getFont


- (void)mouseDown:(struct __GSEvent*)event {

    isDrag = false;
    [ [self tapDelegate] mouseDown: event ];
    [ super mouseDown: event ];

} // mouseDown

 
- (void)mouseUp:(struct __GSEvent *)event {

    [ [self tapDelegate] mouseUp: event ];
    [ super mouseUp: event ];
    
} // mouseUp


- (bool)getIsDrag {
    return isDrag;
} // getIsDrag


- (void)mouseDragged:(struct __GSEvent *)event
{
    
    // We use this to disable scrolling as needed
    if ([trApp getSwipeOK])
    {
        isDrag = true;
        [super mouseDragged:event];
    }
    
} // mouseDragged


// Keep current page up to date
- (void) scrollerDidEndDragging: (id) id  willSmoothScroll: (BOOL) scr
{
    // Not being used for anything at the moment ...
} // scrollerDidEndDragging



// continuous scroll events when moving
- (void) scrollerDidScroll: (id) id
{
    if (!text)
        return;
    
    // Figure new line based on slider offset
    // CGPoint start = [self dragStartOffset];    
    CGPoint offset = [self offset];
    
    // Keep track of partial line offset
    yDelta = (int)offset.y % [self getLineHeight];
    
    // This is the line offset from the initial scroll position
    int delta = (int)(offset.y - yDelta - SCROLLER_SIZE) /  [self getLineHeight] ;

    // Do layout for the new line
    // We moved current-start pixels from cStart
    // [self doLayout:delta-lStart];
    [self doLayout:delta];

} // scrollerDidScroll



@end // @implementation MyTextView

