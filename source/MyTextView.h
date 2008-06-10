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



#import <UIKit/UIKit.h>
#import <UIKit/NSString-UIStringDrawing.h>
#import <CoreGraphics/CGGeometry.h>
#import <WebCore/WebFontCache.h>
#import <UIKit/UIAlertSheet.h>
#import <UIKit/UIViewTapInfo.h>
#import <UIKit/UIView-Geometry.h>
#import <UIKit/UISliderControl.h>


// Prototype for the PDB decode function
int decodePDB(NSString * src, NSMutableData ** dest, NSString ** type);



// This is the number of scroll positions above and below the "current" location on the slider
// We have to use an arbitrary value because we don't know how many lines are in a file,
// and it can change due to formatting, font changes, screen rotations, etc.
// Changing the values on the fly while scrolling causes redraw scrolling glitches, and is wasteful
// We pick this value because it is 8 significant digits (safe for a double), /2 because we need
// a block above and below "current", and /100 to allow for the text height/font size multiplier
// This is considerably larger than any user is ever likely to scroll, and whenever a file is
// opened, closed, font or size changes, or slider is moved we will reset the thumb to current
#define SCROLLER_SIZE   (99999999/200)

#define TEXTREADER_MPAD             10

#define MAX_LAYOUTS                128


// This represents information about the layout of a single line
typedef struct _TextLayout {
    // Range of characters in "text" for this line
    NSRange range;

    // Used for center and right aligned text
    // Width of the line when drawn with the current font
    int     width;

    // Used for Justified aligned text
    // number of pixels for each blank block
    int blank_per_block;

    // Number of "extra" blank pixels that need to be consumed
    int blank_slop;

} TextLayout;


@class textReader;

// *****************************************************************************
@interface MyTextView : UIScroller {

    textReader       *trApp;
    NSLock           *screenLock;

    NSMutableString  *text;

    NSStringEncoding  encoding;
    NSString         *font;
    struct __GSFont  *gsFont;
    int               fontSize;

    bool              invertColors;

    bool              ignoreSingleLF;
    bool              padMargins;
    bool              repeatLine;
    AlignText         textAlignment;

    NSString         *filePath;
    NSString         *fileName;


    // Used while drawing text
    TextLayout        layout[MAX_LAYOUTS];
    int               cLayouts;             // Number of lines laid out in layout
    int               cDisplay;             // Max number of lines to actually display
                                            // (should always be <= cLayouts)
    int               lStart;
    int               cStart;               // Starting char of First *complete* line in current page
                                            // generally the same as layout[0].location
    int               yDelta;               // partial line offset from scrolling

    bool              isDrag;

    MyColors          txtcolors;
}

- (void) setTextReader:(textReader*)tr;

- (id)   init;
- (id)   initWithFrame:(CGRect)rect;

- (void) fillBkgGroundRect:(CGContextRef)context rect:(CGRect)rect;
- (void) setInvertColors:(bool)newInvertColors;
- (bool) getInvertColors;
- (void) setIgnoreSingleLF:(bool)ignore;
- (bool) getIgnoreSingleLF;
- (void) setPadMargins:(bool)pad;
- (bool) getPadMargins;
- (void) setRepeatLine:(bool)repeat;
- (bool) getRepeatLine;
- (void) setTextAlignment:(AlignText)ta;
- (AlignText) getTextAlignment;

- (void) closeCurrentFile;
- (bool)              openFile:(NSString *)name path:(NSString *)path;
- (NSMutableString *) getText;
- (void)              setStart:(int)newStart;
- (int)               getStart;
- (NSString*)         getFileName;
- (NSString*)         getFilePath;

- (NSString *)getFont;
- (bool)setFont:(NSString*)newFont size:(int)size;

- (NSStringEncoding)getEncoding;
- (bool)setEncoding:(NSStringEncoding)enc;

- (int)getFontSize;
- (int)getLineHeight;

- (bool)getIsDrag;

- (void) sizeScroller;

- (void) scrollPage:(ScrollDir)dir;

- (void) setTextColors:(MyColors*)newcolors;
- (MyColors) getTextColors;

@end // MyTextView : UIView


