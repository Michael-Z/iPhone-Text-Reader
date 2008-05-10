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



#import <UIKit/UIKit.h>
#import <UIKit/NSString-UIStringDrawing.h>
#import <CoreGraphics/CGGeometry.h>
#import <WebCore/WebFontCache.h>
#import <UIKit/UIAlertSheet.h>
#import <UIKit/UIViewTapInfo.h>
#import <UIKit/UIView-Geometry.h>
#import <UIKit/UISliderControl.h>
#import <UIKit/UINavBarButton.h>
#import <UIKit/UIProgressHUD.h>
#import <UIkit/UIProgressIndicator.h>


#import "UIOrientingApplication.h"

#define TEXTREADER_NAME     		@"textReader"
#define TEXTREADER_VERSION  		@"0.6.0Beta5"
#define TEXTREADER_CACHE_EXT        @"text"

#define TEXTREADER_DEF_PATH 		@"/var/mobile/Media/textReader/"
#define TEXTREADER_PARENT_DIR 		@".."
#define TEXTREADER_DOWNLOAD_TITLE   @"Download File via URL"

#define TEXTREADER_DFLT_FONT   		@"CourierNewBold"
#define TEXTREADER_DFLT_FONTSIZE 	20
#define TEXTREADER_DFLT_ENCODING 	kCGEncodingMacRoman


#define TEXTREADER_COLOR    		@"color"
#define TEXTREADER_IGNORELF 		@"ignoreLF"
#define TEXTREADER_PADMARGINS 		@"padMargins"
#define TEXTREADER_REVERSETAP 		@"reverseTap"
#define TEXTREADER_SWIPE     		@"swipeOK"

#define TEXTREADER_OLOCKED     		@"oLocked"
#define TEXTREADER_OCODE     		@"oCode"

#define TEXTREADER_FONT 			@"font"
#define TEXTREADER_FONTSIZE 		@"fontSize"
#define TEXTREADER_ENCODING 		@"encoding"

#define TEXTREADER_OPENFILE 		@"OpenFileName"
#define TEXTREADER_OPENPATH    		@"OpenFilePath"

#define TEXTREADER_SLIDERSCALE 		256

//#define TEXTREADER_GB2312			-2312
//#define TEXTREADER_GB2312_NAME		@"Simplified Chinese (GB2312)"


typedef enum _TextFileType {
	kTextFileTypeUnknown = 0,
	kTextFileTypeTXT  = 1,
	kTextFileTypePDB  = 2,
	kTextFileTypeHTML = 3,
	kTextFileTypeFB2  = 4
} TextFileType;


@class FileTable;
@class MyTextView;
@class MyPreferencesTable;
@class MyDownloadTable;


// *****************************************************************************
typedef enum _MyViewName {
	My_No_View,
	My_Info_View,
	My_Text_View,
	My_File_View,
	My_Prefs_View,
	My_Download_View
} MyViewName;

@interface textReader : UIOrientingApplication {

	UIWindow                *mainWindow;
	UITransitionView		*transView;

	MyTextView              *textView;

	UINavigationBar 		*navBar;
	UINavBarButton          *settingsBtn;
	UINavBarButton          *lockBtn;

	UISliderControl         *slider;

	FileTable 				*fileTable;

	MyPreferencesTable      *prefsTable;

	MyDownloadTable         *downloadTable;

	UIProgressHUD			*wait;

	CGPoint         		 mouseDown;

	CGPoint				     offset;
	bool				     isInDragMode;

	int             		 currentOrientation;
	bool              		 reverseTap;
	bool              		 swipe;
	MyViewName				 currentView;

	bool					 orientationInitialized;

	// KLUDGE to try to get wait HUD working
	NSString                *openname;
	NSString                *openpath;

	NSUserDefaults			*defaults;
}

- (void) applicationDidFinishLaunching: (id) unused;
- (id)   init;
- (void) applicationWillSuspend;
- (void) loadDefaults;
- (void) openFile:(NSString *)name path:(NSString *)path;
- (int)  getDefaultStart:(NSString*)name;
- (void) setDefaultStart:(NSString*)name start:(int)startChar;
- (void) removeDefaults:(NSString*)name;

- (void) setReverseTap:(bool)rtap;
- (bool) getReverseTap;

- (void) setSwipe:(bool)sw;
- (bool) getSwipe;

- (void) mouseDown:(struct __GSEvent*)event;
- (void) mouseUp:(struct __GSEvent *)event;
- (void)mouseDragged: (struct __GSEvent *)event;

- (void) showWait;
- (void) hideWait;

- (void) showView:(MyViewName)viewName;

- (struct CGSize) getOrientedViewSize;
- (struct CGRect) getOrientedViewRect;
- (CGPoint)getOrientedPoint:(CGPoint)loc;

- (CGPoint) getOrientedEventLocation:(struct __GSEvent *)event;
- (NSString*) getFileName;
- (NSString*) getFilePath;

- (TextFileType) getFileType:(NSString*)fileName;

- (void) redraw;

@end  // textReader : UIOrientingApplication

