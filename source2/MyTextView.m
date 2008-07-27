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
#import <UIKit/UIFont.h>

#include "rtftype.h"
#include "rtfdecl.h"

#define NSRangeMake(s,l) {s, l}




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

    cacheAll       = false;
    invertColors   = false;
    ignoreSingleLF = IgnoreLF_Off;
    padMargins     = false;
    repeatLine     = false;
    gestureMode    = false;
    fontZoom       = false;
    textAlignment  = Align_Left;

    indentParagraphs = 0;

    [self setTextColors:nil];

    isDrag = false;

    gsFont   = nil;
    font     = TEXTREADER_DFLT_FONT;
    fontSize = TEXTREADER_DFLT_FONTSIZE;

    memset(&encodings[0], 0x00, sizeof(encodings));
    encodings[0] = TEXTREADER_DFLT_ENCODING;

    cStart = 0;
    yDelta = 0;
    cLayouts = 0;
    cDisplay = 0;
    lStart = 0;
    trApp = nil;
    fileName = nil;
    filePath = [TEXTREADER_DEF_PATH copy];

    bkgImage = nil;
    bkgImageName = [_T(@"None") copy];

    // Make sure default directory exists
    [[NSFileManager defaultManager] createDirectoryAtPath:TEXTREADER_DEF_PATH attributes:nil];

    // [self setEnabledGestures:YES];
    // [self setGestureDelegate:self];

    return [super initWithFrame:rect];

} // initWithFrame


- (void) setFontZoom:(bool)zoom { fontZoom = zoom; };
- (bool) getFontZoom { return fontZoom; };


- (bool) setBkgImage:(NSString*)name {

    if (!name || ![name length] ||
        ![name compare:_T(@"None") options:kCFCompareCaseInsensitive])
    {
        if (bkgImage)
            [bkgImage release];
        bkgImage = nil;
        if (bkgImageName)
            [bkgImageName release];
        bkgImageName = [_T(@"None") copy];

        return true;
    }

    UIImage * img = [[UIImage applicationImageNamed:[NSString stringWithFormat:@"images/%@", name]] retain];
    if (!img)
    {
        [trApp showDialog:_T(@"Error")
                        msg:[NSString stringWithFormat:_T(@"Unable to load background image %@"), name]
                     buttons:DialogButtons_OK];
        return false;
    }

    if (bkgImage)
        [bkgImage release];
    bkgImage = img;
    if (bkgImageName)
        [bkgImageName release];
    bkgImageName = [name copy];

    [self setNeedsDisplay];

    return true;

} // setBkgImage


- (NSString*) getBkgImage { return bkgImageName; };


// //  touchesMoved:withEvent
// //- (void) gestureChanged:(GSEvent*)gsevent
// - (void)touchesMoved:(NSSet *)touchset withEvent:(UIEvent *)event
// {
// //    UIEvent * event = (UIEvent*)gsevent;
//
//     if (!fontZoom)
//         return;
//
//     NSArray *touches = [touchset allObjects];
//
//     if ([touches count] > 1)
//     {
//         UITouch * t1 = [touches objectAtIndex:0];
//         UITouch * t2 = [touches objectAtIndex:1];
//
//         CGPoint l1 = [t1 locationInView:self];
//         CGPoint l2 = [t2 locationInView:self];
//
//         // Save current distance between the 2 points ...
//         CGPoint vector = CGPointMake(l1.x-l2.x, l1.y-l2.y);
//
//         float gestureEnd = sqrtf(vector.x*vector.x + vector.y*vector.y);
//
//         // Do nothing if the difference is minimal
//          if (ABS(gestureEnd - gestureStart) < 30)
//              return;
//
//         // Larger or smaller?
//         if (gestureEnd > gestureStart)
//         {
//            [self setFont:[self getFont] size:[self getFontSize]+1];
//         }
//         else
//         {
//             [self setFont:[self getFont] size:[self getFontSize]-1];
//         }
//
//         // Save new starting point ...
//         gestureStart = gestureEnd;
//
//     }
//
// } // gestureEnded



// // touchesBegan:withEvent:
// //- (void) gestureStarted:(GSEvent*)gsevent
// - (void)touchesBegan:(NSSet *)touchset withEvent:(UIEvent *)event
// {
// //    UIEvent * event = (UIEvent*)gsevent;
//
//     if (!fontZoom)
//         return;
//
//     NSArray *touches = [touchset allObjects];
//
//     if ([touches count] > 1)
//     {
//         UITouch * t1 = [touches objectAtIndex:0];
//         UITouch * t2 = [touches objectAtIndex:1];
//
//         CGPoint l1 = [t1 locationInView:self];
//         CGPoint l2 = [t2 locationInView:self];
//
//         // Save current distance between the 2 points ...
//         CGPoint vector = CGPointMake(l1.x-l2.x, l1.y-l2.y);
//
//         gestureStart = sqrtf(vector.x*vector.x + vector.y*vector.y);
//     }
//
// } // gestureStarted


// - (BOOL) canHandleGestures
// {
//   return YES;
// }


- (BOOL) canHandleSwipes
{
    return YES;
}


// Like the trApp version, but this one will apply th status bar offset
// to the rect if the status bar is being displayed ...
- (struct CGRect) getOrientedViewRect {

    CGRect FSrect = [trApp getOrientedViewRect];

    // Apply the status bar offset ...
    if ([trApp getShowStatus] != ShowStatus_Off)
    {
        FSrect.origin.y    += [UIHardware statusBarHeight];
        FSrect.size.height -= [UIHardware statusBarHeight];
    }

    return FSrect;

} // getOrientedViewRect



- (void) setTextReader:(textReader*)tr {
    trApp = tr;
} // setTextReader


// 0 = black text on white
// 1 = white text on black
- (void) setInvertColors:(bool)invert {
    invertColors = invert;
    [self setNeedsDisplay];
} // setInvertColors

- (void) setCacheAll:(bool)ca {
    cacheAll = ca;
} // setCacheAll


- (void) setRepeatLine:(bool)repeat {
    repeatLine = repeat;
} // setRepeastLine


- (bool) getCacheAll { return cacheAll; }
- (bool) getInvertColors { return invertColors; }
- (IgnoreLF) getIgnoreSingleLF { return ignoreSingleLF; }
- (bool) getPadMargins { return padMargins; }
- (bool) getRepeatLine { return repeatLine; };
- (NSMutableString *) getText  { return text; }
- (NSString*) getFileName { return fileName; }
- (NSString*) getFilePath { return filePath; }
- (AlignText) getTextAlignment { return textAlignment; }
- (int) getIndentParagraphs { return indentParagraphs; };


- (int) getStart {
    return cStart;
}


// Fill in background with proper color, and then set the text colors
- (void)fillBkgGroundRect:(CGContextRef)context rect:(CGRect)rect yOffset:(int)yStart {

    // Blank out the rect
    if (invertColors)
        CGContextSetRGBFillColor(context, txtcolors.text_red,
                                          txtcolors.text_green,
                                          txtcolors.text_blue,
                                          txtcolors.text_alpha);
    else
        CGContextSetRGBFillColor(context, txtcolors.bkg_red,
                                          txtcolors.bkg_green,
                                          txtcolors.bkg_blue,
                                          txtcolors.bkg_alpha);

    // Fill in anything that might not be drawn for some reason ...
    CGContextFillRect(context, rect);

    if (bkgImage)
    {
        CGRect  imgRect  = rect;

        // Figure out the part of the rect that matches the bkg
        imgRect.origin.y -= yStart;

        // Handle the case where drawing starts above the visible rect
        if (imgRect.origin.y < 0)
        {
            rect.size.height = imgRect.size.height = MAX(imgRect.size.height+imgRect.origin.y, 0);
            imgRect.origin.y = 0;
            rect.origin.y = yStart;
        }

        // Handle the case where drawing extends below the visible rect
        float excess = (imgRect.origin.y+imgRect.size.height) - [bkgImage size].height;
        if (excess > 0)
            rect.size.height = imgRect.size.height = MAX(imgRect.size.height-excess, 0);

        [bkgImage compositeToRect:rect fromRect:imgRect operation:1 fraction:1.0];
    }

    // Restore text colors
    if (invertColors)
    {
        CGContextSetRGBFillColor(context, txtcolors.bkg_red,
                                          txtcolors.bkg_green,
                                          txtcolors.bkg_blue,
                                          txtcolors.bkg_alpha);
        CGContextSetRGBStrokeColor(context, txtcolors.bkg_red,
                                          txtcolors.bkg_green,
                                          txtcolors.bkg_blue,
                                          txtcolors.bkg_alpha);
    }
    else
    {
        CGContextSetRGBFillColor(context, txtcolors.text_red,
                                          txtcolors.text_green,
                                          txtcolors.text_blue,
                                          txtcolors.text_alpha);
        CGContextSetRGBStrokeColor(context, txtcolors.text_red,
                                          txtcolors.text_green,
                                          txtcolors.text_blue,
                                          txtcolors.text_alpha);
    }

} // fillBkgGroundRect



- (void) setTextColors:(MyColors*)newcolors {

    // Obviously wrong stuff will change to default
    if (!newcolors ||
        (newcolors->text_red   == newcolors->bkg_red &&
         newcolors->text_green == newcolors->bkg_green &&
         newcolors->text_blue  == newcolors->bkg_blue))
    {
       // Default black text on white bkg
       txtcolors.text_red   = 0; // black
       txtcolors.text_green = 0;
       txtcolors.text_blue  = 0;

       txtcolors.bkg_red    = 1; // white
       txtcolors.bkg_green  = 1;
       txtcolors.bkg_blue   = 1;
    }
    else
    {
        memcpy(&txtcolors, newcolors, sizeof(txtcolors));
    }

    txtcolors.text_alpha = 1;
    txtcolors.bkg_alpha = 1;

} // setTextColors


- (MyColors) getTextColors {
    return txtcolors;
} // getTextColors






// ------------------------------------------------------

// IS this a blank character
- (bool) isLiteralBlank:(unichar)c
{
    // We treat 0x0d as an embedded blank ... not ideal,
    // but it keeps us from having to parse the string
    // to skip them ... luckily with proportional fonts
    // 2 spaces look an awful lot like one ...
    if (c == ' '    ||
        c == 0x3000 || // IDEOGRAPHIC SPACE
        c == '\t'   ||
        c == 0x0d)
       return TRUE;

    return FALSE;

} // isLiteralBlank


// Support ignoreSingleLF option:
// If this is not an LF, return FALSE
// If ignoreLF is 0, return TRUE
// If first or last char, return TRUE
// If there is an LF on either side, return TRUE
// If ignoreLF = 1, return FALSE
// If LF is followed by '-', Tab or Cap character, return TRUE
// Return FALSE
- (bool) isLF:(int)start {

    // If this is not an LF, return FALSE
    if (start < 0 ||
        start >= (int)[text length] ||
        [text characterAtIndex:start] != 0x0a)
       return FALSE;

    // If ignoreLF is Off, return TRUE
    if (ignoreSingleLF == IgnoreLF_Off)
        return TRUE;

    // If this LF is the first or last char in the
    // text, we should return TRUE
    if (!start || start == (int)[text length]-1)
        return TRUE;

    // What is before and after it?
    unichar after  = [text characterAtIndex:start+1];
    unichar before = [text characterAtIndex:start-1];

    // Special case following a 0x0d - we need to check one
    // more character in front
    if (before == 0x0d &&
        (start < 2 || [text characterAtIndex:start-2] == 0x0a))
       before = 0x0a;

    // A 0x0d after this means there will be a 0x0a after the 0x0d
    // so consider that sufficient proof this is not a single
    if (before == 0x0a || after == 0x0a || after == 0x0d)
        return TRUE;

    // If ignoreSingleLF is Single, return FALSE
    if (ignoreSingleLF == IgnoreLF_Single)
        return FALSE;

    // If LF is followed by '-', Tab return TRUE
    if (after == '-' || after == 0x2014 || after == '\'' || after == '\"' || after == '\t')
        return TRUE;

//     // If LF is followed by an uppercase character, return TRUE
//     NSRange block = {start+1, 1};
//     NSString * upper = [[text substringWithRange:block] uppercaseString];
//
//     if ([upper characterAtIndex:0] == after)
//         return TRUE;

    // If the previous non-blank character was '.' or ':' treat as a "real" LF
    int prev = start-1;
    while (prev >= 0)
    {
        before = [text characterAtIndex:prev];
        if (![self isLiteralBlank:before])
           break;
        prev--;
    }
    // If prev char was a line ending char, keep the LF
    if (before == '.' || before == '!' ||
        before == ';' ||
        before == '?' || before == '"' ||
        before == '\'' || before == ':')
        return TRUE;

    // Return FALSE
    return FALSE;

} // isLF


// IS this a punctuation character
- (bool) isPunct:(int)start
{
    unichar c = [text characterAtIndex:start];

    switch (c)
    {
        case '.':
        case '!':
        case '(':
        case ')':
        case '-':
        case '=':
        case '+':
        case '*':
        case '/':
        case ',':
        case '<':
        case '>':
        case '{':
        case '}':
        case '[':
        case ']':
        case '\\':
        case '\'':
        case '"':
        case '`':
        case '?':
            return true;
    }

    return false;

} // isPunct


// IS this a blank character
- (bool) isBlank:(int) start
{
    unichar c = [text characterAtIndex:start];

    // A literal blank is a blank
    if ([self isLiteralBlank:c])
        return TRUE;

    // *If* We have a single LF and are ignoring single LFs, it
    // should be treated as a blank/space rather than as a LF
    if (c == 0x0a && ![self isLF:start])
       return TRUE;

    return FALSE;

} // isBlank


// IS this a CR/LF character
- (bool) isCRLF:(int)start
{
   // Handle ignore single LF option
   return [self isLF:start];

} // isCRLF


// Is this a character we can split on?
- (bool) isSplitChar:(int)at
{
    unichar c = [text characterAtIndex:at];
    unichar nextc = 0x00;
    unichar prevc = 0x00;

    // Get the next character
    if (at < (int)[text length] - 1)
        nextc = [text characterAtIndex:at+1];

    // Get the previous character
    if (at > 0)
        prevc = [text characterAtIndex:at-1];

    // NOTE: CRLF, blanks, and tabs go with the next block of text
    // We always split on a CRLF
    if ([self isCRLF:at])
        return true;

    // We can always split on a blank ...
    if ([self isBlank:at])
        return true;

    // NOTE: We currently split on tabs ...
    //       This attaches them to the text that follows
    if (c == '\t')
       return true;

    // JIMB BUG BUG - should we split on '-' ?!?!?!?
    // We would really want to split on the char *after* it ...

    // Split *after* period, comma, and dash, etc.
    // We want to keep these split characters with the current text
    // so we check for them after the fact
    if (ignoreSingleLF == IgnoreLF_Format &&
        (prevc == ',' ||
//         prevc == ':' ||
         prevc == '-' ||
         prevc == 0x2014 ||
         prevc == '=' ||
         prevc == ';' ||
         prevc == '.'))
       return true;

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
    // unichar c = [text characterAtIndex:start];

    // JIMB BUG BUG - need to add support for ignoreSingleLF option!

    // A CR/LF is it's own block
    if ([self isCRLF:start])
    {
        block->length++;;
        return true;
    }

//     // Tabs get returned by themselves just like CR/LF
//     if (c == '\t')
//     {
//         block->length++;;
//         return true;
//     }

    // Are we looking for a block of blanks?
    if ([self isBlank:start])
    {
        // Get all following blanks
        while (start < (int)[text length] && [self isBlank:start])
        {
            start++;
            block->length++;
        }
        return true;
    }

    // OK we know we have one or more "real" characters to display
    // Search for the end of the block

    start++;
    block->length++;

    // Move forward until we hit a separator character
    while (start < (int)[text length] && ![self isSplitChar:start])
    {
        start++;
        block->length++;
    }

    return true;

} // getFwdBlock


static void initLayout(TextLayout * txtLayout, int start, int length, bool newParagraph)
{
    memset(txtLayout, 0x00, sizeof(*txtLayout));

    txtLayout->range.location = start;
    txtLayout->range.length   = length;

    txtLayout->width          = -1;
    txtLayout->blank_width    = -1;

    txtLayout->newParagraph = newParagraph;

} // initLayout


// Inputs:
// lines - # of lines to be laid out in layouts
// layouts - portion of the layout array to fill in
// start - character to begin doing layout
// Returns:
// Number of lines laid out
// This routine lays out each line going forward begining at start
- (int) doFwdLayout:(int)lines layouts:(TextLayout *)layouts start:(int)start
{
    int found = 0;

    if (start < 0)
        start = 0;

    CGRect  viewRect = [self getOrientedViewRect];
    int     line;

    // fill in each line until we are done or run out of space
    for (found = 0, line = 0; line < lines; line++, found++)
    {
        CGSize  lineused  = {0};
        NSRange block;
        bool    newParagraph = false;
        float   width   = viewRect.size.width - (float)(padMargins ? TEXTREADER_MPAD * 2 : 0);

        // Keep track of whether or not this is the start of a new paragraph
        // We have to back up to before stripped blanks ...
        int blankStart = start;
        while (blankStart > 0 && blankStart < (int)[text length])
        {
            if (![self isBlank:blankStart-1])
                break;
            blankStart--;
        }
        if (blankStart <= 0 ||
            (blankStart < (int)[text length] && [self isCRLF:blankStart-1]))
            newParagraph = true;

        // Strip leading blanks for the new line ...
        if (indentParagraphs >= 0 || !newParagraph)
        {
            while (start < (int)[text length] && [self isBlank:start])
                start++;
        }

        // If we hit the end, nothing to lay out
        if (start >= (int)[text length])
            break; // for each line

        // Reserve space for new paragraph indention
        if (indentParagraphs > 0 && newParagraph)
           width -= [[NSString stringWithFormat:@"%C", 0x3000] sizeWithFont:gsFont].width * (float)indentParagraphs;

        // Remember the starting point for this line
        initLayout(&layouts[line], start, 0, newParagraph);

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
                // unichar c = ([text characterAtIndex:block.location]);

                // Handle \n - end of the line so to speak
                // (\n is always returned all by itself)
                if ([self isCRLF:block.location])
                {
                    // This CR/LF ends the line
                    layouts[line].range.length = block.location + block.length
                                                 - layouts[line].range.location;

                    // Move the start past the CR/LF
                    start = block.location + block.length;
                    break; // while this line
                }

                // If this is all blanks and the start of a line, ignore it
                if (!layouts[line].range.length &&
                    [self isBlank:block.location] &&
                    (!layouts[line].newParagraph || indentParagraphs >= 0))
                {
                    // Skip this ...
                    start = block.location + block.length;
                    continue;
                }

                // Figure out how large this block is
                NSRange linerange = {layouts[line].range.location,
                                     block.length + block.location - layouts[line].range.location};
                NSString * x = [text substringWithRange:linerange];
                lineused = [x sizeWithFont:gsFont];

                // Does this block carry us over?
                if (lineused.width > width)
                {
                    // If this block would fit in it's own line, we'll end this line
                    NSString * x = [text substringWithRange:block];
                    CGSize blockused = [x sizeWithFont:gsFont];
                    if (blockused.width <= width)
                        break;

                    // Figure out how much of this block will fit on this line
                    int maxlen = block.location + block.length - layouts[line].range.location;
                    for (layouts[line].range.length = 0;
                         (int)layouts[line].range.length < maxlen;
                         layouts[line].range.length++)
                    {
                        NSRange linerange = {layouts[line].range.location,
                                             layouts[line].range.length+1};
                        NSString * x = [text substringWithRange:linerange];
                        lineused = [x sizeWithFont:gsFont];

                        if (lineused.width > width)
                            break;

                    } // for each proposed character in the line

                    // Put the rest of the block on the next line ...
                    start = layouts[line].range.location + layouts[line].range.length;
                    break; // while this line

                }
                else
                {
                    // Room for this and more ... add this and keep going
                    layouts[line].range.length = block.location + block.length
                                                 - layouts[line].range.location;
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
int tidyRevLayout(TextLayout * layoutTop, int foundLines, int end)
{
    int line;

    // Tidy up the lines - make sure that they end before "end"
    for (line = 0; line < foundLines; line++)
    {
        if (end < (int)layoutTop[line].range.location)
            break;

        // Make sure an individual line doesn't include "end"
        if (end < (int)layoutTop[line].range.location +
                  (int)layoutTop[line].range.length - 1)
        {
            layoutTop[line].range.length = MAX(0, (end - (int)layoutTop[line].range.location) + 1);

            // If we adjust a layout we need to re-init it so that
            // the layout will be recalculated when it gets drawn
            initLayout(&layoutTop[line],
                       layoutTop[line].range.location,
                       layoutTop[line].range.length,
                       layoutTop[line].newParagraph);
        }

    } // for tidy up lines

    return line;

} // tidyRevLayout


// Going backwards, it tries to find a spot that marks a line end
// Right now this is when we find a 0x0a LF
// It could also be when we find a looong block of text w/o
// blanks, CR/LF, etc.
#define MAX_REV 2048
- (int) getRevStart:(int)end {

    int i;
    int start;

    // NOTE: This can get VERY expensive if we don't find an LF ...
    // Put in a kludge to stop it if things bog down
    for (start = end, i = 0;
         start > 0 && ![self isCRLF:start-1] &&
         i < MAX_REV;
         start--, i++);

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
- (int) doRevLayout:(int)lines layouts:(TextLayout *)layouts end:(int)end
{
    // Can't do layout before the start of the text ...
    if (!lines || end < 0 || ![text length])
        return 0;

    // Can't end past the actual last character ...
    if (end > (int)[text length])
        end = (int)[text length]-1;

    // OK - we need to lay out some lines ...
    TextLayout * layoutTop = layouts - (lines - 1);

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
        while ((int)layouts[0].range.location + (int)layouts[0].range.length < (int)[text length] && // JIMB BUG BUG - not really needed!!!
               (int)layouts[0].range.location + (int)layouts[0].range.length + 1 < end)
        {
            TextLayout nextLayout;

            initLayout(&nextLayout, 0, 0, 0); // not calculated yet!

            foundLines  = [self
                           doFwdLayout:1          // lines needed
                             layouts:&nextLayout  // where to put new lines
                               start:layouts[0].range.location + layouts[0].range.length];

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

    CGRect viewRect = [self getOrientedViewRect];

    int lineHeight  = [self getLineHeight];
    int lines       = ((int)viewRect.size.height / lineHeight) + 2;

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
    if (cLayouts && first >= 0 && first < cLayouts && deltaLine >= 0)
    {
        foundLines = cLayouts - first;

        // Copy these to the start
        memmove(&layout[0], &layout[first], sizeof(*layout)*foundLines);

        foundLines += [self
                       doFwdLayout:lines-foundLines    // lines needed
                         layouts:&layout[foundLines]   // where to put new lines
                           start:(int)layout[foundLines-1].range.location +  // character to start new layout
                                 (int)layout[foundLines-1].range.length];
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
                               end:(int)layout[lines-foundLines].range.location-1];  // character to start new layout

        if (foundLines < lines)
        {
            // Tricky ... this should never happen unless we hit the top
            // Copy what we did get to the top
            memmove(&layout[0], &layout[lines-foundLines], sizeof(*layout)*foundLines);

            // Try to get forward layout to fix the rest
            foundLines += [self
                           doFwdLayout:lines-foundLines    // lines needed
                             layouts:&layout[foundLines]   // where to put new lines
                               start:(int)layout[foundLines-1].range.location +  // character to start new layout
                                     (int)layout[foundLines-1].range.length];
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
                start = (int)layout[foundLines-1].range.location +
                        (int)layout[foundLines-1].range.length;
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
        cStart = MAX(0, MIN((int)layout[0].range.location, (int)[text length]-1));

    lStart += deltaLine;


    // Eliminate delta if we are at the top or bottom ...
    if (!cLayouts ||
        layout[0].range.location == 0 ||
        (int)layout[0].range.location + (int)layout[0].range.length >= (int)[text length]-1)
        yDelta = 0;

    // Special case page scroll - align text at the top
    // and don't display partial lines at bottom
    if (!isDrag || ![trApp getSwipeOK])
    {
        yDelta = 0;

        // Strip out the partial line at the bottom???
        if (cDisplay >= (int)viewRect.size.height / lineHeight)
            cDisplay = (int)viewRect.size.height / lineHeight;
    }

    [screenLock unlock];

    // Force a redraw using the new layout
    [self setNeedsDisplay];

} // doLayout


- (void) setTextAlignment:(AlignText)ta
{
    textAlignment = ta;

    // Force a new layout with the new alignment at the current position
    cLayouts = 0;
    [self doLayout:0];

} // setTextAlignment


- (void) setIgnoreSingleLF:(IgnoreLF)ignore {
    ignoreSingleLF = ignore;

    // Force a new layout with the new formatting at the current position
    cLayouts = 0;
    [self doLayout:0];
}

- (void) setPadMargins:(bool)pad {
    padMargins = pad;

    // Force a new layout with the new padding at the current position
    cLayouts = 0;
    [self doLayout:0];
}


- (void) setIndentParagraphs:(int)indent {
    indentParagraphs = indent;

    // Force a new layout with the new indention at the current position
    cLayouts = 0;
    [self doLayout:0];
}


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



- (void) scrollPage:(ScrollDir)dir
{
    isDrag = false;

    CGRect  viewRect = [self getOrientedViewRect];
    int lineHeight   = [self getLineHeight];

    int lines = (int)viewRect.size.height / lineHeight;

    lStart = 0;

    switch (dir)
    {
        case Page_Up:
            [self doLayout:(repeatLine ? -(lines-1) : -lines)];
            break;
        case Page_Down:
            [self doLayout:(repeatLine ? (lines-1) : lines)];
            break;
        case Line_Up:
            [self doLayout:-1];
            break;
        case Line_Down:
            [self doLayout:1];
            break;
    }

    // Reset the scroller to the center
    [self centerScrollerOffset];

} // scrollPage


// --------------------------------------------------------------


// Blech!!! Figure this properly!!!
- (int) getLineHeight {

    if (!gsFont)
        return 0;

    float height = [gsFont descender] + MAX(MAX([gsFont ascender], [gsFont capHeight]), [gsFont xHeight]);

    height *= 1.7;

    return (int)ceil(height);

} // getLineHeight


// Figure out how wide this line of text actually is ...
- (float) calcWidth:(NSString *)x {

    CGSize lineused = [x sizeWithFont:gsFont];

    return lineused.width;

} // calcWidth


// Draw string x justified starting at pt with layout
- (void) drawJustified:(TextLayout *)txtLayout at:(CGPoint)pt
{
    CGRect  viewRect = [self getOrientedViewRect];
    NSRange block;

    pt.x = ceil(pt.x);

    // Strip leading and trailing blanks
    if (!txtLayout->newParagraph || indentParagraphs >= 0)
    {
        while (txtLayout->range.length && [self isBlank:txtLayout->range.location])
        {
            txtLayout->range.location++;
            txtLayout->range.length--;
        }
    }
    while (txtLayout->range.length &&
           [self isBlank:txtLayout->range.location+txtLayout->range.length-1])
        txtLayout->range.length--;

    // Get the text to be added ...
    NSString * x = [text substringWithRange:txtLayout->range];

    // Nothing to do for completely blank lines ...
    if (!txtLayout->range.length)
        return;

    // If this line ends with a 0x0a, left align it
    if ([self isCRLF:txtLayout->range.location + txtLayout->range.length - 1])
    {
        [x drawAtPoint:pt withFont:gsFont];
        return;
    }

    // OK - we have to do it the hard way ...

    // Loop through the blocks in the text twice

    // The first time we count the number of blank blocks, and
    // add up the width of all of the non-blank blocks
    // (ignore CRLF blocks!)

    // NOTE: only do this once, and then cache the results ...
    if (txtLayout->blank_width < 0)
    {
        float   txt_width    = 0;
        int     blank_blocks = 0;

        // For Char align, we add space between characters
        if (textAlignment == Align_Justified2)
        {
            for (block.location = txtLayout->range.location, block.length = 1;
                 block.location < txtLayout->range.location + txtLayout->range.length;
                 block.location++)
            {
                // Ignore CRLF characters
                if ([self isCRLF:block.location])
                   continue;

                NSString * x = [text substringWithRange:block];
                CGSize  used = [x sizeWithFont:gsFont];
                txt_width += ceil(used.width);

            } // for each char in the range

            // We have one less blocks than characters
            blank_blocks = txtLayout->range.length - 1;
        }

        // For Word align, we add space between words
        else
        {
            for (block = txtLayout->range;
                 [self getFwdBlock:&block from:block.location] &&
                 block.location + block.length <= txtLayout->range.location + txtLayout->range.length;
                 block.location = block.location + block.length)
            {
                // Ignore CRLF characters
                if ([self isCRLF:block.location])
                   continue;

                if ([self isBlank:block.location])
                    blank_blocks++;
                else
                {
                    NSString * x = [text substringWithRange:block];
                    CGSize  used = [x sizeWithFont:gsFont];
                    txt_width += ceil(used.width);
                }

            } // for each block in txtLayout

        } // if/else alignment type

        // If no text found, all done
        if (txt_width == 0.0)
            return;

        // If no blanks were found, we will do a left justify
        if (blank_blocks < 1)
        {
            [x drawAtPoint:pt withFont:gsFont];
            return;
        }

        // Calc the blank offset for each blank block
        // (remember to keep track of partial blank pixels
        txtLayout->blank_width = viewRect.size.width - txt_width;

        // Keep the start and end points in mind ...
        txtLayout->blank_width -= pt.x;
        if (padMargins)
            txtLayout->blank_width -= TEXTREADER_MPAD;

        // NOTE: We *must* allow for a negative txtLayout->blank_width!!!
        //       This can happen if the layout of the line of text is
        //       shorter than the length of drawing each character separately!

        txtLayout->num_blanks = blank_blocks;

    } // if layout not already calc'd

    // Draw the text in a justified manner ...

    // For Char align, we add space between characters
    float blank_width = txtLayout->blank_width;
    float num_blanks  = txtLayout->num_blanks;

    if (textAlignment == Align_Justified2)
    {
        for (block.location = txtLayout->range.location, block.length = 1;
             block.location < txtLayout->range.location + txtLayout->range.length;
             block.location++)
        {
            // Ignore CRLF characters
            if ([self isCRLF:block.location])
               continue;

            // Draw each character
            NSString * x = [text substringWithRange:block];
            CGSize  used = [x drawAtPoint:pt withFont:gsFont];
            pt.x += ceil(used.width);

            // Move the offset for blank space ...
            if (num_blanks)
            {
                float pad    = blank_width / num_blanks;
                pt.x        += pad;
                blank_width -= pad;
                num_blanks--;
            }

        } // for each char in the range
    }
    else
    {
        // Loop through the blocks again and draw the text
        for (block = txtLayout->range;
             [self getFwdBlock:&block from:block.location] &&
             block.location + block.length <= txtLayout->range.location + txtLayout->range.length;
             block.location = block.location + block.length)
        {
            // Ignore CRLF characters
            if ([self isCRLF:block.location])
               continue;

            if ([self isBlank:block.location])
            {
                // Move the offset for blank space ...
                if (num_blanks)
                {
                    int pad      = blank_width / num_blanks;
                    pt.x        += pad;
                    blank_width -= pad;
                    num_blanks--;
                }
            }
            else
            {
                // Draw this block of text at the indicated spot
                NSString * x = [text substringWithRange:block];
                CGSize  used = [x drawAtPoint:pt withFont:gsFont];
                pt.x += ceil(used.width);
            }

        } // for each block in txtLayout
    }

} // drawJustified


- (void)drawRect:(struct CGRect)rect
{
    CGRect       viewRect   = [self getOrientedViewRect];
    CGContextRef context    = UICurrentContext();
    int          lineHeight = [self getLineHeight];
    CGRect       lineRect;

// JIMB BUG BUG - Figure out how to only redraw the invalid portion !!!

    // Figure out where we draw the text
    // This allows us to scroll partial lines

    int yStart = rect.origin.y - yDelta;

    // No text means nothing to do ...
    if (!text || ![text length] || !trApp || !gsFont)
    {
       // Blank screen ...
       lineRect = CGRectMake(0, yStart, viewRect.size.width, viewRect.size.height+lineHeight*2);

       [self fillBkgGroundRect:context rect:lineRect yOffset:rect.origin.y];

       return [super drawRect:rect];
    }

    [screenLock lock];

    // Always clear the first line ...
    lineRect = CGRectMake(0, rect.origin.y, viewRect.size.width, lineHeight);
    [self fillBkgGroundRect:context rect:lineRect yOffset:rect.origin.y];

    // Adjust start for status bar ...
    if ([trApp getShowStatus] != ShowStatus_Off)
    {
        yStart += [UIHardware statusBarHeight];
    }

    int yEnd   = yStart + rect.size.height;

    int line;

    for (line = 0; yStart <= yEnd; yStart += lineHeight, line++)
    {
        // This is where the line starts
        lineRect = CGRectMake(0, yStart, viewRect.size.width, lineHeight);

        // Blank out the line so we can draw the new text
        [self fillBkgGroundRect:context rect:lineRect yOffset:rect.origin.y];

        lineRect = CGRectMake(0, yStart, viewRect.size.width, lineHeight);

        // Nothing else to do if there is no text on this line
        if (line >= cDisplay || layout[line].range.location >= [text length])
           continue;

        // Figure out what we need to do to align this text ...
        // Get the substring for this "chunk" of text
        NSString * x = [text substringWithRange:layout[line].range];

        CGPoint    pt;
        pt.y = lineRect.origin.y;

        // pt.x depends on the justification
        switch (textAlignment)
        {
            case Align_Center:
                if (layout[line].width < 0)
                    layout[line].width = [self calcWidth:x];
                pt.x = (viewRect.size.width - layout[line].width) / 2;
                [x drawAtPoint:pt withFont:gsFont];
                break;

            case Align_Right:
                if (layout[line].width < 0)
                    layout[line].width = [self calcWidth:x];
                pt.x = viewRect.size.width - layout[line].width;
                if (layout[line].newParagraph && indentParagraphs > 0)
                    pt.x -= [[NSString stringWithFormat:@"%C", 0x3000] sizeWithFont:gsFont].width * (float)indentParagraphs;
                if (padMargins)
                    pt.x -= TEXTREADER_MPAD;
                [x drawAtPoint:pt withFont:gsFont];
                break;

            case Align_Justified:
            case Align_Justified2:
                // Apply margin padding
                pt.x = padMargins ? TEXTREADER_MPAD : 0;
                if (layout[line].newParagraph && indentParagraphs > 0)
                    pt.x += [[NSString stringWithFormat:@"%C", 0x3000] sizeWithFont:gsFont].width * (float)indentParagraphs;
                // Draw it in chunks
                [self drawJustified:&layout[line] at:pt];
                break;

            case Align_Left:
            default:
                pt.x = padMargins ? TEXTREADER_MPAD : 0;
                if (layout[line].newParagraph && indentParagraphs > 0)
                    pt.x += [[NSString stringWithFormat:@"%C", 0x3000] sizeWithFont:gsFont].width * (float)indentParagraphs;
                [x drawAtPoint:pt withFont:gsFont];
                break;

        } // switch on alignment

        // Draw the text at the point

        // Always blank the status bar field if being shown
        if (line == 0 && [trApp getShowStatus] != ShowStatus_Off)
        {
            lineRect = CGRectMake(0, rect.origin.y,
                                  viewRect.size.width,
                                  [UIHardware statusBarHeight]);
            [self fillBkgGroundRect:context rect:lineRect yOffset:rect.origin.y];
        }

    } // for each line of text we need to draw ...

    // Wipe any remaining text ...
    lineRect = CGRectMake(0, yStart, viewRect.size.width, lineHeight);
    [self fillBkgGroundRect:context rect:lineRect yOffset:rect.origin.y];


    [screenLock unlock];

    return [super drawRect:rect];

} // drawRect


- (void) sizeScroller {

    // No text - nothing to do ...
    if (!text || ![text length])
        return;

    CGRect fsrect = [self getOrientedViewRect];

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

    isDrag = false;

} // sizeScroller


- (void) setStart:(int)newStart {

    if (text)
    {
        // We treat 1 and 0 as both meaning the start (i.e. 0)
        // This allows us to tell if a default exists or not
        if (newStart <= 1)
            newStart = 0;

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



// findChar
// Returns offset of char or 0 if not found
NSUInteger getTag(NSString * str, NSUInteger start, NSUInteger end, char * upTag, char * lowTag)
{
    NSUInteger i, j;

    // 0 means search to the end
    if (!end || end > [str length])
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


static const unichar cvt1252[] = {8218, 402, 8222, 8230, 8224, 8225,
                                  0, 0, 352, 8249, 338, 0, 0, 0, 0,
                                  8216, 8217, 8220, 8221, 8226, 8211, 8212,
                                  0, 8482, 353, 250, 339, 0, 0, 376};

// Handle explicit references to bytes in CP1252
static unichar fix1252Char(unichar ch) {

    // These CP1252 characters do not map directly to UTF16
    // so we have to translate them ...
    if (ch >= 130 && ch <= 159)
        ch = cvt1252[ch-130];

    return ch;

} // fix1252Char


static int hexDigit(NSString * src, int pos)
{
    unichar c = [src characterAtIndex:pos];

    if (c >= '0' && c <= '9')
        return c - '0';
    else if (c >= 'A' && c <= 'F')
        return c - 'A';
    else if (c >= 'a' && c <= 'f')
        return c - 'a';
    else
        return 0;
} // hexDigit


// Replace some entities with characters more likely to be transcodable
static unichar patchEntity(unichar entity)
{
    // Quick patch job for a couple of entities
    if (entity == 0x00)
        entity = '?';   // Need to pick a better character here ...

    return entity;

} // patchEntity


// JIMB BUG BUG - rewrite this so it is sorted table driven!
// There are way more than I planned to support ...


// Adds the specified block of text from src to dest
// Removes CR/LF
// Converts &nbsp; &copy; &ndash; &mdash; &amp; &eacute;
// Adds other text "as-is"
void addHTMLText(NSString * src, NSRange rtext, NSMutableString * dest)
{
    int begining        = [dest length];
    NSRange addedBlanks = {begining, 1};
    NSRange added       = {begining, 1};

    // Add new text to the dest - we'll patch it up in place
    [dest appendString:[src substringWithRange:rtext]];

    // First:
    // Convert all consecutive blank space to a single blank
    // (this is done before the entities are expanded, so
    //  we won't mess up "real/intended" characters)
    while (addedBlanks.location < [dest length])
    {
        unichar c = [dest characterAtIndex:addedBlanks.location];

        // Convert tabs, 0x0d and 0x0a to blank space
        if (c == 0x0a || c == 0x0d || c == '\t')
        {
            [dest replaceCharactersInRange:addedBlanks withString:@" "];
            c = ' ';
        }

        // Strip multiple tab and blank characters
        if (c == ' ')
        {
            // If previous character is blankspace, delete this character
            // We only add a single blank at a time
            // (remember, cr/lf/tabs have already been turned into blanks!
            c = [dest characterAtIndex:addedBlanks.location-1];
            if (c == ' ')
                // delete this doubled blank
                [dest deleteCharactersInRange:addedBlanks];
            else
                // Leave this blank as is
                addedBlanks.location++;
        }
        else
            // Not blank space - move to the next char
            addedBlanks.location++;
    }


    // Second:
    // Now we need to Expand all character entities
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
                    int i;

                    // Convert the number to a unicode character - no validation!

                    // Hex or decimal?!?!?
                    c = [dest characterAtIndex:added.location+2];
                    if (c == 'x' || c == 'X')
                    {
                        for (i = 3; i < added.length; i++)
                        {
                            c = [dest characterAtIndex:added.location+i];
                            if (c == ';')
                                break;

                            entity = entity * 0x10 + hexDigit(dest, added.location+i);
                        }
                    }
                    else
                    {
                        for (i = 2; i < added.length; i++)
                        {
                            c = [dest characterAtIndex:added.location+i];
                            if (c == ';')
                                break;

                            if (c < '0' || c > '9')
                                break;

                            entity = entity * 10 + c - '0';
                        }
                   }

                   // This doesn't really seem right, but I've seen files that seem to
                   // want #151 mapped to a '-', so force it and hope for the best ...
                   entity = fix1252Char(entity);
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
                                case 'g':
                                    // gt       003E
                                    if (getTag(dest, added.location, added.location+added.length, "gt;", NULL))
                                        entity = 0x003E;
                                    break;

                                case 'l':
                                    // lt       003C
                                    if (getTag(dest, added.location, added.location+added.length, "lt;", NULL))
                                        entity = 0x003C;
                                    break;
                            }
                        break;

                        case 5:
                            switch([dest characterAtIndex:added.location+1])
                            {
                                case 'a':
                                    // amp      0026
                                    if (getTag(dest, added.location, added.location+added.length, "amp;", NULL))
                                        entity = 0x0026;
                                    break;

                                case 'd':
                                    // deg      00B0
                                    if (getTag(dest, added.location, added.location+added.length, "deg;", NULL))
                                        entity = 0x00B0;
                                    break;

                                case 'E':
                                    // ETH      00D0
                                    if (getTag(dest, added.location, added.location+added.length, "ETH;", NULL))
                                        entity = 0x00D0;
                                    break;

                                case 'e':
                                    // eth      00F0
                                    if (getTag(dest, added.location, added.location+added.length, "eth;", NULL))
                                        entity = 0x00F0;
                                    break;

                                case 'n':
                                    // not      00AC
                                    if (getTag(dest, added.location, added.location+added.length, "not;", NULL))
                                        entity = 0x00AC;
                                    break;

                                case 'r':
                                    // reg      00AE
                                    if (getTag(dest, added.location, added.location+added.length, "reg;", NULL))
                                        entity = 0x00AE;
                                    break;

                                case 's':
                                    // shy      00AD
                                    if (getTag(dest, added.location, added.location+added.length, "shy;", NULL))
                                        entity = 0x00AD;
                                    break;

                                case 'u':
                                    // uml      00A8
                                    if (getTag(dest, added.location, added.location+added.length, "uml;", NULL))
                                        entity = 0x00A8;
                                    break;

                                case 'y':
                                    // yen      00A5
                                    if (getTag(dest, added.location, added.location+added.length, "yen;", NULL))
                                        entity = 0x00A5;
                                    break;
                            }
                        break;

                        case 6:
                            switch([dest characterAtIndex:added.location+1])
                            {
                                case 'A':
                                    // Auml    00C4
                                    if (getTag(dest, added.location, added.location+added.length, "Auml;", NULL))
                                        entity = 0x00C4;
                                    break;

                                case 'a':
                                    // auml    00E4
                                    if (getTag(dest, added.location, added.location+added.length, "auml;", NULL))
                                        entity = 0x00E4;
                                    break;

                                case 'b':
                                    // bull     2022
                                    if (getTag(dest, added.location, added.location+added.length, "bull;", NULL))
                                        entity = 0x2022;
                                    break;

                                case 'c':
                                    // copy     00A9
                                    if (getTag(dest, added.location, added.location+added.length, "copy;", NULL))
                                        entity = 0x00A9;
                                    // cent     00A2
                                    else if (getTag(dest, added.location, added.location+added.length, "cent;", NULL))
                                        entity = 0x00A2;
                                    // circ     02C6
                                    else if (getTag(dest, added.location, added.location+added.length, "circ;", NULL))
                                        entity = 0x02C6;
                                    break;

                                case 'e':
                                    // emsp     2003
                                    if (getTag(dest, added.location, added.location+added.length, "emsp;", NULL))
                                        entity = 0x2003;
                                    // ensp     2002
                                    else if (getTag(dest, added.location, added.location+added.length, "ensp;", NULL))
                                        entity = 0x2002;
                                    // euro     20ac
                                    else if (getTag(dest, added.location, added.location+added.length, "euro;", NULL))
                                        entity = 0x20AC;
                                    // euml    00EB
                                    else if (getTag(dest, added.location, added.location+added.length, "euml;", NULL))
                                        entity = 0x00EB;
                                    break;

                                case 'E':
                                    // Euml    00CB
                                    if (getTag(dest, added.location, added.location+added.length, "Euml;", NULL))
                                        entity = 0x00CB;
                                    break;

                                case 'f':
                                    // fnof     0192
                                    if (getTag(dest, added.location, added.location+added.length, "fnof;", NULL))
                                        entity = 0x0192;
                                    break;

                                case 'I':
                                    // Iuml    00CF
                                    if (getTag(dest, added.location, added.location+added.length, "Iuml;", NULL))
                                        entity = 0x00CF;
                                    break;

                                case 'i':
                                    // iuml    00EF
                                    if (getTag(dest, added.location, added.location+added.length, "iuml;", NULL))
                                        entity = 0x00EF;
                                    break;

                                case 'm':
                                    // macr     00AF
                                    if (getTag(dest, added.location, added.location+added.length, "macr;", NULL))
                                        entity = 0x00AF;
                                    break;

                                case 'n':
                                    // nbsp     00A0
                                    if (getTag(dest, added.location, added.location+added.length, "nbsp;", NULL))
                                        entity = 0x00A0;
                                    break;

                                case 'o':
                                    // ordf     00AA
                                    if (getTag(dest, added.location, added.location+added.length, "ordf;", NULL))
                                        entity = 0x00AA;
                                    else
                                    // ordm     00BA
                                    if (getTag(dest, added.location, added.location+added.length, "ordm;", NULL))
                                        entity = 0x00BA;
                                    else
                                    // ouml    00F6
                                    if (getTag(dest, added.location, added.location+added.length, "ouml;", NULL))
                                        entity = 0x00F6;
                                    break;

                                case 'O':
                                    // Ouml    00D6
                                    if (getTag(dest, added.location, added.location+added.length, "Ouml;", NULL))
                                        entity = 0x00D6;
                                    break;

                                case 'p':
                                    // para     00B6
                                    if (getTag(dest, added.location, added.location+added.length, "para;", NULL))
                                        entity = 0x00B6;
                                    // sup2     00B2
                                    else if (getTag(dest, added.location, added.location+added.length, "sup2;", NULL))
                                        entity = 0x00B2;
                                    // sup3     00B3
                                    else if (getTag(dest, added.location, added.location+added.length, "sup3;", NULL))
                                        entity = 0x00B3;
                                    // sup1     00B9
                                    else if (getTag(dest, added.location, added.location+added.length, "sup1;", NULL))
                                        entity = 0x00B9;
                                    break;

                                case 'q':
                                    // quot     0022
                                    if (getTag(dest, added.location, added.location+added.length, "quot;", NULL))
                                        entity = 0x0022;
                                    break;

                                case 's':
                                    // sect     00A7
                                    if (getTag(dest, added.location, added.location+added.length, "sect;", NULL))
                                        entity = 0x00A7;
                                    break;

                                case 'U':
                                    // Uuml    00DC
                                    if (getTag(dest, added.location, added.location+added.length, "Uuml;", NULL))
                                        entity = 0x00DC;
                                    break;

                                case 'u':
                                    // uuml    00FC
                                    if (getTag(dest, added.location, added.location+added.length, "uuml;", NULL))
                                        entity = 0x00FC;
                                    break;

                                case 'Y':
                                    // Yuml     0178
                                    if (getTag(dest, added.location, added.location+added.length, "Yuml;", NULL))
                                        entity = 0x0178;
                                    break;

                                case 'y':
                                    // yuml     00FF
                                    if (getTag(dest, added.location, added.location+added.length, "yuml;", NULL))
                                        entity = 0x00FF;
                                    break;


                            }
                        break;

                        case 7:
                            switch([dest characterAtIndex:added.location+1])
                            {
                                case 'A':
                                    // Acirc    00C2
                                    if (getTag(dest, added.location, added.location+added.length, "Acirc;", NULL))
                                        entity = 0x00C2;
                                    else
                                    // Aring    00C5
                                    if (getTag(dest, added.location, added.location+added.length, "Aring;", NULL))
                                        entity = 0x00C5;
                                    else
                                    // AElig    00C6
                                    if (getTag(dest, added.location, added.location+added.length, "AElig;", NULL))
                                        entity = 0x00C6;
                                    break;

                                case 'a':
                                    // acute
                                    if (getTag(dest, added.location, added.location+added.length, "acute;", NULL))
                                        entity = 0x00B4;
                                    else
                                    // acirc    00E2
                                    if (getTag(dest, added.location, added.location+added.length, "acirc;", NULL))
                                        entity = 0x00E2;
                                    else
                                    // aring    00E5
                                    if (getTag(dest, added.location, added.location+added.length, "aring;", NULL))
                                        entity = 0x00E5;
                                    else
                                    // aelig    00E6
                                    if (getTag(dest, added.location, added.location+added.length, "aelig;", NULL))
                                        entity = 0x00E6;
                                    break;

                                case 'b':
                                    // bdquo    201E
                                    if (getTag(dest, added.location, added.location+added.length, "bdquo;", NULL))
                                        entity = 0x201E;
                                    break;

                                case 'c':
                                    // cedil    00B8
                                    if (getTag(dest, added.location, added.location+added.length, "cedil;", NULL))
                                        entity = 0x00B8;
                                    break;

                                case 'E':
                                    // Ecirc    00CA
                                    if (getTag(dest, added.location, added.location+added.length, "Ecirc;", NULL))
                                        entity = 0x00CA;
                                    break;

                                case 'e':
                                    // ecirc    00EA
                                    if (getTag(dest, added.location, added.location+added.length, "ecirc;", NULL))
                                        entity = 0x00EA;
                                    break;

                                case 'i':
                                    // iexcl    00A1
                                    if (getTag(dest, added.location, added.location+added.length, "iexcl;", NULL))
                                        entity = 0x00A1;
                                    else
                                    // icirc    00EE
                                    if (getTag(dest, added.location, added.location+added.length, "icirc;", NULL))
                                        entity = 0x00EE;
                                    break;

                                case 'I':
                                    // Icirc    00CE
                                    if (getTag(dest, added.location, added.location+added.length, "Icirc;", NULL))
                                        entity = 0x00CE;
                                    break;

                                case 'l':
                                    // ldquo    201C
                                    if (getTag(dest, added.location, added.location+added.length, "ldquo;", NULL))
                                        entity = 0x201C;
                                    // lsquo    2018
                                    else if (getTag(dest, added.location, added.location+added.length, "lsquo;", NULL))
                                        entity = 0x2018;
                                    // laquo    00AB
                                    else if (getTag(dest, added.location, added.location+added.length, "laquo;", NULL))
                                        entity = 0x00AB;
                                    break;

                                case 'm':
                                    // mdash    2014
                                    if (getTag(dest, added.location, added.location+added.length, "mdash;", NULL))
                                        entity = 0x2014;
                                    // micro    00B5
                                    else if (getTag(dest, added.location, added.location+added.length, "micro;", NULL))
                                        entity = 0x00B5;
                                    break;

                                case 'n':
                                    // ndash    2013
                                    if (getTag(dest, added.location, added.location+added.length, "ndash;", NULL))
                                        entity = 0x2013;
                                    break;

                                case 'O':
                                    // OElig    0152
                                    if (getTag(dest, added.location, added.location+added.length, "OElig;", NULL))
                                        entity = 0x0152;
                                    else
                                    // Ocirc    00D4
                                    if (getTag(dest, added.location, added.location+added.length, "Ocirc;", NULL))
                                        entity = 0x00D4;
                                    break;

                                case 'o':
                                    // oelig    0153
                                    if (getTag(dest, added.location, added.location+added.length, "oelig;", NULL))
                                        entity = 0x0153;
                                    else
                                    // ocirc    00F4
                                    if (getTag(dest, added.location, added.location+added.length, "ocirc;", NULL))
                                        entity = 0x00F4;
                                    break;

                                case 'p':
                                    // pound    00A3
                                    if (getTag(dest, added.location, added.location+added.length, "pound;", NULL))
                                        entity = 0x00A3;
                                    break;

                                case 'r':
                                    // rdquo    201D
                                    if (getTag(dest, added.location, added.location+added.length, "rdquo;", NULL))
                                        entity = 0x201D;
                                    // rsquo    2019
                                    else if (getTag(dest, added.location, added.location+added.length, "rsquo;", NULL))
                                        entity = 0x2019;
                                    // raquo    00BB
                                    else if (getTag(dest, added.location, added.location+added.length, "raquo;", NULL))
                                        entity = 0x00BB;
                                    break;

                                case 's':
                                    // sbquo    201A
                                    if (getTag(dest, added.location, added.location+added.length, "sbquo;", NULL))
                                        entity = 0x201A;
                                    else
                                    // szlig    00DF
                                    if (getTag(dest, added.location, added.location+added.length, "szlig;", NULL))
                                        entity = 0x00DF;
                                    break;

                                case 't':
                                    // tilde    02DC
                                    if (getTag(dest, added.location, added.location+added.length, "tilde;", NULL))
                                        entity = 0x02DC;
                                    else
                                    // trade    2122
                                    if (getTag(dest, added.location, added.location+added.length, "trade;", NULL))
                                        entity = 0x2122;
                                    else
                                    // times    00D7
                                    if (getTag(dest, added.location, added.location+added.length, "times;", NULL))
                                        entity = 0x00D7;
                                    else
                                    // thorn    00FE
                                    if (getTag(dest, added.location, added.location+added.length, "thorn;", NULL))
                                        entity = 0x00FE;
                                    break;

                                case 'T':
                                    // THORN    00DE
                                    if (getTag(dest, added.location, added.location+added.length, "THORN;", NULL))
                                        entity = 0x00DE;
                                    break;

                                case 'U':
                                    // Ucirc    00DB
                                    if (getTag(dest, added.location, added.location+added.length, "Ucirc;", NULL))
                                        entity = 0x00DB;
                                    break;

                                case 'u':
                                    // ucirc    00FB
                                    if (getTag(dest, added.location, added.location+added.length, "ucirc;", NULL))
                                        entity = 0x00FB;
                                    break;

                            }

                        break;

                        case 8:
                            switch([dest characterAtIndex:added.location+1])
                            {
                                case 'A':
                                    // Agrave    00C0
                                    if (getTag(dest, added.location, added.location+added.length, "Agrave;", NULL))
                                        entity = 0x00C0;
                                    else
                                    // Aacute    00C1
                                    if (getTag(dest, added.location, added.location+added.length, "Aacute;", NULL))
                                        entity = 0x00C1;
                                    else
                                    // Atilde    00C3
                                    if (getTag(dest, added.location, added.location+added.length, "Atilde;", NULL))
                                        entity = 0x00C3;
                                    break;

                                case 'a':
                                    // agrave    00E0
                                    if (getTag(dest, added.location, added.location+added.length, "agrave;", NULL))
                                        entity = 0x00E0;
                                    else
                                    // aacute    00E1
                                    if (getTag(dest, added.location, added.location+added.length, "aacute;", NULL))
                                        entity = 0x00E1;
                                    else
                                    // atilde    00E3
                                    if (getTag(dest, added.location, added.location+added.length, "atilde;", NULL))
                                        entity = 0x00E3;
                                    break;

                                case 'b':
                                    // brvbar    00A6
                                    if (getTag(dest, added.location, added.location+added.length, "brvbar;", NULL))
                                        entity = 0x00A6;
                                    break;

                                case 'c':
                                    // curren   00A4
                                    if (getTag(dest, added.location, added.location+added.length, "curren;", NULL))
                                        entity = 0x00A4;
                                    else
                                    // ccedil   00E7
                                    if (getTag(dest, added.location, added.location+added.length, "ccedil;", NULL))
                                        entity = 0x00E7;
                                    break;

                                case 'C':
                                    // Ccedil   00C7
                                    if (getTag(dest, added.location, added.location+added.length, "Ccedil;", NULL))
                                        entity = 0x00C7;
                                    break;

                                case 'D':
                                    // Dagger   2021
                                    if (getTag(dest, added.location, added.location+added.length, "Dagger;", NULL))
                                        entity = 0x2021;
                                    break;

                                case 'd':
                                    // dagger   2020
                                    if (getTag(dest, added.location, added.location+added.length, "dagger;", NULL))
                                        entity = 0x2020;
                                    else
                                    // divide   00F7
                                    if (getTag(dest, added.location, added.location+added.length, "divide;", NULL))
                                        entity = 0x00F7;
                                    break;

                                case 'E':
                                    // Egrave    00C8
                                    if (getTag(dest, added.location, added.location+added.length, "Egrave;", NULL))
                                        entity = 0x00C8;
                                    else
                                    // Eacute    00C9
                                    if (getTag(dest, added.location, added.location+added.length, "Eacute;", NULL))
                                        entity = 0x00C9;
                                    break;

                                case 'e':
                                    // egrave    00E8
                                    if (getTag(dest, added.location, added.location+added.length, "egrave;", NULL))
                                        entity = 0x00E8;
                                    else
                                    // eacute   00E9
                                    if (getTag(dest, added.location, added.location+added.length, "eacute;", NULL))
                                        entity = 0x00E9;
                                    break;

                                case 'f':
                                    // frac14   00BC
                                    if (getTag(dest, added.location, added.location+added.length, "frac14;", NULL))
                                        entity = 0x00BC;
                                    // frac12   00BD
                                    else
                                    if (getTag(dest, added.location, added.location+added.length, "frac12;", NULL))
                                        entity = 0x00BD;
                                    // frac34   00BE
                                    else
                                    if (getTag(dest, added.location, added.location+added.length, "frac34;", NULL))
                                        entity = 0x00BE;
                                    break;

                                case 'h':
                                    // hellip   2026
                                    if (getTag(dest, added.location, added.location+added.length, "hellip;", NULL))
                                        entity = 0x2026;
                                    break;

                                case 'i':
                                    // iquest   00BF
                                    if (getTag(dest, added.location, added.location+added.length, "iquest;", NULL))
                                        entity = 0x00BF;
                                    else
                                    // igrave    00EC
                                    if (getTag(dest, added.location, added.location+added.length, "igrave;", NULL))
                                        entity = 0x00EC;
                                    else
                                    // iacute    00ED
                                    if (getTag(dest, added.location, added.location+added.length, "iacute;", NULL))
                                        entity = 0x00ED;
                                    break;

                                case 'I':
                                    // Igrave    00CC
                                    if (getTag(dest, added.location, added.location+added.length, "Igrave;", NULL))
                                        entity = 0x00CC;
                                    else
                                    // Iacute    00CD
                                    if (getTag(dest, added.location, added.location+added.length, "Iacute;", NULL))
                                        entity = 0x00CD;
                                    break;

                                case 'l':
                                    // lsaquo   2039
                                    if (getTag(dest, added.location, added.location+added.length, "lsaquo;", NULL))
                                        entity = 0x2039;
                                    break;

                                case 'm':
                                    // middot   00B7
                                    if (getTag(dest, added.location, added.location+added.length, "middot;", NULL))
                                        entity = 0x00B7;
                                    break;

                                case 'N':
                                    // Ntilde    00D1
                                    if (getTag(dest, added.location, added.location+added.length, "Ntilde;", NULL))
                                        entity = 0x00D1;
                                    break;

                                case 'n':
                                    // ntilde    00F1
                                    if (getTag(dest, added.location, added.location+added.length, "ntilde;", NULL))
                                        entity = 0x00F1;
                                    break;

                                case 'O':
                                    // Ograve    00D2
                                    if (getTag(dest, added.location, added.location+added.length, "Ograve;", NULL))
                                        entity = 0x00D2;
                                    else
                                    // Oacute    00D3
                                    if (getTag(dest, added.location, added.location+added.length, "Oacute;", NULL))
                                        entity = 0x00D3;
                                    else
                                    // Otilde    00D5
                                    if (getTag(dest, added.location, added.location+added.length, "Otilde;", NULL))
                                        entity = 0x00D5;
                                    else
                                    // Oslash    00D8
                                    if (getTag(dest, added.location, added.location+added.length, "Oslash;", NULL))
                                        entity = 0x00D8;
                                    break;

                                case 'o':
                                    // ograve    00F2
                                    if (getTag(dest, added.location, added.location+added.length, "ograve;", NULL))
                                        entity = 0x00F2;
                                    else
                                    // oacute    00F3
                                    if (getTag(dest, added.location, added.location+added.length, "oacute;", NULL))
                                        entity = 0x00F3;
                                    else
                                    // otilde    00F5
                                    if (getTag(dest, added.location, added.location+added.length, "otilde;", NULL))
                                        entity = 0x00F5;
                                    else
                                    // oslash    00F8
                                    if (getTag(dest, added.location, added.location+added.length, "oslash;", NULL))
                                        entity = 0x00F8;
                                    break;

                                case 'p':
                                    // permil   2030
                                    if (getTag(dest, added.location, added.location+added.length, "permil;", NULL))
                                        entity = 0x2030;
                                    // plusmn   00B1
                                    else
                                    if (getTag(dest, added.location, added.location+added.length, "plusmn;", NULL))
                                        entity = 0x00B1;
                                    break;

                                case 'r':
                                    // rsaquo    203A
                                    if (getTag(dest, added.location, added.location+added.length, "rsaquo;", NULL))
                                        entity = 0x203A;
                                    break;

                                case 'S':
                                    // Scaron   0160
                                    if (getTag(dest, added.location, added.location+added.length, "Scaron;", NULL))
                                        entity = 0x0160;
                                    break;

                                case 's':
                                    // scaron   0161
                                    if (getTag(dest, added.location, added.location+added.length, "scaron;", NULL))
                                        entity = 0x0161;
                                    break;

                                case 'U':
                                    // Ugrave    00D9
                                    if (getTag(dest, added.location, added.location+added.length, "Ugrave;", NULL))
                                        entity = 0x00D9;
                                    else
                                    // Uacute    00DA
                                    if (getTag(dest, added.location, added.location+added.length, "Uacute;", NULL))
                                        entity = 0x00DA;
                                    break;

                                case 'u':
                                    // ugrave    00F9
                                    if (getTag(dest, added.location, added.location+added.length, "ugrave;", NULL))
                                        entity = 0x00F9;
                                    else
                                    // uacute    00FA
                                    if (getTag(dest, added.location, added.location+added.length, "uacute;", NULL))
                                        entity = 0x00FA;
                                    break;

                                case 'Y':
                                    // Yacute    00DD
                                    if (getTag(dest, added.location, added.location+added.length, "Yacute;", NULL))
                                        entity = 0x00DD;
                                    break;

                                case 'y':
                                    // yacute    00FD
                                    if (getTag(dest, added.location, added.location+added.length, "yacute;", NULL))
                                        entity = 0x00FD;
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
static bool openScript    = false;
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

        case 'L': case 'l':
            // <LI
            if (getTag(src, rtag.location, 2+rtag.location+1, "I>", "i>"))
                [dest appendFormat:@" %C ", (unichar)0x2022]; // bullet character
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

            // <script - look for </script to end the block ...
            else if (getTag(src, rtag.location, 6+rtag.location+1, "CRIPT>", "cript>") ||
                     getTag(src, rtag.location, 6+rtag.location+1, "CRIPT ", "cript "))
                openScript = true;
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
                    if (getTag(src, rtag.location+1, 10+rtag.location+1+1, "OOK-TITLE>", "ook-title>") ||
                        getTag(src, rtag.location+1, 10+rtag.location+1+1, "OOK-TITLE ", "ook-title "))
                        [dest appendString:@"\n\n\n"];
                    break;

//                  case 'D': case 'd':
//                      // </div
//                      if (getTag(src, rtag.location+1, 4+rtag.location+1+1, "DIV>", "div>") ||
//                          getTag(src, rtag.location+1, 4+rtag.location+1+1, "DIV ", "div "))
//                          [dest appendString:@"\n"];
//                      break;

                case 'L': case 'l':
                    // </LI
                    if (getTag(src, rtag.location+2, 2+rtag.location+1+1, "I>", "i>"))
                        [dest appendString:@"\n"]; // end this list item entry

                case 'H': case 'h':
                    // </H1
                    if (getTag(src, rtag.location+2, 2+rtag.location+1, "1>", "1 "))
                        [dest appendString:@"\n\n\n"];

                    // </H2 to </H6
                    else if (getTag(src, rtag.location+2, 2+rtag.location+1+1, "2>", "2 ") ||
                             getTag(src, rtag.location+2, 2+rtag.location+1+1, "3>", "3 ") ||
                             getTag(src, rtag.location+2, 2+rtag.location+1+1, "4>", "4 ") ||
                             getTag(src, rtag.location+2, 2+rtag.location+1+1, "5>", "5 ") ||
                             getTag(src, rtag.location+2, 2+rtag.location+1+1, "6>", "6 "))
                       [dest appendString:@"\n\n"];
                    break;

                case 'P': case 'p':
                    // </p
                    if (getTag(src, rtag.location+1, 2+rtag.location+1+1, "P>", "p>") ||
                        getTag(src, rtag.location+1, 2+rtag.location+1+1, "P ", "p "))
                    {
                        [dest appendString:@"\n"];
                        openParagraph = false;
                    }
                    break;

                case 'S': case 's':
                    // </section - treat like /H2
                    if (getTag(src, rtag.location+1, 7+rtag.location+1+1, "ECTION>", "ection>") ||
                        getTag(src, rtag.location+1, 7+rtag.location+1+1, "ECTION ", "ection "))
                        [dest appendString:@"\n\n"];

                    // </subtitle - treat like /H3
                    else if (getTag(src, rtag.location+1, 8+rtag.location+1+1, "UBTITLE>", "ubtitle>") ||
                             getTag(src, rtag.location+1, 8+rtag.location+1+1, "UBTITLE ", "ubtitle "))
                        [dest appendString:@"\n\n"];

                    // </script - close out <script tag ...
                    else if (getTag(src, rtag.location+1, 6+rtag.location+1+1, "CRIPT>", "cript>") ||
                             getTag(src, rtag.location+1, 6+rtag.location+1+1, "CRIPT ", "cript "))
                        openScript = false;
                    break;

                case 'T': case 't':
                    // </title - same as </H2
                    if (getTag(src, rtag.location+1, 5+rtag.location+1+1, "ITLE>", "itle>") ||
                        getTag(src, rtag.location+1, 5+rtag.location+1+1, "ITLE ", "itle "))
                        [dest appendString:@"\n\n"];
                    break;
           }
            break;

    } // switch on first char of tag

} // addHTMLTag


- (void) saveCache:(NSString*)newText {

    // Save the modified text ad Unicode so we don't have to reconvert, and don't have
    // to worry about encoding mismatches

    // Nothing to do if it is already a cache file ...
    if ([trApp getFileType:fileName] == kTextFileTypeTRCache)
        return;

    // This keeps us from having to go through this again
    // NOTE: Some times, directory permissions will make this impossible
    //       Don't pop a dialog since that will annoy people even more
    NSString *fullpath = [[filePath stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:TEXTREADER_CACHE_EXT];

    // Cache files are always written out as Unicode strings to prevent
    // transcoding problems ... we always load them the same way ...
    if ([newText writeToFile:fullpath atomically:NO encoding:NSUnicodeStringEncoding error:NULL])
    {
        // If we cached it, change the file name so we will reload it automatically
        NSString * tmp = [[fileName stringByAppendingPathExtension:TEXTREADER_CACHE_EXT] copy];
        [fileName release];
        fileName = tmp;
    }

} // saveCache


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
    openScript    = false;

    // Special case a check for the document starting with <BODY
    // The check below wouldn't find it because the offset would be 0

    // Look for the start of the body tag - we ignore everything before it
    rtag.location = getTag(src, 0, 0, "<BODY", "<body");

    // Always strip .html and .fb2 files (people like to produce HTML w/o a <body>
    // We only want to strip PDBs if they have a body
    if (rtag.location || ftype == kTextFileTypeHTML || ftype == kTextFileTypeFB2)
    {
        // Looks like we are going to do some stripping ... wild guess at final size
        newText = [[[NSMutableString alloc] initWithCapacity:[src length]/2] retain];
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
            // NOTE: Ignore text if we are in a <script> block!
            if (!openScript)
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

    // Cache this file to speed up future opens
    [self saveCache:newText];

} // stripHTML


- (void) closeCurrentFile {

    if (fileName)
        [fileName release];
    fileName = nil;

    [self setText:nil];

    [self setNeedsDisplay];

} // closeCurrentFile


// Strips out PML tags and produces ugly text for reading enjoyment ...
// NOTE: PML definitions from http://www.ereader.com/ereader/help/dropbook/pml.htm
- (void) stripPML:(NSMutableString  *)newText type:(TextFileType)ftype {

    unichar               c[8096];
    int                   cL     = 0;
    NSMutableString     * src    = newText;
    int                   pos    = 0;
    int                   i;

    // Create new mutable string for output ...
    newText = [[[NSMutableString alloc] initWithCapacity:[src length]] retain];

    // Loop through the text copying until we hit a back slash '\'
    for (pos = 0; pos < [src length]; pos++)
    {
        unichar cur = [src characterAtIndex:pos];
        if (pos < [src length]-1 && cur == '\\')
        {
            // get the next character
            unichar nextchar = [src characterAtIndex:pos+1];
            switch (nextchar)
            {
                case '\\': // a single backslash character
                    c[cL++] = cur;
                    pos ++;
                    break;

                case 'x': // double - New chapter; also causes a new page break
                case 'p': // single - New page
                    c[cL++] = 0x0a;
                    c[cL++] = 0x0a;
                    pos ++;
                    break;


                // All of these get tossed
                case 't': // double - indent block of text
                case 'n': // single - use normal font
                case 's': // double - use standard font
                case 'b': // double - use bold font
                case 'l': // double - use large font
                case 'B': // double - Bold the text
                case 'k': // double - Small caps
                case 'c': // double - center block of text
                case 'r': // double - right justify block of text
                case 'i': // double - italicize block of text
                case 'u': // double - underline block of text
                case 'o': // double - overstrike block of text
                case 'I': // double - reference item
                case '-': // single - soft hyphen
                    pos ++;
                    break;

                case 'a': // single - \aXXX - insert decimal character XXX (in WIN1252 CP)
                    if (pos+4 < [src length])
                    {
                        unichar x = ([src characterAtIndex:pos+3]-'0')*100  +
                                    ([src characterAtIndex:pos+4]-'0')*10   +
                                    ([src characterAtIndex:pos+5]-'0');

                        // This specifies a CP1252 char rather than UTF16, so
                        // handle the mapping if needed ...
                        c[cL++] = fix1252Char(x);
                    }
                    break;

                case 'U': // single - \UXXXX - insert decimal character XXXX (in Unicode)
                    if (pos+5 < [src length])
                    {
                        c[cL++] = hexDigit(src, pos+2)*0x1000 +
                                  hexDigit(src, pos+3)*0x100  +
                                  hexDigit(src, pos+4)*0x10   +
                                  hexDigit(src, pos+5);
                    }
                    break;

                case 'C': // single - Cn="Chapter Title" - invisible - just adds to table of contents
                case 'T': // single - \T="50%" - indent screen percentage
                case 'w': // single - \w="50%" - embed horizontal rule screen percentage (LF before and after)
                case 'm': // single - image - \m="imagename.png"
                case 'Q': // single - specify a link anchor - \Q="linkanchor"
                    // Skip these ...
                    // Find the end of the link and skip this text
                    // (i.e. go to the second double quote character)
                    for (i = 0, pos+=2; pos < [src length]; pos++)
                    {
                        if ([src characterAtIndex:pos] == '"')
                            i++;
                        if (i == 2)
                            break;
                    }
                    break;

                case 'S': // double - Sp - superscript
                          // double - Sb - subscript
                          // double - Sd - sidebar - \Sd="sidebar1"Sidebar\Sd
                case 'X': // double - Xn - New chapter - no new page break (indent)
                case 'v': // double - invisible block of text
                case 'q': // double - link anchor - \q="#linkanchor"Some text\q
                case 'F': // double - footnote - \Fn="footnote1"1\Fn
                    // Skip these ...
                    // Find the next occurrence of this tag
                    for (pos+=2; pos < [src length]; pos++)
                    {
                        if ([src characterAtIndex:pos]   == nextchar &&
                            [src characterAtIndex:pos-1] == '\\')
                            break;
                    }
                    // move past the extra character for \S
                    if (nextchar == 'S')
                        pos++;
                    break;

                default:
                    // No clue ... Strip the \ and move on ...
                    break;
            }

        }
        else
        {
            // If this isn't a backslash esace, just add it and move on
            c[cL++] = cur;
        }

        // Dump buffer when it gets full
        // Leave a bit of space for expanded replacements
        if (cL >= sizeof(c)/sizeof(*c)-32)
        {
            [newText appendFormat:@"%.*S", cL, c];
            cL = 0;
        }

    } // for

    // Add any remaining text in the block
    if (cL)
    {
        [newText appendFormat:@"%.*S", cL, c];
        cL = 0;
    }

    // Free the source newText ...
    [src release];

    // Replace the open text with this new text and refresh the screen
    [self setText:newText];

    // Cache this file to speed up future opens
    [self saveCache:newText];

} // stripPML


// ---------------------------------------------
// Thread specific code ...
// ---------------------------------------------

- (NSMutableString *)dataToString:(NSData *)data {

    NSMutableString * newText = nil;

    int i;
    for (i = 0; i < sizeof(encodings)/sizeof(*encodings); i++)
    {
        NSStringEncoding encoding = encodings[i];

        if (encoding)
        {
            newText = [[[NSMutableString alloc] initWithData:data encoding:encoding] retain];
            if (newText)
               break;
        }

    } // for each encoding ...

    return newText;

} // dataToString


// Load an RTF doc as data, and then convert it to a string
- (NSMutableString*)openRTFFile:(NSString*)fullpath type:(TextFileType*)ftype {

    NSMutableString * newText = nil;

    RTFDOC rtfdoc = {0};

    rtfdoc.src  = [[NSData dataWithContentsOfMappedFile:fullpath] retain];
    rtfdoc.dest = [[NSMutableData alloc] initWithCapacity:4096];

    if (rtfdoc.src && rtfdoc.dest)
    {
        if (ecRtfParse(&rtfdoc) == ecOK)
            newText = [self dataToString:rtfdoc.dest];
    }

    if (rtfdoc.src)
        [rtfdoc.src release];

    if (rtfdoc.dest)
        [rtfdoc.dest release];

    *ftype = kTextFileTypeRTF;

    return newText;

} // openRTFFile


// Load a PDB doc as data and then convert it to a string
- (NSMutableString*) openPDBFile:(NSString*)fullpath type:(TextFileType*)ftype {

    NSMutableString * newText = nil;
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
                                           @"%@ \"%@\" %@ \"%@\".\n%@ %@\n%@",
                                           _T(@"The format of"),
                                           fullpath,
                                           _T(@"is"),
                                           type, TEXTREADER_NAME,
                                           _T(@"is only able to open unencrypted Mobipocket, Plucker, and Palm Doc PDB files."),
                                           _T(@"Sorry ...")
                                           ];
            [trApp showDialog:_T(@"Unable to Open PDB File!")
                            msg:errorMsg
                         buttons:DialogButtons_OK];

            return false;
        }
    }
    else
    {
        int i;
        for (i = 0; i < sizeof(encodings)/sizeof(*encodings); i++)
        {
            NSStringEncoding encoding = encodings[i];

            if (encoding)
            {
                newText = [[[NSMutableString alloc] initWithData:data encoding:encoding] retain];
                if (newText)
                   break;
            }
        }
    }

    if (data)
        [data release];

    // Set the file type ...
    if (![type compare:@"eReader" options:kCFCompareCaseInsensitive])
       *ftype = kTextFileTypePML;

    // Check the PDB for HTML - We'll consider anything with
    // a < and a > in the first 128 characters an HTML doc
    else if ( newText &&
              ([newText characterAtIndex:0] == '<' ||
               (getTag(newText, 0, 256, "<", NULL) &&
                getTag(newText, 0, 256, ">", NULL))) )
       *ftype = kTextFileTypeHTML;

    return newText;

} // openPDBFile



- (NSMutableString*) openTextFile:(NSString*)fullpath type:(TextFileType*)ftype {

    NSMutableString * newText = nil;

    int i;

    for (i = 0; i < sizeof(encodings)/sizeof(*encodings); i++)
    {
        NSStringEncoding encoding = encodings[i];

        if (encoding)
        {
            // Read in the text file - let NSMutableString do the work
            newText = [[NSMutableString
                        stringWithContentsOfFile:fullpath
                        encoding:encoding
                        error:nil] retain];
            if (newText)
               break;
        }
    }

    return newText;

} // opentextFile


- (NSMutableString*) openCacheFile:(NSString*)fullpath type:(TextFileType*)ftype {

    NSMutableString * newText = nil;

    // Cache files always use default Unicode encoding ...
    newText = [[NSMutableString
                stringWithContentsOfFile:fullpath
                encoding:NSUnicodeStringEncoding
                error:nil] retain];

    // From here on, treate cache files as text files ...
    *ftype = kTextFileTypeTXT;

    return newText;

} // opentextFile


// Open specified file and display
- (bool) openFile:(NSString *)name path:(NSString*)path {
    NSMutableString * newText = nil;
    // NSError         * error   = nil;

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

        switch (ftype)
        {
            // Cache files are always UTF16BE encoding ...
            case kTextFileTypeTRCache:
                newText = [self openCacheFile:fullpath type:&ftype];
                break;

            case kTextFileTypePDB:
                // Open a PDB file
                newText = [self openPDBFile:fullpath type:&ftype];
                break;

            case kTextFileTypeRTF:
                // Open an RTF file
                newText = [self openRTFFile:fullpath type:&ftype];
                break;

            case kTextFileTypeTXT:
            case kTextFileTypeHTML:
            case kTextFileTypeFB2:
            default:
                // everything else gets loaded as a plain old text file
                newText = [self openTextFile:fullpath type:&ftype];
                break;
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

            // Strip PML in a similar fashion to what we do with HTML ...
            if (ftype == kTextFileTypePML)
            {
                [self stripPML:newText type:ftype];

                // All done - file will be reopened when stripPML finishes
                return true;
            }

            // Otherwise, no massaging of the text is needed ...
            // Save the new text for view
            [self setText:newText];

            // Always Cache RTF text to keep us from having to parse it again ...
            // Cache all files if they told us to ...
            if (ftype == kTextFileTypeRTF || cacheAll)
                [self saveCache:newText];

            return true;

        } // if newText

    } // if name

    // We had an error if we got here ...
    NSString *errorMsg = [NSString stringWithFormat:
                                   @"%@ \"%@\" %@ \"%@\"%@\n%@ %@ %@",
                                   _T(@"Unable to open file"),
                                   name,
                                   _T(@"in directory"),
                                   path,
                                   _T(@".dir_suffix"), // Just a "." in most languages ...
                                   _T(@"Please make sure the directory and file exist, the read permissions are set, and the file is really in"),
// JIMB BUG BUG - change this!!!
                                   [trApp stringFromEncoding:encodings[0]],
// JIMB BUG BUG - change this!!!
                                   _T(@"encoding.")];
    [trApp showDialog:_T(@"Error opening file")
                    msg:errorMsg
                 buttons:DialogButtons_OK];

    return false;

} // openFile


- (NSStringEncoding*)getEncodings {
    return encodings;
} // getEncodings


- (bool)setEncodings:(NSStringEncoding*)enc {

    memcpy(encodings, enc, sizeof(encodings));

    // Default initial encoding ...
    if (!encodings[0])
        encodings[0] = NSMacOSRomanStringEncoding;

    // // HACK/KLUDGE to get things to sort of work
    // encodings[0] = NSISOLatin1StringEncoding;

    return true;

} // setEncodings


// typedef enum {
//     kGSFontTraitNone = 0,
//     kGSFontTraitItalic = 1,
//     kGSFontTraitBold = 2,
//     kGSFontTraitBoldItalic = (kGSFontTraitBold | kGSFontTraitItalic)
// } GSFontTrait;


- (bool)setFont:(NSString*)newFont size:(int)size {

    // struct __GSFont * newgsFont;
    UIFont * newgsFont = nil;

    if (!newFont || [newFont length] < 1)
        newFont = @"arialuni";
    if (size < 10)
        size = 10;
    if (size > 34)
        size = 34;

    // newgsFont = GSFontCreateWithName([newFont cStringUsingEncoding:kCGEncodingMacRoman], 0, size);
    newgsFont = [[UIFont fontWithName:newFont size:size] retain];
    if (newgsFont)
    {
        [font release];
        font = [newFont copy];
        fontSize = size;
        gsFont = newgsFont;

        [self sizeScroller];
        // SizeScroller will force a redraw

        return true;
    }

    [trApp showDialog:_T(@"Error")
                    msg:[NSString stringWithFormat:_T(@"Unable to create font %@"), newFont]
                 buttons:DialogButtons_OK];

    return false;

} // setFont


- (int)getFontSize {
    return fontSize;
} // getFontSize

- (NSString *)getFont {
    return font;
} // getFont


- (void)mouseDown:(struct __GSEvent*)event {

    gestureMode = false;

    [ [self tapDelegate] mouseDown: event ];
    [ super mouseDown: event ];

} // mouseDown


- (void)mouseUp:(struct __GSEvent *)event {

    if (!gestureMode)
        [ [self tapDelegate] mouseUp: event ];

    [ super mouseUp: event ];

} // mouseUp


- (bool)getIsDrag {

    return isDrag;

} // getIsDrag


- (void)mouseDragged:(struct __GSEvent *)event
{
    // We use this to disable scrolling as needed
    //if ([trApp getSwipeOK])
    //{
        isDrag = true;
        [super mouseDragged:event];
    //}

} // mouseDragged


- (void) endDragging {

    // Clear the flag so we know dragging is finished
    isDrag = false;
    gestureMode = false;

} // endDragging


// Keep current page up to date
- (void) scrollerDidEndDragging:(id)id  willSmoothScroll:(BOOL)scr
{
    [self endDragging];

} // scrollerDidEndDragging



// continuous scroll events when moving
- (void) scrollerDidScroll: (id) id
{
    if (!text)
        return;

    if (![trApp getSwipeOK])
       return;

    isDrag = true;

    // Figure new line based on slider offset
    // CGPoint start = [self dragStartOffset];
    CGPoint offset = [self offset];

    // Keep track of partial line offset
    yDelta = (int)offset.y % [self getLineHeight];

    // This is the line offset from the initial scroll position
    int delta = (int)(offset.y - yDelta - SCROLLER_SIZE) /  [self getLineHeight] ;

    // Do layout for the new line
    // We moved current-start pixels from cStart
    [self doLayout:delta];

    [trApp showPercentage];


} // scrollerDidScroll



@end // @implementation MyTextView

