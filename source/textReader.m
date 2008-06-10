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
#import "UIDeletableCell.h"
#import "PrefsTable.h"
#import "ColorTable.h"
#import "DownloadTable.h"



// *****************************************************************************
// This is the "main" GUI application ...
@implementation textReader




- (id) init {   

    defaults = [[NSUserDefaults standardUserDefaults] retain];
    
    currentOrientation  = -9999;
    wait                = nil;
    transView           = nil;
    baseTextView        = nil;
    textView            = nil;
    fileTable           = nil;
    prefsTable          = nil;
    colorTable          = nil;
    downloadTable       = nil;
    navBar              = nil;
    slider              = nil;
    settingsBtn         = nil;
    lockBtn             = nil;
    searchBtn           = nil;
    searchBox           = nil;
    lastSearch          = nil;
    // bookmarkBtn         = nil;
    okDialog            = nil;
    currentView         = My_No_View;
    mouseDown           = CGPointMake(-1,-1);
    reverseTap          = false;
    swipeOK             = false;
    volPressed          = 0;
    volChanged          = false;    
    orientationInitialized = false;

    [super init];
    
} // init


- (void) setReverseTap:(bool)rtap {
    reverseTap = rtap;
}


- (void) setSwipeOK:(bool)sw {
    swipeOK = sw;
}


// Turn on the volume hud
// Called from a timer to prevent the hud from appearing when we turn on 
// a volume setting ...
- (void)enableVolumeHUD:(id)unused {  
    [self setSystemVolumeHUDEnabled:YES];
} // enableVolumeHUD


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
    
} // setCurVolume


- (void) setVolScroll:(int)vs {

    // Turning on ...
    if (vs != 0)
    {
        // Volume scrolling ...  
        [self setSystemVolumeHUDEnabled:NO];

        AVSystemController *avsc = [AVSystemController sharedAVSystemController];
        
        NSString *name;
        [avsc getActiveCategoryVolume:&initVol andName:&name];

        // We need to set the current volume so it has some up and down room
        // Can't do this here because the HUDEnabled:NO has not yet taken effect - use a timer
        // [avsc setActiveCategoryVolumeTo:curVol];
        [NSTimer scheduledTimerWithTimeInterval:0.4f target:self selector:@selector(setCurVolume:) userInfo:nil repeats:NO];
    }
    
    // Turning off ...
    else if (volScroll != 0 && vs == 0)
    {
        // Restore original volume
        AVSystemController *avsc = [AVSystemController sharedAVSystemController];
        if (curVol != initVol)
        {
            // Wish there was a way to restore the vol w/o having the volume 
            // HUD appear when we exit ?!?!?!?!?
            curVol = initVol;
            [avsc setActiveCategoryVolumeTo:initVol];
        }
        [NSTimer scheduledTimerWithTimeInterval:0.4f target:self selector:@selector(enableVolumeHUD:) userInfo:nil repeats:NO];

    }
    
    // Remember the new setting
    volScroll = vs;
    
} // setVolScroll


- (void) showWait {

    if (!wait)
    {       
        struct CGRect rect = [self getOrientedViewRect];
        rect.origin.x = 0;
        rect.origin.y = rect.size.height - (rect.size.height * 2) / 5;
        rect.size.height = rect.size.height / 5;

        wait = [[UIProgressHUD alloc] initWithWindow:mainWindow];
        [wait setText:_T(@"Loading ...")];
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


- (MyViewName) getCurrentView { return currentView; };

- (bool) getReverseTap { return reverseTap; }

- (bool) getSwipeOK { return swipeOK; }

- (int) getVolScroll { return volScroll; }

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

//  // Restore original volume
//  AVSystemController *avsc = [AVSystemController sharedAVSystemController];
//  if (curVol != initVol)
//  {
//      // Wish there was a way to restore the vol w/o having the volume 
//      // HUD appear when we exit ?!?!?!?!? Leave it out for now ...
//      curVol = initVol;
//      [avsc setActiveCategoryVolumeTo:initVol];
//  }

    [defaults setInteger:[textView getInvertColors] forKey:TEXTREADER_INVERTCOLORS];
    
    [defaults setInteger:[self getOrientCode] forKey:TEXTREADER_OCODE];
    [defaults setInteger:[self orientationLocked] forKey:TEXTREADER_OLOCKED];
    
    [defaults setInteger:reverseTap forKey:TEXTREADER_REVERSETAP];
    
    [defaults setInteger:swipeOK forKey:TEXTREADER_SWIPE];
    
    [defaults setInteger:volScroll forKey:TEXTREADER_VOLSCROLL];
    
    [defaults setInteger:[textView getIgnoreSingleLF] forKey:TEXTREADER_IGNORELF];

    [defaults setInteger:[textView getPadMargins] forKey:TEXTREADER_PADMARGINS];

    [defaults setInteger:[textView getRepeatLine] forKey:TEXTREADER_REPEATLINE];

    [defaults setInteger:[textView getTextAlignment] forKey:TEXTREADER_TEXTALIGNMENT];

    [defaults setObject:[textView getFont] forKey:TEXTREADER_FONT];

    [defaults setInteger:[textView getFontSize] forKey:TEXTREADER_FONTSIZE];

    [defaults setInteger:[textView getEncoding] forKey:TEXTREADER_ENCODING];

    [defaults setFloat:[textView getTextColors].text_red   forKey:TEXTREADER_TEXTRED];
    [defaults setFloat:[textView getTextColors].text_green forKey:TEXTREADER_TEXTGREEN];
    [defaults setFloat:[textView getTextColors].text_blue  forKey:TEXTREADER_TEXTBLUE];

    [defaults setFloat:[textView getTextColors].bkg_red   forKey:TEXTREADER_BKGRED];
    [defaults setFloat:[textView getTextColors].bkg_green forKey:TEXTREADER_BKGGREEN];
    [defaults setFloat:[textView getTextColors].bkg_blue  forKey:TEXTREADER_BKGBLUE];
    
    // Save lastSearch if we have one ...
    if (lastSearch)
        [defaults setObject:lastSearch forKey:TEXTREADER_LASTSEARCH];

    // Save currently open book so we can reopen it later
    NSString * fileName = [textView getFileName];
    if (!fileName)
        fileName = @"";

    NSString * filePath = [textView getFilePath];
    if (!filePath)
        filePath = TEXTREADER_DEF_PATH;

    [defaults setObject:fileName forKey:TEXTREADER_OPENFILE];
    [defaults setObject:filePath forKey:TEXTREADER_OPENPATH];
    [self setDefaultStart:fileName start:[textView getStart]];
        
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
    struct CGRect sbtnRect, lbtnRect;
    
    // Position settings button 
    sbtnRect.size.width  = 43;
    sbtnRect.size.height = 30;
    sbtnRect.origin.x = viewSize.width - sbtnRect.size.width - 8;
    sbtnRect.origin.y = 37;
    [settingsBtn setFrame:sbtnRect];
    
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
                            
    // Position bookmark button
    lbtnRect.size.width  = 45;
    lbtnRect.size.height = 30;
    lbtnRect.origin.x = sbtnRect.origin.x - lbtnRect.size.width;
    lbtnRect.origin.y = sbtnRect.origin.y;    
//     [bookmarkBtn setFrame:lbtnRect];
    
    // Position search button
    // lbtnRect.size.width  = 45;
    // lbtnRect.size.height = 30;
//     lbtnRect.origin.x = lbtnRect.origin.x - lbtnRect.size.width;
    // lbtnRect.origin.y = sbtnRect.origin.y;    
    [searchBtn setFrame:lbtnRect];
    
    // Position lock button
    // lbtnRect.size.width  = 45;
    // lbtnRect.size.height = 30;
    lbtnRect.origin.x = lbtnRect.origin.x - lbtnRect.size.width;
    // lbtnRect.origin.y = sbtnRect.origin.y;    
    [lockBtn setFrame:lbtnRect];
    
    // Position "percent" label
    lbtnRect.size.width  = 70;
    lbtnRect.origin.x = lbtnRect.origin.x - lbtnRect.size.width;
    // lbtnRect.origin.y = sbtnRect.origin.y;    
    [percent setFrame:lbtnRect];
       
} // fixButtons


- (void) loadDefaults {

    // Restore general prefs
    [textView setInvertColors:[defaults integerForKey:TEXTREADER_INVERTCOLORS]];

    [self setReverseTap:[defaults integerForKey:TEXTREADER_REVERSETAP]];

    [self setSwipeOK:[defaults integerForKey:TEXTREADER_SWIPE]];

    [self setVolScroll:[defaults integerForKey:TEXTREADER_VOLSCROLL]];

    [textView setIgnoreSingleLF:[defaults integerForKey:TEXTREADER_IGNORELF]];

    [textView setPadMargins:[defaults integerForKey:TEXTREADER_PADMARGINS]];

    [textView setRepeatLine:[defaults integerForKey:TEXTREADER_REPEATLINE]];

    [textView setTextAlignment:[defaults integerForKey:TEXTREADER_TEXTALIGNMENT]];

    // Restore font prefs
    int fontSize = [defaults integerForKey:TEXTREADER_FONTSIZE];
    if (fontSize < 8 || fontSize > 40)
        fontSize = TEXTREADER_DFLT_FONTSIZE;

    NSString * font = [defaults stringForKey:TEXTREADER_FONT];
    if (!font || [font length] < 1)
        font = TEXTREADER_DFLT_FONT;

    [textView setFont:font size:fontSize];
        
    [textView setEncoding:[defaults integerForKey:TEXTREADER_ENCODING]];

    MyColors txtcolors;
    
    txtcolors.text_red   = [defaults floatForKey:TEXTREADER_TEXTRED];
    txtcolors.text_green = [defaults floatForKey:TEXTREADER_TEXTGREEN];
    txtcolors.text_blue  = [defaults floatForKey:TEXTREADER_TEXTBLUE];

    txtcolors.bkg_red    = [defaults floatForKey:TEXTREADER_BKGRED];
    txtcolors.bkg_green  = [defaults floatForKey:TEXTREADER_BKGGREEN];
    txtcolors.bkg_blue   = [defaults floatForKey:TEXTREADER_BKGBLUE];

    [textView setTextColors:&txtcolors];

    // Get the last search string requested ...
    lastSearch = [defaults stringForKey:TEXTREADER_LASTSEARCH];
    
    // Open last opened file at last position
    NSString * path = [defaults stringForKey:TEXTREADER_OPENPATH];
    NSString * name = [defaults stringForKey:TEXTREADER_OPENFILE];
    if (name && [name length])
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


// Set the filename as the navbar title
- (void) setNavTitle {

    // Create title label ...    
    if ([textView getFileName])
        [navBar setPrompt:[textView getFileName]];
    else
        [navBar setPrompt:TEXTREADER_NAME];
        
} // setNavTitle


- (void) recreateSlider {
    if (slider)
    {
        // Nuke the old one ...
        [slider removeFromSuperview];
        [slider release];
        slider = nil;
    }
    
    if (currentView == My_Info_View)
    {
        struct CGRect FSrect = [self getOrientedViewRect];
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        if ([textView getText])
        {
            struct CGRect rect   = CGRectMake(0, 
                                              FSrect.size.height-[UINavigationBar defaultSize].height, 
                                              FSrect.size.width, 
                                              [UINavigationBar defaultSize].height);    
            // Create the slider ...    
            slider = [[UISliderControl alloc] initWithFrame:rect];
            float backParts[4] = {0, 0, 0, .5};
            [slider setBackgroundColor: CGColorCreate(colorSpace, backParts)];
            [slider setShowValue:NO];
            [slider setMinValue:0];
            //[slider setMaxValue:[[textView getText] length]];
            //[slider setValue:[textView getStart]];   
            [slider setMaxValue:100];
            [slider setValue:100.0*(double)[textView getStart]/(double)[[textView getText] length]];   

            [slider addTarget:self action:@selector(handleSlider:) forEvents:255];

            [baseTextView addSubview:slider];   
        }

        // Make sure the navbar title is the filename ...
        [self setNavTitle];        
   }
   
} // recreateSlider


- (void) showFileTable:(NSString*)path
{           
    struct CGRect FSrect     = [self getOrientedViewRect];

    // A view with a NavBar and Table
    UIView * fileView = [[UIView alloc ] initWithFrame:FSrect];;
    [fileView setAutoresizingMask: kMainAreaResizeMask];
    [fileView setAutoresizesSubviews: YES];

    FSrect.origin.y += [UIHardware statusBarHeight];
    FSrect.size.height = [UINavigationBar defaultSize].height;
    UINavigationBar * fileBar   = [[UINavigationBar alloc] initWithFrame:FSrect];
    [fileBar setBarStyle: 0];
    [fileBar setDelegate: self];
    [fileBar showButtonsWithLeft: _T(@"Back") right: nil leftBack: YES];
    [fileBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle: _T(@"Open Text File")]];
    [fileBar setAutoresizingMask: kTopBarResizeMask];

    FSrect = [self getOrientedViewRect];
    FSrect.origin.y    += [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
    FSrect.size.height -= [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
    fileTable = [ [ FileTable alloc ] initWithFrame:FSrect];

    [fileTable setNavBar:fileBar];

    [fileTable setPath:path];

    [fileTable setTextReader:self];
    [fileTable reloadData];

    [fileView addSubview:fileBar];  
    [fileView addSubview:fileTable];

    [super hideStatus: false];

    // Switch views
    [transView transition:1 toView:fileView];
    currentView = My_File_View;

    [self redraw];
    
} // showFileTable


- (void) showPercentage:(int)pos {

    if (currentView == My_Info_View)
    {
        NSString * pct = nil;
    
        if ([textView getText] && [[textView getText] length])
        {
            // The blanks are a simple way to force it to the left
            // so it doesn't overlap the buttons
            pct = [NSString stringWithFormat:@"%4.2f%%", 
                     100.0 * (double)pos / (double)[[textView getText] length]];
        }
        else
        {
            // pct = TEXTREADER_NAME;
            pct = @"";
        }

        // [navBar popNavigationItem];
        // [navBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle:pct]];
        // [navItem setTitle:pct];
        [percent setText:pct];
    }
    
} // showPercentage


// Gets rid of the search box ...
- (void) endSearch {

    // Kill the search box
    if (searchBox)
    {
        [searchBox removeFromSuperview];
        [searchBox release];
    }
    if (keyboard)
    {
        [keyboard removeFromSuperview];
        [keyboard release];
    }
    searchBox = nil;
    keyboard  = nil;
    
    // Restore the nav title ...
    [self setNavTitle];
    
} // endSearch


- (void) showView:(MyViewName)viewName
{
    struct CGRect FSrect     = [self getOrientedViewRect];
    struct CGSize viewSize   = [self getOrientedViewSize];
          
    // Get rid of the search stuff
    [self endSearch];
    
    switch (viewName)
    {
        case My_No_View:
            break;
            
        case My_Color_View:
            if (currentView != My_Color_View)
            {           
                // // Re-enable the volume hud
                [NSTimer scheduledTimerWithTimeInterval:0.4f target:self selector:@selector(enableVolumeHUD:) userInfo:nil repeats:NO];

                // A view with a NavBar and Prefs Table
                UIView * colorsView = [[UIView alloc ] initWithFrame:FSrect];;
                [colorsView setAutoresizingMask: kMainAreaResizeMask];
                [colorsView setAutoresizesSubviews: YES];

                FSrect.origin.y += [UIHardware statusBarHeight];
                FSrect.size.height = [UINavigationBar defaultSize].height;
                UINavigationBar * colorsBar   = [[UINavigationBar alloc] initWithFrame:FSrect];
                [colorsBar setBarStyle: 0];
                [colorsBar showButtonsWithLeft: _T(@"Save") right:_T(@"Cancel") leftBack: YES];
                [colorsBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle: _T(@"Colors")]];
                [colorsBar setAutoresizingMask: kTopBarResizeMask];
                
                FSrect = [self getOrientedViewRect];
                FSrect.origin.y    += [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
                FSrect.size.height -= [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
                colorTable = [ [ MyColorTable alloc ] initWithFrame:FSrect];
                [colorTable setTextReader:self];
                [colorTable setTextView:textView];
                [colorTable reloadData];
                
                [colorsBar setDelegate:colorTable];

                [colorsView addSubview:colorsBar];  
                [colorsView addSubview:colorTable];

                [super hideStatus:false];
            
                // Switch views
                [transView transition:1 toView:colorsView];
                currentView = My_Color_View;

                [self redraw];
            }
            break;
            
        case My_Download_View:
            if (currentView != My_Download_View)
            {           
                // Re-enable the volume hud
                [NSTimer scheduledTimerWithTimeInterval:0.4f target:self selector:@selector(enableVolumeHUD:) userInfo:nil repeats:NO];

                
                // A view with a NavBar and Prefs Table
                UIView * downloadView = [[UIView alloc ] initWithFrame:FSrect];;
                [downloadView setAutoresizingMask: kMainAreaResizeMask];
                [downloadView setAutoresizesSubviews: YES];

                FSrect.origin.y += [UIHardware statusBarHeight];
                FSrect.size.height = [UINavigationBar defaultSize].height;
                UINavigationBar * downloadBar   = [[UINavigationBar alloc] initWithFrame:FSrect];
                [downloadBar setBarStyle: 0];
                [downloadBar showButtonsWithLeft: _T(@"Done") right:nil leftBack: YES];
                [downloadBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle: _T(@"Download File via URL")]];
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
                // // Disable HUD since user might change settings ...            
                [NSTimer scheduledTimerWithTimeInterval:0.4f target:self selector:@selector(enableVolumeHUD:) userInfo:nil repeats:NO];

            
                // A view with a NavBar and Prefs Table
                UIView * prefsView = [[UIView alloc ] initWithFrame:FSrect];;
                [prefsView setAutoresizingMask: kMainAreaResizeMask];
                [prefsView setAutoresizesSubviews: YES];

                FSrect.origin.y += [UIHardware statusBarHeight];
                FSrect.size.height = [UINavigationBar defaultSize].height;
                UINavigationBar * prefsBar  = [[UINavigationBar alloc] initWithFrame:FSrect];
                [prefsBar setBarStyle: 0];
                [prefsBar showButtonsWithLeft: _T(@"Done") right:_T(@"About") leftBack: YES];
                [prefsBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle: _T(@"Settings")]];
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
                // Re-enable the volume hud
                [NSTimer scheduledTimerWithTimeInterval:0.4f target:self selector:@selector(enableVolumeHUD:) userInfo:nil repeats:NO];
                
                [self showFileTable:[textView getFilePath]];
            }
            break;
            
        case My_Info_View:
            if (currentView != My_Info_View)
            {               
                // Re-enable the volume hud
                [NSTimer scheduledTimerWithTimeInterval:0.4f target:self selector:@selector(enableVolumeHUD:) userInfo:nil repeats:NO];

                struct CGRect navBarRect = [navBar frame];
                navBarRect.size.width = viewSize.width;

                [super hideStatus: false];
                
                // Rescale in case of rotation
                [baseTextView setBounds:[transView bounds]];
                [navBar setFrame: navBarRect];
                [navBar setAlpha:1];
                
                // Switch views
                [transView transition:1 toView:baseTextView];
                currentView = My_Info_View;
                
                // Update the slider
                [self recreateSlider];
                
                // Display the file percentage in the nav bar ...
                [self showPercentage:[textView getStart]];
                
                fileTable = nil;
                prefsTable = nil;
                downloadTable = nil;
                
                [self redraw];
            }
            break;
            
        case My_Text_View:
            if (currentView != My_Text_View)
            {
                // Restore the current volume scrolling
                [self setVolScroll:volScroll];
                
                // Rescale in case of rotation
                [super hideStatus: true];
                [baseTextView setBounds:[transView bounds]];
                
                // Hide navbar and title
                [navBar setAlpha:0];
                        
                // Switch views
                if (currentView == My_File_View)
                    [transView transition:1 toView:baseTextView];
                else
                    [transView transition:2 toView:baseTextView];
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


// Show the settings page
- (void)showSettings:(UINavBarButton *)btn
{
    if (![btn isPressed])
        [self showView:My_Prefs_View];
}


// Handle the search button
- (void)showSearch:(UINavBarButton *)btn
{
    CGRect FSrect = [self getOrientedViewRect];
    CGRect searchRect = CGRectMake(1., 36., FSrect.size.width-2., [UISearchField defaultHeight]);
    
    // Only search if we are not already searching, and there is text to search through
    if (![btn isPressed] && !searchBox &&
        [textView getText] && [[textView getText] length])
    {
        // Make a search box on the nav bar - have it cover the buttons
        searchBox = [[UISearchField alloc] initWithFrame:searchRect];
        [[searchBox textTraits] setEditingDelegate:self];    
        [searchBox setDisplayEnabled: YES ];
        [searchBox setFont: [NSClassFromString(@"WebFontCache") createFontWithFamily:@"Helvetica" traits:2 size:16]];
        //[searchBox setPaddingTop: 6]; 
        [searchBox setPaddingLeft: 3]; 
        [[searchBox textTraits] setReturnKeyType:6]; // Search
        [[searchBox textTraits] setEditingDelegate:self];
        if (lastSearch)
            [searchBox setText:lastSearch];
        
        [searchBox setClearButtonStyle:2]; 
        [searchBox setTextCentersVertically:YES]; 
        [searchBox setPlaceholder:_T(@"Enter your search text ...")];
        [navBar addSubview:searchBox];         
        
        // Set focus to search 
        [searchBox becomeFirstResponder];
        
        // Create a keyboard ... at the bottom of the page
        keyboard = [[UIKeyboard alloc] initWithDefaultSize];
        CGRect kbdRect = [keyboard frame];
        kbdRect.origin.x = 0;
        kbdRect.origin.y = FSrect.size.height-kbdRect.size.height;
        [keyboard setFrame:kbdRect];
        [baseTextView addSubview:keyboard];
    }

    
} // showSearch


// The keyboard is used for searching ...
-(BOOL) keyboardInput:(id)k shouldInsertText:(id)i isMarkedText:(int)b {

    if ([i length] == 1 && [i characterAtIndex:0] == 0xA)
    {
        // Save the new search string
        if (lastSearch)
            [lastSearch release];
        
        // Get the new search text
        lastSearch = [[searchBox text] copy];
        
        // OK - try to find it in the current text starting at the current position ...
        NSRange cur = {MIN((int)[textView getStart]+1, 
                           (int)[[textView getText] length]-1), 
                       MAX(0, 
                           (int)[[textView getText] length] - ((int)[textView getStart] + 1))};
                           
        // lastSearch = [[NSString stringWithFormat:@"l=%d l=%d s=%d max=%d", cur.location, cur.length, [textView getStart], [[textView getText] length]] copy];
        NSRange found = [[textView getText] rangeOfString:lastSearch 
                                                  options:NSCaseInsensitiveSearch 
                                                    range:cur];

        if (found.location == NSNotFound)
        {
            // Set text to not found
            [navBar setPrompt:_T(@"Search text not found ...")];
        }
        else
        {
            // Set new start position
            [textView setStart:found.location];
            
            // Get rid of the search stuff
            [self endSearch];
            
            // Show the user where we found the text
            [self showView:My_Text_View];
        }
                    
       return NO;
    }

    return YES;
} // keyboardInput


// Handle the bookmarks
- (void)showBookmark:(UINavBarButton *)btn
{
    if (![btn isPressed])
    {
    }
} // showBookmark


- (void)toggleLock:(UINavBarButton *)btn
{
    if (![btn isPressed])
    {
        if ([self orientationLocked])
            [self unlockUIOrientation];
        else
            [self lockUIOrientation];
        [self fixButtons];
        // [self showView:My_Text_View];
    }
}


- (void) pageText:(ScrollDir)dir
{
    if (currentView == My_Text_View)
    {
        if (reverseTap)
        {
            switch (dir)
            {
                case Page_Up:
                    dir = Page_Down;
                    break;
                case Page_Down:
                    dir = Page_Up;
                    break;
                case Line_Up:
                    dir = Line_Down;
                    break;
                case Line_Down:
                    dir = Line_Up;
                    break;
            }
        }
        [textView scrollPage:dir];
    }
    
} // pageText



// This is used to detect when the user has pressed vol up/down
// since the timer was started ...
- (void)clearVolumeChanged:(id)unused {

    // If user pressed vol up/down since the timer started
    // we should keep accepting up/down presses w/o debouncing
    if (volChanged)
    {
        // Restart the timer so we can detect when scrolling stops
        [NSTimer scheduledTimerWithTimeInterval:0.1f target:self 
                 selector:@selector(clearVolumeChanged:) userInfo:nil repeats:NO];
    }
    else
        // We are done with this round of vol presses,
        // so reset the flag - the next press will get debounced
        volPressed = 0;
    
    // Reset vol changed flag so we can tell if user presses it 
    // before timer pops again ...
    volChanged = false;
    
    return;
    
} // clearVolumeChanged


// This is used to "de-bounce" the volume buttons
// We start a timer to call this func to reset the changed flag
// Until the timer fires we won't accept another vol change
- (void)clearVolumeDebounce:(id)unused {

    if (volChanged)
    {
        // Clear debounce flag
        if (volPressed == 1)
            volPressed = 2;

        [self clearVolumeChanged:nil];
    }
    else
    {
        // All done ...
        volPressed = 0;
    }
    
} // clearVolumeDebounce


// This gets called every time the vol keys get pressed
- (void) volumeChanged:(NSNotification *)notify
{
    float newVol;
    NSString * name;
            
    // Nothing to do if volume scrolling is disabled
    if (volScroll == 0 || currentView != My_Text_View)
        return;
            
    AVSystemController *avsc = [AVSystemController sharedAVSystemController];
    
    [avsc getActiveCategoryVolume:&newVol andName:&name];
    
    // No vol change, nothing to do ...
    if (newVol == curVol)
        return;

    // Is this up or down?
    if (newVol < curVol) 
    {
        // Scroll down
        // volPressed==1 means debounce the first press
        if (volPressed != 1)
        {
            volPressed++;
            volChanged = true;
            
            if (volScroll == 1)
                [self pageText:Line_Down];
            else
                [self pageText:Page_Down];
                
            // Set timer to reset debounce
            if (volPressed == 1)
            {
                volChanged = false;
                [NSTimer scheduledTimerWithTimeInterval:0.3 target:self 
                         selector:@selector(clearVolumeDebounce:) userInfo:nil repeats:NO];
            }
        }
        else
            volChanged = true;
    }
    else if (newVol > curVol)
    {
        // Scroll up
        // volPressed==1 means debounce the first press
        if (volPressed != 1)
        {
            volPressed++;            
            volChanged = true;
            
            if (volScroll == 1)
                [self pageText:Line_Up];
            else
                [self pageText:Page_Up];

            // Set timer to reset debounce
            if (volPressed == 1)
            {
                volChanged = false;
                [NSTimer scheduledTimerWithTimeInterval:0.3 target:self 
                         selector:@selector(clearVolumeDebounce:) userInfo:nil repeats:NO];
            }
        }
        else
            volChanged = true;
    }

    // Restore the previous vol setting
    [avsc setActiveCategoryVolumeTo:curVol];
 
} // volumeChanged


// This is called when everything is ready to go/initialized
// Now we can set up the GUI and get to work
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

    // Create a view to hold the scrolling text, slider and navBar
    baseTextView = [[[UIView alloc] initWithFrame: FSrect] retain]; 
    [textView setAutoresizingMask:kMainAreaResizeMask];
    [textView setTapDelegate: self];
    
    // Go ahead and create the text view window we will
    // draw text onto ... that way we know it always exists
    textView = [[[MyTextView alloc] initWithFrame: FSrect] retain]; 
    [textView setAutoresizingMask: kMainAreaResizeMask];
    [textView setTapDelegate:self];
    [textView setTextReader:self];
    [baseTextView addSubview:textView]; 
    
    struct CGSize navSize    = [UINavigationBar defaultSize];
    struct CGSize viewSize   = [self getOrientedViewSize];
    struct CGRect navBarRect = CGRectMake(0, [UIHardware statusBarHeight], viewSize.width, navSize.height);

    // Create nav bar for info view
    navBar  = [[[UINavigationBar alloc] initWithFrame: navBarRect] retain];
    [navBar setBarStyle: 0];
    [navBar setDelegate: self];
    [navBar showButtonsWithLeft: _T(@"Open") right:nil leftBack: YES];
    
    navItem = [[UINavigationItem alloc] initWithTitle:nil];
    [navBar pushNavigationItem:navItem];
    [navBar setAutoresizingMask: kTopBarResizeMask];    
    [navBar setAlpha:0];
    [baseTextView addSubview:navBar];   
    
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

//     // Add bookmarks button
//     bookmarkBtn = [[UINavBarButton alloc] initWithFrame:navBarRect];
//     [bookmarkBtn setAutosizesToFit:NO];
//     image = [ [ UIImage alloc ] 
//           initWithContentsOfFile: [ [ NSString alloc ] 
//           initWithFormat: @"/Applications/%@.app/bookmark_up.png", 
//                           TEXTREADER_NAME ] ];
//     [bookmarkBtn setImage:image forState:0];
//     image = [ [ UIImage alloc ] 
//           initWithContentsOfFile: [ [ NSString alloc ] 
//           initWithFormat: @"/Applications/%@.app/bookmark_dn.png", 
//                           TEXTREADER_NAME ] ];
//     [bookmarkBtn setImage:image forState:1];
//     [bookmarkBtn setDrawContentsCentered:YES];
//     [bookmarkBtn addTarget:self action:@selector(showBookmark:) forEvents: (255)];
//     [navBar addSubview:bookmarkBtn];

    // Add search button
    searchBtn = [[UINavBarButton alloc] initWithFrame:navBarRect];
    [searchBtn setAutosizesToFit:NO];
    image = [ [ UIImage alloc ] 
          initWithContentsOfFile: [ [ NSString alloc ] 
          initWithFormat: @"/Applications/%@.app/search_up.png", 
                          TEXTREADER_NAME ] ];
    [searchBtn setImage:image forState:0];
    image = [ [ UIImage alloc ] 
          initWithContentsOfFile: [ [ NSString alloc ] 
          initWithFormat: @"/Applications/%@.app/search_dn.png", 
                          TEXTREADER_NAME ] ];
    [searchBtn setImage:image forState:1];
    [searchBtn setDrawContentsCentered:YES];
    [searchBtn addTarget:self action:@selector(showSearch:) forEvents: (255)];
    [navBar addSubview:searchBtn];

    // Add lock button
    lockBtn = [[UINavBarButton alloc] initWithFrame:navBarRect];
    [lockBtn setAutosizesToFit:NO];
    [lockBtn setDrawContentsCentered:YES];
    [lockBtn addTarget:self action:@selector(toggleLock:) forEvents: (255)];
    [navBar addSubview:lockBtn];

    // Add "percent" label w/ transparent background
    percent = [[UITextLabel alloc] initWithFrame:navBarRect];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    float backParts[4] = {0, 0, 0, 0};
    [percent setBackgroundColor: CGColorCreate(colorSpace, backParts)];
    [navBar addSubview:percent];

    [self fixButtons];
    
    AVSystemController *avsc = [AVSystemController sharedAVSystemController];

    [[NSNotificationCenter defaultCenter] addObserver:self 
        selector:@selector(volumeChanged:) 
        name:@"AVSystemController_SystemVolumeDidChangeNotification" 
        object:avsc];
        
    [super setInitialized: true];   
    
    [self loadDefaults];
    
} // applicationDidFinishLaunching


// We get this message when the slider is moved/touched
- (void) handleSlider: (id)whatever
{
    //[textView setStart:[slider value]];

    if (whatever == slider)
    {
         int pos = [slider value] * (double)[[textView getText] length] / 100.0;

         [self showPercentage:pos];

         [textView setStart:pos];
    }
         
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

} // deviceOrientationChanged


// Here's the recommended method for doing custom stuff when the screen's rotation has changed... 
- (void) setUIOrientation: (int) o_code {

    // Don't rotate while we have an OK dialog up ...
    if (okDialog || searchBox)
        return;

    [super setUIOrientation: o_code];
    
    if ([self orientationLocked])
       return;
    
    if (![super isInitialized] || ([super getOrientation] == currentOrientation))
        return;
            
    currentOrientation = [super getOrientation];

    struct CGRect FSrect = [self getOrientedViewRect];
    struct CGRect rect;
    
    // Slider will not redraw properly when rotated - so nuke it and recreate it ...
    [self recreateSlider];
    
    // Put the baseTextView in the right spot
    [baseTextView setFrame:FSrect];
    
    // Resize the navbar as well
    rect   = [navBar frame];
    // rect.origin.y = [UIHardware statusBarHeight];
    rect.size.width = FSrect.size.width;
    [navBar setFrame:rect];

    // Set the locked orientation
    // Can't do this during finishedLaunchine because UIOrientation is 
    // not yet set up at that point
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
    
    // We need to redo the layout since the width has changed
    [textView sizeScroller];

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

    // If this is a drag, don't treat it like a mouse up    
    if (![textView getIsDrag])
    {

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
                      [textView scrollPage:Page_Down];
                  else
                      // Move up one page 
                      [textView scrollPage:Page_Up];
                }

                // Both lower  = page forward
                else if (mouseDown.y > lower && mouseUp.y > lower)
                {
                  if (reverseTap)
                      // Move down one page 
                      [textView scrollPage:Page_Up];
                  else
                      // Move up one page 
                      [textView scrollPage:Page_Down];
                }

                // Both middle = show/hide navBar
                else if (mouseDown.y >= upper && mouseDown.y <= lower &&
                         mouseUp.y   >= upper && mouseUp.y   <= lower)
                {
                    [self showView:My_Info_View];
                }

            } // if info view else text view

        } // if we have text to display
        
    } // if not a drag

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


// Force a resize/redraw as needed
- (void) redraw {
    if (currentView == My_Text_View || currentView == My_Info_View)
        [textView setNeedsDisplay];
    else if (currentView == My_File_View)
        [fileTable resize];
    else if (currentView == My_Prefs_View)
        [prefsTable resize];
    else if (currentView == My_Download_View)
        [downloadTable resize];
    else if (currentView == My_Color_View)
        [colorTable resize];
        
} // redraw


// Do the actual load - we split this out so we can show the wait hud ... 
// What a waste - the HUD code ought to work without needing messages on the
// main thread
- (void) openFile2
{
    if (openname && [textView openFile:openname path:openpath])
    {
        [self showView:My_Text_View];
        // [navBar pushNavigationItem: [[UINavigationItem alloc] initWithTitle:openname]];
    }
    else
    {
        [self showView:My_Info_View];
    }

    [self hideWait];
    
} // openFile2


// Only purpose is a wrapper for openFile2 - we have to do it on the main thread
// or it will choke!
- (void) thrdOpenFile:(id)ignored 
{   
    [self performSelectorOnMainThread:@selector(openFile2) 
                            withObject:nil waitUntilDone:YES];
} // thrdOpenFile


// Close currently open file
- (void) closeCurrentFile {
    
   openname = nil;
   [textView closeCurrentFile];
   
   [self redraw];
    
} // closeCurrentFile


// NOTE: We use a thread because otherwise the loading hud won't show up
//       Opening on a thread slows us down, so this is a case where
//       listening to users slows things down even more
//       (kind of like scrolling)
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


// Figure out a type for the specified file based on the extension
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

    if (type == kTextFileTypeUnknown &&
        [fileName length] > ([TEXTREADER_CACHE_EXT length]+1) && 
        [fileName characterAtIndex:[fileName length]-([TEXTREADER_CACHE_EXT length]+1)] == '.')
    {
        NSString * ext = [fileName substringFromIndex:[fileName length]-[TEXTREADER_CACHE_EXT length]];
        
        if (![ext compare:TEXTREADER_CACHE_EXT options:kCFCompareCaseInsensitive ])
            type = kTextFileTypeTRCache;
    }
    
    return type;
    
} // getFileType


- (void) releaseDialog {

  if (okDialog)
  {
      [okDialog dismissAnimated:YES];
      [okDialog release];
      okDialog = nil;
  }
  
} // releaseDialog


- (UIAlertSheet*) getDialog {
    return okDialog;
} // getDialog


- (UIAlertSheet*) showDialog:(NSString*)title  msg:(NSString*)msg  button:(NSString*)button  delegate:(id)delegate
{
        CGRect rect = [[UIWindow keyWindow] bounds];
        
        if (!okDialog)
        {
            okDialog = [[UIAlertSheet alloc] initWithFrame:CGRectMake(0,rect.size.height-240,rect.size.width,240)];
            if (button)
                [okDialog addButtonWithTitle:button];
            [okDialog setTitle:title];
            [okDialog setBodyText:msg];
            [okDialog setDelegate:delegate];
            [okDialog popupAlertAnimated:YES];
        }    

        return okDialog;
        
} // showOKDialog


// This view's alert sheets are just informational ...
// Dismiss them without doing anything special
- (void)alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button 
{

  [self releaseDialog];

} // alertSheet


- (NSString *)stringFromEncoding:(NSStringEncoding)enc {
    // Special case GB2312
    if (enc == TEXTREADER_GB2312)
        return TEXTREADER_GB2312_NAME;
        
    return [NSString localizedNameOfStringEncoding:enc];
    
} // stringFromEncoding


- (NSStringEncoding)encodingFromString:(NSString *)string {
    
    // Special case gb2312
    if ([string compare:TEXTREADER_GB2312_NAME] == NSOrderedSame)
        return TEXTREADER_GB2312;
        
    const NSStringEncoding * enc = [NSString availableStringEncodings];
    
    while (enc && *enc)
    {
        if ([string compare:[NSString localizedNameOfStringEncoding:*enc]] == NSOrderedSame)
           break;
        enc++;
    }
    
    return (enc && *enc) ? *enc : kCGEncodingMacRoman;
    
} // encodingFromString



@end // @implementation textReader






