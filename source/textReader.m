//
//
//   textReader.app -  kludged up by Jim Beesley 
//   This incorporates inspiration, code, and examples from (among others)
//   * http://iphonedevdoc.com/index.php - random hints
//   * jYopp - http://jyopp.com/iphone.php - UIOrientingApplication example
//   * mxweas - UITransitionView example
//   * thebends.org - textDrawing example
//   * "iPhone Open Application Development" by Jonathan Zdziarski - FileTable/UIDeletableCell/Preferences example
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
#import "UIDeletableCell.h"
#import "PrefsTable.h"
#import "DownloadTable.h"




// *****************************************************************************
// This is the "main" GUI application ...
@implementation textReader




- (id) init {   

	defaults = [[NSUserDefaults standardUserDefaults] retain];
	
	currentOrientation 	= -9999;
	transView  			= nil;
	textView  			= nil;
	fileTable           = nil;
	prefsTable          = nil;
	downloadTable       = nil;
	navBar    			= nil;
	slider              = nil;
	currentView         = My_No_View;
	mouseDown           = CGPointMake(-1,-1);

	[super init];
} // init

- (NSString*) getFileName {
	return [textView getFileName];
}

- (NSString*) getFilePath {
	return [textView getFilePath];
}

- (void) removeDefaults:(NSString*)name {
	if (name)
	{
		// Remove start char for this file
		[defaults removeObjectForKey:name];
		
		// If this is the current open file, remove the OpenFileName entry 
		// so we won't get an error when we exit and start
		if ([name isEqualToString:[defaults stringForKey:TEXTREADER_OPENFILE]])
		{
			[defaults removeObjectForKey:TEXTREADER_OPENPATH];			
			[defaults removeObjectForKey:TEXTREADER_OPENFILE];			
		}
	}
} // removeDefaults


// Write current preferences and clean up
- (void) applicationWillSuspend {

	[defaults setInteger:[textView getColor] forKey:TEXTREADER_COLOR];
	
	[defaults setInteger:[textView getIgnoreNewLine] forKey:TEXTREADER_IGNORELF];

	[defaults setInteger:[textView getPadMargins] forKey:TEXTREADER_PADMARGINS];

	[defaults setObject:[textView getFont] forKey:TEXTREADER_FONT];

	[defaults setInteger:[textView getFontSize] forKey:TEXTREADER_FONTSIZE];

	// Save currently open book so we can reopen it later
	NSString * fileName = [textView getFileName];
	if (fileName)
	{
		NSString * filePath = [textView getFilePath];
		if (!filePath)
			filePath = TEXTREADER_DEF_PATH;
			
		[defaults setObject:fileName forKey:TEXTREADER_OPENFILE];
		[defaults setObject:filePath forKey:TEXTREADER_OPENPATH];
		[self setDefaultStart:fileName start:[textView getStart]];
	}
		
} // applicationWillSuspend


- (int) getDefaultStart:(NSString*)name {
	if (name)
		return [defaults integerForKey:name];
	return 0;
} // getDefaultStart


- (void) setDefaultStart:(NSString*)name start:(int)startChar {
	[defaults setInteger:startChar forKey:name];
} // setDefaultStart


- (void) loadDefaults {

	// Restore general prefs
	[textView setColor:[defaults integerForKey:TEXTREADER_COLOR]];

	[textView setIgnoreNewLine:[defaults integerForKey:TEXTREADER_IGNORELF]];

	[textView setPadMargins:[defaults integerForKey:TEXTREADER_PADMARGINS]];

	// Restore font prefs
	int fontSize = [defaults integerForKey:TEXTREADER_FONTSIZE];
	if (fontSize < 1 || fontSize > 40)
		[textView setFontSize:TEXTREADER_DFLT_FONTSIZE];
	else
		[textView setFontSize:fontSize];

	NSString * font = [defaults stringForKey:TEXTREADER_FONT];
	if (!font || [font length] < 4)
		[textView setFont:TEXTREADER_DFLT_FONT];
	else
		[textView setFont:font];

	// Open last opened file at last position
	NSString * path = [defaults stringForKey:TEXTREADER_OPENPATH];
	NSString * name = [defaults stringForKey:TEXTREADER_OPENFILE];
	if (name)
		[self openFile:name path:path start:[self getDefaultStart:name]];
	else
		[self showView:My_Info_View];
	
} // loadDefaults


- (void) showView:(MyViewName)viewName
{
	struct CGRect FSrect     = [self getOrientedViewRect];
	struct CGSize navSize    = [UINavigationBar defaultSize];
	struct CGSize viewSize   = [self getOrientedViewSize];
	
	switch (viewName)
	{
		case My_No_View:
			break;
			
		case My_Download_View:
			if (currentView != My_Download_View)
			{			
				// A view with a Status Bar, NavBar and Table
				UIView * downloadView = [[UIView alloc ] initWithFrame:FSrect];;
				[downloadView setAutoresizingMask: kMainAreaResizeMask];
				[downloadView setAutoresizesSubviews: YES];

				FSrect.origin.y += [UIHardware statusBarHeight];
				FSrect.size.height = [UINavigationBar defaultSize].height;
				UINavigationBar * downloadBar	= [[UINavigationBar alloc] initWithFrame:FSrect];
				[downloadBar setBarStyle: 0];
				[downloadBar showButtonsWithLeft: @"Done" right:nil leftBack: YES];
				[downloadBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle: @"Download File via URL"]];
				[downloadBar setAutoresizingMask: kTopBarResizeMask];
				
				FSrect = [self getOrientedViewRect];
				FSrect.origin.y    += [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
				FSrect.size.height -= [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
				downloadTable = [ [ MyDownloadTable alloc ] initWithFrame:FSrect];
				[downloadTable setTextReader:self];
				//[downloadTable setTextView:textView];
				[downloadTable reloadData];
				
				[downloadBar setDelegate:downloadTable];

				[downloadView addSubview:downloadBar];	
				[downloadView addSubview:downloadTable];

				[super hideStatus: false];
			
				// Switch views
				[transView transition:1 toView:downloadView];
				currentView = My_Download_View;

				[self redraw];
			}
			break;
			
		case My_Prefs_View:
			if (currentView != My_Prefs_View)
			{			
				// A view with a Status Bar, NavBar and Table
				UIView * prefsView = [[UIView alloc ] initWithFrame:FSrect];;
				[prefsView setAutoresizingMask: kMainAreaResizeMask];
				[prefsView setAutoresizesSubviews: YES];

				FSrect.origin.y += [UIHardware statusBarHeight];
				FSrect.size.height = [UINavigationBar defaultSize].height;
				UINavigationBar * prefsBar	= [[UINavigationBar alloc] initWithFrame:FSrect];
				[prefsBar setBarStyle: 0];
				[prefsBar showButtonsWithLeft: @"Done" right:@"About" leftBack: YES];
				[prefsBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle: @"Settings"]];
				[prefsBar setAutoresizingMask: kTopBarResizeMask];
				
				FSrect = [self getOrientedViewRect];
				FSrect.origin.y    += [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
				FSrect.size.height -= [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
				prefsTable = [ [ MyPreferencesTable alloc ] initWithFrame:FSrect];
				[prefsTable setTextReader:self];
				[prefsTable setTextView:textView];
				[prefsTable reloadData];
				
				[prefsBar setDelegate:prefsTable];

				[prefsView addSubview:prefsBar];	
				[prefsView addSubview:prefsTable];

				[super hideStatus: false];
			
				// Switch views
				[transView transition:1 toView:prefsView];
				currentView = My_Prefs_View;

				[self redraw];
			}
			break;
			
		case My_File_View:
			if (currentView != My_File_View)
			{			
				// A view with a Status Bar, NavBar and Table
				UIView * fileView = [[UIView alloc ] initWithFrame:FSrect];;
				[fileView setAutoresizingMask: kMainAreaResizeMask];
				[fileView setAutoresizesSubviews: YES];

				FSrect.origin.y += [UIHardware statusBarHeight];
				FSrect.size.height = [UINavigationBar defaultSize].height;
				UINavigationBar * fileBar	= [[UINavigationBar alloc] initWithFrame:FSrect];
				[fileBar setBarStyle: 0];
				[fileBar setDelegate: self];
				[fileBar showButtonsWithLeft: @"Back" right: nil leftBack: YES];
				[fileBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle: @"Open Text File"]];
				[fileBar setAutoresizingMask: kTopBarResizeMask];
				
				FSrect = [self getOrientedViewRect];
				FSrect.origin.y    += [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
				FSrect.size.height -= [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
				fileTable = [ [ FileTable alloc ] initWithFrame:FSrect];

				if ([textView getFilePath])
					[fileTable setPath:[textView getFilePath]];
				else
					[fileTable setPath:TEXTREADER_DEF_PATH];
				
				[fileTable setTextReader:self];
				[fileTable reloadData];
				
				[fileView addSubview:fileBar];	
				[fileView addSubview:fileTable];

				[super hideStatus: false];
				
				// Switch views
				[transView transition:1 toView:fileView];
				currentView = My_File_View;
				
				[self redraw];
			}
			break;
			
		case My_Info_View:
			if (currentView != My_Info_View)
			{				
				struct CGRect navBarRect = CGRectMake(0, [UIHardware statusBarHeight], viewSize.width, navSize.height);

				[super hideStatus: false];
				
				// Rescale in case of rotation
				[textView setBounds:[transView bounds]];
				[navBar setFrame: navBarRect];
				[navBar setAlpha:1];
				
				// Handle the slider if we have text loaded
				if ([textView getText])
				{
					navBarRect.origin.y = FSrect.size.height - navBarRect.size.height;
					[slider setFrame: navBarRect];
					[slider setMaxValue:[[textView getText] length]];
					[slider setValue:[textView getStart]];	
					[slider setAlpha:1];
				}
				else
					[slider setAlpha:0];

				// Switch views
				[transView transition:1 toView:textView];
				currentView = My_Info_View;
				
				fileTable = nil;
				prefsTable = nil;
				downloadTable = nil;
				
				[self redraw];
			}
			break;
			
		case My_Text_View:
			if (currentView != My_Text_View)
			{
				struct CGRect navBarRect = CGRectMake(0, [UIHardware statusBarHeight], viewSize.width, navSize.height);
				
				// Rescale in case of rotation
				[super hideStatus: true];
				[textView setBounds:[transView bounds]];
				[navBar setFrame: navBarRect];
				[navBar setAlpha:0];
				[slider setAlpha:0];
				
				// Switch views
				if (currentView == My_File_View)
					[transView transition:1 toView:textView];
				else
					[transView transition:2 toView:textView];
				currentView = My_Text_View;
				
				fileTable = nil;
				prefsTable = nil;
				downloadTable = nil;
				
				[self redraw];				
			}
			break;

	} // switch on viewName
	
} // showView


- (void) applicationDidFinishLaunching: (id) unused {

	[self setUIOrientation: [UIHardware deviceOrientation:YES]];

	struct CGRect FSrect = [self getOrientedViewRect];
	   
	// Initialize the main window 
	UIWindow *mainWindow = [[UIWindow alloc] initWithContentRect: FSrect];
	[mainWindow orderFront: self];
	[mainWindow makeKey: self];
	[mainWindow _setHidden: false];
	[mainWindow setAutoresizingMask: kMainAreaResizeMask];
	[mainWindow setAutoresizesSubviews: YES];


	// Main view holds other views ...
	transView = [[[UITransitionView alloc] initWithFrame: FSrect] retain];
	[transView setAutoresizingMask: kMainAreaResizeMask];
	[transView setAutoresizesSubviews: YES];
	[mainWindow setContentView: transView];

	// Go ahead and create the text view window we will
	// draw text onto ... that way we know it always exists
	textView = [[[MyTextView alloc] initWithFrame: FSrect] retain];	
	[textView setAutoresizingMask: kMainAreaResizeMask];
	[textView setTapDelegate: self];
	[textView setTextReader:self];
	
	struct CGSize navSize    = [UINavigationBar defaultSize];
	struct CGSize viewSize   = [self getOrientedViewSize];
	struct CGRect navBarRect = CGRectMake(0, [UIHardware statusBarHeight], viewSize.width, navSize.height);

	navBar	= [[[UINavigationBar alloc] initWithFrame: navBarRect] retain];
	[navBar setBarStyle: 0];
	[navBar setDelegate: self];
	[navBar showButtonsWithLeft: @"Open" right: @"Settings" leftBack: YES];
	[navBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle:TEXTREADER_NAME]];
	[navBar setAutoresizingMask: kTopBarResizeMask];	
    [navBar setAlpha:0];
	[textView addSubview:navBar];	
	
	
	navBarRect.origin.y = FSrect.size.height - navBarRect.size.height;
	slider = [[UISliderControl alloc] initWithFrame:navBarRect];
    float backParts[4] = {0, 0, 0, .5};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    [slider setBackgroundColor: CGColorCreate(colorSpace, backParts)];
    [slider setAlpha:0];
	[slider setShowValue:NO];
	[slider addTarget:self action:@selector(handleSlider:) forEvents:7]; // 7=drag, 2=up
	[slider setMinValue:0];
	[navBar setAutoresizingMask: kTopBarResizeMask];	
	[textView addSubview:slider];	
	
	[super setInitialized: true];	

	[self loadDefaults];	
	
} // applicationDidFinishLaunching


- (void) handleSlider: (id)whatever
{
	[textView setStart:[slider value]];
} // handleSlider


// Get rect of rotated window
- (struct CGRect) getOrientedViewRect {
	struct CGRect FSrect;
 	
 	// 0==horizontal(portrait), 90/-90==vertical(landscape)
	if ([super getOrientation])
		FSrect = CGRectMake(0, 0, 480, 320);
	else
		FSrect = CGRectMake(0, 0, 320, 480);
		
	return FSrect;
} // getOrientedViewRect


// Get height and width in rotated window
- (struct CGSize) getOrientedViewSize {
	return [self getOrientedViewRect].size;
} // getOrientedViewSize


// Handle changes in orientation
- (void)deviceOrientationChanged:(GSEvent*)event {
	[super deviceOrientationChanged: event];
	int newO = [UIHardware deviceOrientation: YES];
	if (newO > 6 || newO < 0) 
	   return;
} // deviceOrientationChanged


// Here's the recommended method for doing custom stuff when the screen's rotation has changed... 
- (void) setUIOrientation: (int) o_code {
	[super setUIOrientation: o_code];
	
	if (![super isInitialized] || ([super getOrientation] == currentOrientation))
		return;
	
	currentOrientation = [super getOrientation];

	// Resize the slider since it doesn't get it for free ...
 	CGRect FSrect = [self getOrientedViewRect];
 	CGRect rect = [slider frame];
 	rect.size.width = FSrect.size.width;
 	rect.origin.y = FSrect.size.height - rect.size.height;
 	[slider setFrame: rect];
//  	[slider setBounds: rect];
//   	[slider sliderBoundsChanged];
// 	[slider setMinValue: 10];
// 	[slider setMinValue: 0];
// 	if ([textView getText])
// 	{
// // JIMB BUG BUG figure out how to get this to update when we rotate!!!
// // Is it easier to just recreate it every time ?!?!?!?
// 		[slider setMaxValue:[[textView getText] length]];
// 		[slider setValue:[textView getStart]];	
// 	}
// 	[slider drawSliderInRect:rect];

	// Resize the navbar as well
	rect = [navBar frame];
	rect.origin.y = [UIHardware statusBarHeight];
	rect.size.width = FSrect.size.width;
	[navBar setFrame:rect];
	
	// Force a screen update
	[self redraw];
	
} // setUIOrientation


// Figure out point location in rotated window
- (CGPoint)getOrientedPoint:(CGPoint)loc {
	struct CGSize viewSize = [self getOrientedViewSize];
	int angle = [super getOrientation];

	// coordinates are correct for orientation==0
	if (angle == 90) // on right side
		loc = CGPointMake(loc.y, viewSize.height - loc.x);
	else if (angle == -90) // on left side
		loc = CGPointMake(viewSize.width - loc.y, loc.x);
	
	return loc;
} // getOrientedEventLocation


// Figure out where user clicked in rotated window
- (CGPoint)getOrientedEventLocation:(struct __GSEvent *)event {
	return [self getOrientedPoint:GSEventGetLocationInWindow(event)];
} // getOrientedEventLocation


// Handle mouse down - remember the position
- (void)mouseDown:(struct __GSEvent*)event {
	mouseDown = [self getOrientedEventLocation:event];
} // mouseDown
 
 
// Handle mouse up
- (void)mouseUp:(struct __GSEvent *)event {

	CGPoint mouseUp = [self getOrientedEventLocation:event];
 	struct CGSize viewSize = [self getOrientedViewSize];
	
	int upper = viewSize.height / 3;
	int lower = viewSize.height * 2 / 3;
	
	// Ignore ups w/o downs ...
	if (mouseDown.x < 0 || mouseDown.y < 0)
		return;
	
	// If no text loaded, show the bar and keep it up
	if (!textView || ![textView getText])
	{
		[self showView:My_Info_View];
	}
	else
	{
		// A tap in an info view means return to text
		if (currentView == My_Info_View)
		{
			[self showView:My_Text_View];
		}
		
		// Tap in a text view means scroll or show info
		else if (currentView == My_Text_View)
		{
			// Both upper  = page back
			if (mouseDown.y < upper && mouseUp.y < upper)
			{
				// Move up one page 
				[textView pageUp];
			}

			// Both lower  = page forward
			else if (mouseDown.y > lower && mouseUp.y > lower)
			{
				// Move down one page 
				[textView pageDown];
			}

			// Both middle = show/hide navBar
			else if (mouseDown.y >= upper && mouseDown.y <= lower &&
					 mouseUp.y   >= upper && mouseUp.y   <= lower)
			{
				[self showView:My_Info_View];
			}
			
		} // if info view else text view
		
	} // if we have text to display

	// We handle the up for this down, so reset the position
	// (This prevents a mouseUp "bounce")
	mouseDown = CGPointMake(-1, -1);
	
	return;
		
} // mouseUp


// Handle navBar buttons ...
- (void) navigationBar: (UINavigationBar*) navBar buttonClicked: (int) button 
{
	if (currentView == My_File_View)
	{
		[self showView:My_Info_View];
	}
	else
	{
		switch (button) {
			case 0: // Settings
				[self showView:My_Prefs_View];
				break;

			case 1: // Open
				[self showView:My_File_View];
				break;
		} // switch
	}
	
} // navigationBar


- (void) redraw {
	if (currentView == My_Text_View || currentView == My_Info_View)
		[textView setNeedsDisplay];
	else if (currentView == My_File_View)
		[fileTable resize];
	else if (currentView == My_Prefs_View)
		[prefsTable resize];
	else if (currentView == My_Download_View)
		[downloadTable resize];
} // redraw


- (bool) openFile:(NSString *)name path:(NSString *)path start:(int)startChar {
	if (name && [textView openFile:name path:path start:startChar])
	{
		[self showView:My_Text_View];
		[navBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle:name]];
	}
	else
		[self showView:My_Info_View];
} // openFile


- (TextFileType) getFileType:(NSString*)fileName {

	TextFileType type = kTextFileTypeUnknown;

	if ([fileName length] > 4 && 
	    [fileName characterAtIndex:[fileName length]-4] == '.')
	{
		NSString * ext = [fileName substringFromIndex:[fileName length]-3];
		
		if (![ext compare:@"txt" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypeTXT;
			
		else if (![ext compare:@"pdb" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypePDB;
		
		//[ext release];
	}
	else if ([fileName length] > 5 && 
	         [fileName characterAtIndex:[fileName length]-5] == '.')
	{
		NSString * ext = [fileName substringFromIndex:[fileName length]-3];
		
		if (![ext compare:@"text" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypeTXT;

		//[ext release];
	}

	return type;
} // getFileType


// This view's alert sheets are just informational ...
// Dismiss them without doing anything special
- (void)alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button 
{
  [sheet dismissAnimated:YES];
  [sheet release];
} // alertSheet


@end // @implementation textReader






