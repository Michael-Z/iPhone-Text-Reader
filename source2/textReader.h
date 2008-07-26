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
#import <UIKit/UISlider.h>
#import <UIKit/UISegmentedControl.h>
#import <UIKit/UIProgressHUD.h>
#import <UIKit/UIProgressIndicator.h>
#import <UIKit/UISearchBar.h>
#import <Celestial/AVSystemController.h>

#import <UIKit/UIEvent.h>
#import <UIKit/UITouch.h>
#import <UIKit/UIColor.h>

#import "UIOrientingApplication.h"


#define _T(x) NSLocalizedString(x,nil)

#define TEXTREADER_HOMEPAGE         @"http://code.google.com/p/iphonetextreader/"
#define TEXTREADER_NAME             @"textReader"
#define TEXTREADER_VERSION          @"2.1 Beta 4"

#define TEXTREADER_CACHE_EXT        @"trCache"

#define TEXTREADER_DEF_PATH         @"/var/mobile/Media/textReader/"
#define TEXTREADER_PARENT_DIR       @".."
#define TEXTREADER_DOWNLOAD_TITLE   _T(@"Download File via URL")

#define TEXTREADER_DFLT_FONT        @"CourierNewBold"
#define TEXTREADER_DFLT_FONTSIZE    20
#define TEXTREADER_DFLT_ENCODING    /* kCGEncodingMacRoman */ NSISOLatin1StringEncoding


#define TEXTREADER_INVERTCOLORS     @"color"        // This is really invert!
#define TEXTREADER_IGNORELF         @"ignoreLF"
#define TEXTREADER_PADMARGINS       @"padMargins"
#define TEXTREADER_INDENT           @"indentParagraph"
#define TEXTREADER_REPEATLINE       @"repeatLine"
#define TEXTREADER_REVERSETAP       @"reverseTap"
#define TEXTREADER_SWIPE            @"swipeOK"
#define TEXTREADER_SHOWSTATUS       @"showStatus"
#define TEXTREADER_TEXTALIGNMENT    @"textAlignment"
#define TEXTREADER_SHOWCOVERART     @"showCoverArt"
#define TEXTREADER_FONTZOOM         @"fontZoom"
#define TEXTREADER_BKGIMAGE         @"bkgImage"
#define TEXTREADER_CACHEALL         @"cacheAll"
#define TEXTREADER_FILESCROLL       @"fileScroll"
#define TEXTREADER_DELETECACHEDIR   @"deleteCacheDir"

#define TEXTREADER_SEARCHWRAP       @"searchWrap"
#define TEXTREADER_SEARCHWORD       @"searchWord"

#define TEXTREADER_VOLSCROLL        @"volScroll"

#define TEXTREADER_OLOCKED          @"oLocked"
#define TEXTREADER_OCODE            @"oCode"

#define TEXTREADER_FONT             @"font"
#define TEXTREADER_FONTSIZE         @"fontSize"
#define TEXTREADER_ENCODING         @"encoding"
#define TEXTREADER_ENCODING2        @"encoding2"
#define TEXTREADER_ENCODING3        @"encoding3"
#define TEXTREADER_ENCODING4        @"encoding4"

#define TEXTREADER_OPENFILE         @"OpenFileName"
#define TEXTREADER_OPENPATH         @"OpenFilePath"

#define TEXTREADER_LASTSEARCH       @"lastSearch"

#define TEXTREADER_LASTURL          @"lastURL"
#define TEXTREADER_LASTURLSAVEAS    @"lastURLSaveAs"
#define TEXTREADER_REMEMBERURL      @"rememberURL"

#define TEXTREADER_TEXTRED          @"textRed"
#define TEXTREADER_TEXTGREEN        @"textGreen"
#define TEXTREADER_TEXTBLUE         @"textBlue"
#define TEXTREADER_TEXTALPHA        @"textAlpha"

#define TEXTREADER_BKGRED           @"bkgRed"
#define TEXTREADER_BKGGREEN         @"bkgGreen"
#define TEXTREADER_BKGBLUE          @"bkgBlue"
#define TEXTREADER_BKGALPHA         @"bkgAlpha"

#define TEXTREADER_SLIDERSCALE      256

#define TEXTREADER_ENC_NONE         0
#define TEXTREADER_ENC_NONE_NAME    _T(@"No Encoding Specified")



@class FileTable;
@class MyTextView;
@class MyPreferencesTable;
@class MyColorTable;
@class MyDownloadTable;



// *****************************************************************************
// Enums that are used all over ...
typedef struct _MyColors {

    float text_red;
    float text_green;
    float text_blue;
    float text_alpha;

    float bkg_red;
    float bkg_green;
    float bkg_blue;
    float bkg_alpha;

} MyColors;

typedef enum _TextFileType {
    kTextFileTypeUnknown = 0,
    kTextFileTypeTXT     = 1,
    kTextFileTypePDB     = 2,
    kTextFileTypeHTML    = 3,
    kTextFileTypeFB2     = 4,
    kTextFileTypeTRCache = 5,
    kTextFileTypePML     = 6,
    kTextFileTypeRTF     = 7,
    kTextFileTypeCHM     = 8,
    kTextFileTypeZIP     = 9,
    kTextFileTypeRAR     = 10
} TextFileType;

typedef enum _MyViewName {
    My_No_View,
    My_Info_View,
    My_Text_View,
    My_File_View,

    My_Prefs_View,
    My_Text_Prefs_View,
    My_Display_Prefs_View,
    My_Scroll_Prefs_View,
    My_Other_Prefs_View,

    My_Color_View,
    My_Download_View
} MyViewName;

typedef enum _ScrollDir {
    Page_Up,
    Page_Down,
    Line_Up,
    Line_Down
} ScrollDir;

typedef enum _AlignText {
    Align_Left       = 0,
    Align_Center     = 1,
    Align_Right      = 2,
    Align_Justified  = 3,
    Align_Justified2 = 4
} AlignText;

typedef enum _VolScroll {
    VolScroll_Off  = 0,
    VolScroll_Line = 1,
    VolScroll_Page = 2
} VolScroll;

typedef enum _IgnoreLF {
    IgnoreLF_Off    = 0,
    IgnoreLF_Single = 1,
    IgnoreLF_Format = 2
} IgnoreLF;

typedef enum _FileScroll {
    FileScroll_Off    = 0,
    FileScroll_RtoL   = 1,
    FileScroll_LtoR   = 2
} FileScroll;

typedef enum _DialogButtons {
    DialogButtons_None        = 0x00,
    DialogButtons_OK          = 0x01,
    DialogButtons_Website     = 0x02,
    DialogButtons_OKWebsite   = 0x03,
    DialogButtons_DeleteCache = 0x04
} DialogButtons;


typedef struct _TREncoding {
    NSStringEncoding   encoding;
    NSString         * name;
} TREncoding;


// *****************************************************************************

@interface textReader : UIOrientingApplication {

    UIWindow                *mainWindow;
    UITransitionView        *transView;

    UIView                  *baseTextView;
    MyTextView              *textView;

    UINavigationBar         *navBar;
    UINavigationItem        *navItem;
//    UINavBarButton          *settingsBtn;
//    UINavBarButton          *lockBtn;
//    UINavBarButton          *searchBtn;
//    UINavBarButton          *bookmarkBtn;
    UISegmentedControl      *toolBar;
    UITextLabel             *percent;
    UIImageView             *coverArt;

    // UISearchField           *searchBox;
    UISearchBar             *searchBox;
    UIKeyboard              *keyboard;
    NSString                *lastSearch;

    UISlider                *slider;

    FileTable               *fileTable;

    MyPreferencesTable      *prefsTable;

    MyColorTable            *colorTable;

    MyDownloadTable         *downloadTable;

    UIProgressHUD           *wait;

    CGPoint                  mouseDown;

    int                      currentOrientation;
    MyViewName               currentView;

    bool                     orientationInitialized;

    bool                     reverseTap;
    bool                     swipeOK;
    VolScroll                volScroll;
    ShowStatus               showStatus;
    bool                     showCoverArt;
    FileScroll               fileScroll;
    bool                     deleteCacheDir;

    bool                     searchWrap;
    bool                     searchWord;
    bool                     rememberURL;

    // Initial volume - we'll try to restore this level if possible
    float                    initVol;

    // Current volume - we return to this when we scroll up/down
    float                    curVol;

    // Has the user pressed vol up/down since the timer started?
    bool                     volChanged;

    // Count of volume presses - we debounce the first one
    int                      volPressed;

    // KLUDGE to try to get wait HUD working
    NSString                *openname;
    NSString                *openpath;

    UIAlertSheet            *okDialog;

    NSUserDefaults          *defaults;
    DialogButtons            dlgButtons;

} // @interface textReader : UIOrientingApplication


- (void) applicationDidFinishLaunching: (id) unused;
- (id)   init;
- (void) applicationWillSuspend;
- (void) loadDefaults;
- (void) closeCurrentFile;
- (void) openFile:(NSString *)name path:(NSString *)path;
- (int)  getDefaultStart:(NSString*)name;
- (void) setDefaultStart:(NSString*)name start:(int)startChar;
- (void) removeDefaults:(NSString*)name;

- (void) setRememberURL:(bool)remember;
- (bool) getRememberURL;

- (void) setReverseTap:(bool)rtap;
- (bool) getReverseTap;

- (void) setSwipeOK:(bool)sw;
- (bool) getSwipeOK;

- (void) setDeleteCacheDir:(bool)dcd;
- (bool) getDeleteCacheDir;

- (void) setSearchWrap:(bool)sw;
- (bool) getSearchWrap;

- (void) setSearchWord:(bool)sw;
- (bool) getSearchWord;

- (void) setVolScroll:(VolScroll)vs;
- (VolScroll) getVolScroll;

- (void) setShowStatus:(ShowStatus)ss;
- (ShowStatus) getShowStatus;

- (void) setShowCoverArt:(bool)show;
- (bool) getShowCoverArt;

- (void) setFileScroll:(FileScroll)fs;
- (FileScroll) getFileScroll;

- (void) mouseDown:(struct __GSEvent*)event;
- (void) mouseUp:(struct __GSEvent *)event;

- (void) showWait;
- (void) hideWait;

- (void) showView:(MyViewName)viewName;
- (MyViewName) getCurrentView;

// - (struct CGSize) getOrientedViewSize;
- (struct CGRect) getOrientedViewRect;
- (CGPoint)getOrientedPoint:(CGPoint)loc;

- (CGPoint) getOrientedEventLocation:(struct __GSEvent *)event;
- (NSString*) getFileName;
- (NSString*) getFilePath;

- (TextFileType) getFileType:(NSString*)fileName;

- (void) showFileTable:(NSString*)path;

- (void) redraw;

- (void) releaseDialog;
- (UIAlertSheet*) showDialog:(NSString*)title msg:(NSString*)msg buttons:(DialogButtons)buttons;
- (UIAlertSheet*) getDialog;

- (NSString *)stringFromEncoding:(NSStringEncoding)enc;
- (NSStringEncoding)encodingFromString:(NSString *)string;

- (void) scaleImage:(UIImageView*)image maxheight:(int)maxheight maxwidth:(int)maxwidth yOffset:(int)yOffset;
- (NSString *) getCoverArt:(NSString *)fname path:(NSString*)path;

- (void) rememberOpenFile:(NSString*)name path:(NSString*)path;

- (NSMutableArray *) getVisibleFiles:(NSString *)path;

- (void) showPercentage;

@end  // textReader : UIOrientingApplication

