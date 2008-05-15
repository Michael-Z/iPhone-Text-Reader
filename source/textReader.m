
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
#import "UIDeletableCell.h"
#import "PrefsTable.h"
#import "DownloadTable.h"




// *****************************************************************************
// This is the "main" GUI application ...
@implementation textReader




- (id) init {   

	defaults = [[NSUserDefaults standardUserDefaults] retain];
	
	currentOrientation 	= -9999;
	wait                = nil;
	transView  			= nil;
	textView  			= nil;
	fileTable           = nil;
	prefsTable          = nil;
	downloadTable       = nil;
	navBar    			= nil;
	slider              = nil;
	settingsBtn         = nil;
	lockBtn             = nil;
	currentView         = My_No_View;
	mouseDown           = CGPointMake(-1,-1);
	volChanged          = false;
	reverseTap          = false;
	swipe               = false;
	orientationInitialized = false;

	[super init];
	
} // init

- (void) setReverseTap:(bool)rtap {
	reverseTap = rtap;
}

- (void) setSwipe:(bool)sw {
	swipe = sw;
}

- (void) showWait {

	if (!wait)
	{		
		struct CGRect rect = [self getOrientedViewRect];
		rect.origin.x = 0;
		rect.origin.y = rect.size.height - (rect.size.height * 2) / 5;
		rect.size.height = rect.size.height / 5;

		wait = [[UIProgressHUD alloc] initWithWindow:mainWindow];
		[wait setText:@"Loading ..."];
		// [wait setText:@""];
		[wait drawRect:rect];
		[wait setNeedsDisplay];

		// Sad - doesn't work ...		
		// Try to hide the background of the spinner ...
		// float backParts[4] = {0, 0, 0, .5};
		// float backParts[4] = {0, 0, 0, 0};
		// CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		// [wait setBackgroundColor: CGColorCreate(colorSpace, backParts)];
	}
	
// JIMB BUG BUG - handle this !!!	
	// Rotate ?!?!?!? Not sure how best to do it ????
	[transView setEnabled:NO];
    [wait show:YES];

} // showWait


- (void) hideWait {
  if (wait)
  {
 	  [wait show:NO];
 	  // [wait removeFromSuperview];
 	  // [wait release];
 	  // wait = nil;
  }
  
  [transView setEnabled:YES];
  
} // hideWait



- (bool) getReverseTap { return reverseTap; }

- (bool) getSwipe { return swipe; }

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

	// Restore original volume
	AVSystemController *avsc = [AVSystemController sharedAVSystemController];
	if (curVol != initVol)
	{
		curVol = initVol;
		[avsc setActiveCategoryVolumeTo:initVol];
	}

	[defaults setInteger:[textView getColor] forKey:TEXTREADER_COLOR];
	
	[defaults setInteger:[self getOrientCode] forKey:TEXTREADER_OCODE];
	[defaults setInteger:[self orientationLocked] forKey:TEXTREADER_OLOCKED];
	
	[defaults setInteger:reverseTap forKey:TEXTREADER_REVERSETAP];
	
	[defaults setInteger:swipe forKey:TEXTREADER_SWIPE];
	
	[defaults setInteger:[textView getIgnoreNewLine] forKey:TEXTREADER_IGNORELF];

	[defaults setInteger:[textView getPadMargins] forKey:TEXTREADER_PADMARGINS];

	[defaults setObject:[textView getFont] forKey:TEXTREADER_FONT];

	[defaults setInteger:[textView getFontSize] forKey:TEXTREADER_FONTSIZE];

	[defaults setInteger:[textView getEncoding] forKey:TEXTREADER_ENCODING];

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


- (void)fixButtons {

	struct CGSize viewSize   = [self getOrientedViewSize];
	struct CGRect btnRect;

	// Position settings button	
	btnRect.size.width = btnRect.size.height = [UINavigationBar defaultSize].height *0.8;
	btnRect.origin.x = viewSize.width - btnRect.size.width - 4;
	btnRect.origin.y = ([UINavigationBar defaultSize].height - btnRect.size.height) / 2;
	[settingsBtn setFrame:btnRect];
	
	// Handle lock image
	UIImageView *imgLock = [ [ UIImage alloc ] 
			  initWithContentsOfFile: [ [ NSString alloc ] 
			  initWithFormat: @"/Applications/%@.app/locked.png", 
							  TEXTREADER_NAME ] ];
	UIImageView *imgUnlock = [ [ UIImage alloc ] 
			  initWithContentsOfFile: [ [ NSString alloc ] 
			  initWithFormat: @"/Applications/%@.app/unlocked.png", 
							  TEXTREADER_NAME ] ];

	if ([self orientationLocked])
	{
		[lockBtn setImage:imgLock forState:0];
		[lockBtn setImage:imgUnlock forState:1];
	}
	else
	{
		[lockBtn setImage:imgUnlock forState:0];
		[lockBtn setImage:imgLock forState:1];
	}
						  	
	// Position lock button
	btnRect.origin.x -= btnRect.size.width - 4;
	[lockBtn setFrame:btnRect];
	
} // fixButtons


- (void) loadDefaults {

	// Restore general prefs
	[textView setColor:[defaults integerForKey:TEXTREADER_COLOR]];

	[self setReverseTap:[defaults integerForKey:TEXTREADER_REVERSETAP]];

	[self setSwipe:[defaults integerForKey:TEXTREADER_SWIPE]];

	[textView setIgnoreNewLine:[defaults integerForKey:TEXTREADER_IGNORELF]];

	[textView setPadMargins:[defaults integerForKey:TEXTREADER_PADMARGINS]];

	// Restore font prefs
	int fontSize = [defaults integerForKey:TEXTREADER_FONTSIZE];
	if (fontSize < 8 || fontSize > 40)
		fontSize = TEXTREADER_DFLT_FONTSIZE;

	NSString * font = [defaults stringForKey:TEXTREADER_FONT];
	if (!font || [font length] < 1)
		font = TEXTREADER_DFLT_FONT;

	[textView setFont:font size:fontSize];
		
	[textView setEncoding:[defaults integerForKey:TEXTREADER_ENCODING]];

	// Open last opened file at last position
	NSString * path = [defaults stringForKey:TEXTREADER_OPENPATH];
	NSString * name = [defaults stringForKey:TEXTREADER_OPENFILE];
	if (name)
		[self openFile:name path:path];
		// Leave wait up - openfile will clear it when done
	else
	{
		// No file to open - switch to info view
		[self showView:My_Info_View];
		
		// Done waiting
		[self hideWait];
	}
		
} // loadDefaults


- (void) recreateSlider {
	if (slider)
	{
		// Nuke the old one ...
  	    [slider removeFromSuperview];
	    [slider release];
	    slider = nil;
	}
	if ([textView getText] && currentView == My_Info_View)
	{
		struct CGRect FSrect = [self getOrientedViewRect];
		struct CGRect rect   = CGRectMake(0, 
		                                  FSrect.size.height-[UINavigationBar defaultSize].height, 
		                                  FSrect.size.width, 
		                                  [UINavigationBar defaultSize].height);	
		// Create the slider ...	
		slider = [[UISliderControl alloc] initWithFrame:rect];
		float backParts[4] = {0, 0, 0, .5};
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		[slider setBackgroundColor: CGColorCreate(colorSpace, backParts)];
		[slider setShowValue:NO];
		[slider setMinValue:0];

		[slider addTarget:self action:@selector(handleSlider:) forEvents:7]; // 7=drag, 2=up
		[slider setMaxValue:[[textView getText] length]/TEXTREADER_SLIDERSCALE+1];
		[slider setValue:[textView getStart]/TEXTREADER_SLIDERSCALE];	
	
		[textView addSubview:slider];	
	}
	
} // recreateSlider


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

				[fileTable setNavBar:fileBar];
				
				[fileTable setPath:[textView getFilePath]];
				
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
				
				// Switch views
				[transView transition:1 toView:textView];
				currentView = My_Info_View;
				
				// Update the slider
				[self recreateSlider];
				
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
						
				// Switch views
				if (currentView == My_File_View)
					[transView transition:1 toView:textView];
				else
					[transView transition:2 toView:textView];
				currentView = My_Text_View;
				
				// Update the slider
				[self recreateSlider];
				
				fileTable = nil;
				prefsTable = nil;
				downloadTable = nil;
				
				[self redraw];				
			}
			break;

	} // switch on viewName
	
} // showView


- (void)showSettings:(UINavBarButton *)btn
{
	if (![btn isPressed])
		[self showView:My_Prefs_View];
}


- (void)toggleLock:(UINavBarButton *)btn
{
	if (![btn isPressed])
	{
		if ([self orientationLocked])
			[self unlockUIOrientation];
		else
			[self lockUIOrientation];
		[self fixButtons];
		[self showView:My_Text_View];
	}
}


- (void) pageText:(bool)pgup
{
	if (currentView == My_Text_View)
	{
		if (pgup)
		{
			if (reverseTap)
				// Move down one page 
				[textView pageDown];
			else
				// Move up one page 
				[textView pageUp];
		}
		else
		{
			if (reverseTap)
				// Move down one page 
				[textView pageUp];
			else
				// Move up one page 
				[textView pageDown];
		}
	}
} // pageText


// This is used to "de-bounce" the volume buttons
- (void)clearVolumeChanged:(id)unused {  
	volChanged = false;
}


- (void) volumeChanged:(NSNotification *)notify
{
	float newVol;
 	NSString * name;
 	 		
	AVSystemController *avsc = [AVSystemController sharedAVSystemController];
	
 	[avsc getActiveCategoryVolume:&newVol andName:&name];

 	if (newVol < curVol) 
 	{
 		// Scroll down
 		if (!volChanged)
 		{
 			volChanged = true;
 			[self pageText:false];
			[NSTimer scheduledTimerWithTimeInterval:0.4f target:self 
			         selector:@selector(clearVolumeChanged:) userInfo:nil repeats:NO];
 		}
 	}
 	else if (newVol > curVol)
 	{
 		// Scroll up
 		if (!volChanged)
 		{
 			volChanged = true;
 			[self pageText:true];
			[NSTimer scheduledTimerWithTimeInterval:0.4f target:self 
			         selector:@selector(clearVolumeChanged:) userInfo:nil repeats:NO];
 		}
 	}
 	
 	if (newVol != curVol)
		[avsc setActiveCategoryVolumeTo:curVol];
 
 	// Restore our initial volume
 
} // volumeChanged

// Make sure the current volume is within bounds
- (void)setCurVolume:(id)unused {  

	curVol = initVol;
	
	// There are 16 bars on the volume HUD
	// 1/16 = 0.0625, but apparently that isn't quite enough - add 0.005
    if (curVol == 1.0f) 
    	curVol = 1.0f - 0.063f;
    if (curVol < 0.063f) 
    	curVol = 0.063f;
		
	AVSystemController *avsc = [AVSystemController sharedAVSystemController];
	[avsc setActiveCategoryVolumeTo:curVol];
}



- (void) applicationDidFinishLaunching: (id) unused {

	[self setUIOrientation: [UIHardware deviceOrientation:YES]];

	struct CGRect FSrect = [self getOrientedViewRect];
	   
	// Initialize the main window 
	mainWindow = [[UIWindow alloc] initWithContentRect: FSrect];
	[mainWindow orderFront: self];
	[mainWindow makeKey: self];
	[mainWindow _setHidden: false];
	[mainWindow setAutoresizingMask: kMainAreaResizeMask];
	[mainWindow setAutoresizesSubviews: YES];
	
	// Fire up the loading wait msg
	[self showWait];

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
	[navBar showButtonsWithLeft: @"Open" right:nil leftBack: YES];
	[navBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle:TEXTREADER_NAME]];
	[navBar setAutoresizingMask: kTopBarResizeMask];	
    [navBar setAlpha:0];
	[textView addSubview:navBar];	
	
	// Add settings button
	settingsBtn = [[UINavBarButton alloc] initWithFrame:navBarRect];
	[settingsBtn setAutosizesToFit:NO];
	UIImageView *image = [ [ UIImage alloc ] 
		  initWithContentsOfFile: [ [ NSString alloc ] 
		  initWithFormat: @"/Applications/%@.app/settings_up.png", 
						  TEXTREADER_NAME ] ];
	[settingsBtn setImage:image forState:0];
	image = [ [ UIImage alloc ] 
		  initWithContentsOfFile: [ [ NSString alloc ] 
		  initWithFormat: @"/Applications/%@.app/settings_dn.png", 
						  TEXTREADER_NAME ] ];
	[settingsBtn setImage:image forState:1];

	[settingsBtn setDrawContentsCentered:YES];
	[settingsBtn addTarget:self action:@selector(showSettings:) forEvents: (255)];
	[navBar addSubview:settingsBtn];

	// Add lock button
	lockBtn = [[UINavBarButton alloc] initWithFrame:navBarRect];
	[lockBtn setAutosizesToFit:NO];
	[lockBtn setDrawContentsCentered:YES];
	[lockBtn addTarget:self action:@selector(toggleLock:) forEvents: (255)];
	[navBar addSubview:lockBtn];

	[self fixButtons];

	// // Volume scrolling ...	
	[self setSystemVolumeHUDEnabled:NO];
	
	AVSystemController *avsc = [AVSystemController sharedAVSystemController];

	[[NSNotificationCenter defaultCenter] addObserver:self 
		selector:@selector(volumeChanged:) 
		name:@"AVSystemController_SystemVolumeDidChangeNotification" 
		object:avsc];

	NSString *name;
	[avsc getActiveCategoryVolume:&initVol andName:&name];

	// We need to set the current volume so it has some up and down room
	// Can't do this here because the HUDEnabled:NO has not yet taken effect - use a timer
	// [avsc setActiveCategoryVolumeTo:curVol];
    [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(setCurVolume:) userInfo:nil repeats:NO];
	
	[super setInitialized: true];	
	
	[self loadDefaults];
	
} // applicationDidFinishLaunching


- (void) handleSlider: (id)whatever
{
	//[textView setStart:[slider value]];

	int pos = MIN([[textView getText] length], [slider value]*TEXTREADER_SLIDERSCALE);
	
	[textView setStart:pos];
	
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

//	int newO = [UIHardware deviceOrientation: YES];
//	if (newO > 6 || newO < 0) 
//	   return;
	   
} // deviceOrientationChanged


// Here's the recommended method for doing custom stuff when the screen's rotation has changed... 
- (void) setUIOrientation: (int) o_code {
	[super setUIOrientation: o_code];
	
	if ([self orientationLocked])
	   return;
	
	if (![super isInitialized] || ([super getOrientation] == currentOrientation))
		return;
	
	currentOrientation = [super getOrientation];

	// Slider will not redraw properly when rotated - so nuke it and recreate it ...
	[self recreateSlider];
	
	// Resize the navbar as well
	struct CGRect FSrect = [self getOrientedViewRect];
	struct CGRect rect   = [navBar frame];
	rect.origin.y = [UIHardware statusBarHeight];
	rect.size.width = FSrect.size.width;
	[navBar setFrame:rect];

	// Set the locked orientation
	// Can't do this during finishedLaunchine because UIOrientation is set up at that point
	if (!orientationInitialized)
	{
		orientationInitialized = TRUE;
		if ([defaults integerForKey:TEXTREADER_OLOCKED])
			[self lockUIToOrientation:[defaults integerForKey:TEXTREADER_OCODE]];
	}
	
	// Resize the buttons on the navbar
	[self fixButtons];
	
	// // Rotate wait msg
	// JIMB BUG BUG - has some strange side effects ...
	// //[wait setRotationBy:currentOrientation - [super getOrientation]];
	// [wait setRotationBy:[super getOrientation]];

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
	//Added by Allen Li
	offset = mouseDown;
	isInDragMode = NO;
	//Until Here Allen Li
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
	
	//Added by Allen Li
	if (isInDragMode)
	{
		isInDragMode = NO;
		mouseDown = CGPointMake(-1, -1);		
		return;
	}
	
	//Until here -Allen Li
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
				if (reverseTap)
					// Move down one page 
					[textView pageDown];
				else
					// Move up one page 
					[textView pageUp];
			}

			// Both lower  = page forward
			else if (mouseDown.y > lower && mouseUp.y > lower)
			{
				if (reverseTap)
					// Move down one page 
					[textView pageUp];
				else
					// Move up one page 
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

//Added by Allen Li --- Handle Mouse-Dragged
- (void)mouseDragged: (struct __GSEvent *)event
{
	// Did they want this turned off?
	if (!swipe)
		return;
		
	CGPoint point = [self getOrientedEventLocation:event];

	int dragLen;
	int fontHeight;

	fontHeight = [textView getFontHeight];

	dragLen = point.y - offset.y;

	if( (dragLen >= fontHeight) || (dragLen <= (-fontHeight)) )
	{
		isInDragMode = YES;
		offset = point;
		[textView dragText:(dragLen)];
	}
	
}//mouseDragged

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


// Try splitting this out so we can show the wait hud ... D'Oh! Still doesn't work
- (void) openFile2
{
 	if (openname && [textView openFile:openname path:openpath])
 	{
 		[self showView:My_Text_View];
 		[navBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle:openname]];
 	}
 	else
 		[self showView:My_Info_View];

 	[self hideWait];
}

// Even with everything commented out this blows up ...
- (void) thrdOpenFile:(id)ignored 
{   
	[self performSelectorOnMainThread:@selector(openFile2) 
							withObject:nil waitUntilDone:YES];
}

- (void) openFile:(NSString *)name path:(NSString *)path {

	[self showWait];
	
	// KLUDGE!!!!
	// Remember the open file and path
	openname = name;
	openpath = path;

	// For some reason, we often don't get the "wait" when loading default file
	// Maybe because the mainwindow isn't quite up?!?!?
    [NSThread detachNewThreadSelector:@selector(thrdOpenFile:)
	  						 toTarget:self
	  					   withObject:nil];
    
} // openFile


- (TextFileType) getFileType:(NSString*)fileName {

	TextFileType type = kTextFileTypeUnknown;

	if ([fileName length] > 4 && 
	    [fileName characterAtIndex:[fileName length]-4] == '.')
	{
		NSString * ext = [fileName substringFromIndex:[fileName length]-3];
		
		if (![ext compare:@"txt" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypeTXT;
			
		else if (![ext compare:@"pdb" options:kCFCompareCaseInsensitive ] ||
		         ![ext compare:@"prc" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypePDB;
		
		else if (![ext compare:@"htm" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypeHTML;

		else if (![ext compare:@"fb2" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypeFB2;
	}
	else if ([fileName length] > 5 && 
	         [fileName characterAtIndex:[fileName length]-5] == '.')
	{
		NSString * ext = [fileName substringFromIndex:[fileName length]-4];
		
		if (![ext compare:@"text" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypeTXT;

		else if (![ext compare:@"html" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypeHTML;

		else if (![ext compare:@"mobi" options:kCFCompareCaseInsensitive ])
			type = kTextFileTypePDB;
	}

	return type;
	
} // getFileType


// This view's alert sheets are just informational ...
// Dismiss them without doing anything special
- (void)alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button 
{
  //[self unlockUIOrientation];
  [sheet dismissAnimated:YES];
  [sheet release];
} // alertSheet


@end // @implementation textReader






