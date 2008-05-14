
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


@class textReader;

// *****************************************************************************
@interface MyTextView : UIView {

	textReader   	 *trApp;
	NSLock	         *screenLock;

	NSMutableString  *text;
	int               start;
	int               end;
	int		          lineStart[480]; //Added by Allen Li
	int		    	  backLineStart[480]; //Added by Allen Li
	int		    	  currentBackLine;

	NSStringEncoding  encoding;
	NSStringEncoding  gb2312enc;
	NSString         *font;
	struct __GSFont  *gsFont;
	float             fontSize;
	int               color;

	bool              ignoreNewLine;
	bool              padMargins;

	NSString         *filePath;
	NSString         *fileName;

	// bool              pageUp;
}

- (void) setTextReader:(textReader*)tr;

- (id)   init;
- (id)   initWithFrame:(CGRect)rect;

- (void) fillBkgGroundRect:(CGContextRef)context rect:(CGRect)rect;
- (void) setColor:(int)newColor;
- (int)  getColor;
- (void) setIgnoreNewLine:(bool)ignore;
- (bool) getIgnoreNewLine;
- (void) setPadMargins:(bool)pad;
- (bool) getPadMargins;

- (void) pageUp;
- (void) pageDown;
-(void) moveDown:(int)moveLines; //Added by Allen Li
-(void) moveUp:(int)moveLines; //Added by Allen Li
-(void) dragText:(int)offset; //Added by Allen Li
-(int) calcLines:(int)tStart lookingEnd:(int) tEnd; //Added by Allen Li
-(int) lookingBackForCRLF:(int)start limitation:(int)searchLength; //Added by Allen Li
-(void) moveUpByDrawingBack:(int)moveLines textEnd:(int)tEnd; //Added by Allen Li


- (bool)              openFile:(NSString *)name path:(NSString *)path;
- (NSMutableString *) getText;
- (void)              setStart:(int)newStart;
- (int)               getStart;
- (int)               getEnd;
- (NSString*)         getFileName;
- (NSString*)         getFilePath;

- (NSString *)getFont;
- (int) getFontHeight; //Added by Allen Li
- (bool)setFont:(NSString*)newFont size:(int)size;

- (NSStringEncoding)getEncoding;
- (bool)setEncoding:(NSStringEncoding)enc;

- (int)getFontSize;

- (void) mouseDown:(struct __GSEvent*)event;
- (void) mouseUp:(struct __GSEvent *)event;

@end // MyTextView : UIView


