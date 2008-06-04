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



#import "PrefsTable.h"
#import "textReader.h"
#import "MyTextView.h"

static const int kUIControlEventMouseUpInside = 1 << 6;



// **********************************************************************
@implementation MySegControl
- (void)mouseUp:(struct __GSEvent *)event;
{
    [trApp setVolScroll:[self selectedSegment]];
}

- (void) setTextReader:(textReader*)tr {
    trApp = tr;
} // setTextReader

@end


// **********************************************************************
// Class for Preferences Page
@implementation MyPreferencesTable

- (id)initWithFrame:(CGRect)rect {
    pickerView = nil;
    
    self = [ super initWithFrame: rect ];
    if (nil != self) {
    
        memset(groupcell, sizeof(groupcell), 0x00);
        memset(cells,     sizeof(groupcell), 0x00);
        
        [ self setDataSource: self ];
        [ self setDelegate: self ];
    }
    
    invertScreen = nil;
    ignoreSingleLF = nil;
    padMargins = nil;
    reverseTap = nil;
    swipeOK = nil;
    repeatLine = nil;

    return self;
}


- (int)numberOfGroupsInPreferencesTable:(UIPreferencesTable *)aTable {

    /* Number of logical groups, including labels */
    return NUM_GROUPS;
}


- (int)preferencesTable:(UIPreferencesTable *)aTable
    numberOfRowsInGroup:(int)group
{
    switch (group) {
        case(0):
            // Font
            // Font Size
            // Encoding
            return 3; 

        case(1):
            // Invert
            // Colors
            // Pad Margins
            // Ignore Single LF
            return 4;
            
        case(2):
            // Reverse Tap
            // Repeat Line
            // Allow Swipe
            return 3;
        
        case(3):
            // Volume Scroll
            return 1;
            
        case(4):
            // Blank line
            // Web Site
            // Email address
            return 3;
    }
    return 0;
}


- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable
    cellForGroup:(int)group
{
     if (groupcell[group] != NULL)
         return groupcell[group];

     groupcell[group] = [ [ UIPreferencesTableCell alloc ] init ];
     switch (group) {
         case (0):
             [ groupcell[group] setTitle: _T(@"Text Settings") ];
             break;
         case (1):
             [ groupcell[group] setTitle: _T(@"Display Settings") ];
             break;
         case (2):
             [ groupcell[group] setTitle: _T(@"Scroll Settings") ];
             break;
         case (3):
             [ groupcell[group] setTitle: _T(@"Volume Button Scroll") ];
             break;
     }
     return groupcell[group];
}


- (float)preferencesTable:(UIPreferencesTable *)aTable
    heightForRow:(int)row
    inGroup:(int)group
    withProposedHeight:(float)proposed
{
    /* Return height for group titles */
    if (row == -1) {
        if (group < 4)
            return 40; // JIMB BUG BUG
    }

    return proposed;
}


- (BOOL)preferencesTable:(UIPreferencesTable *)aTable
    isLabelGroup:(int)group
{
    if (group == 4)
        return YES;
        
    return NO;
}


- (NSStringEncoding)encodingFromString:(NSString *)string {
    const NSStringEncoding * enc = [NSString availableStringEncodings];
        
    while (enc && *enc)
    {
        if ([string compare:[NSString localizedNameOfStringEncoding:*enc]] == NSOrderedSame)
           break;
        enc++;
    }
    
    return (enc && *enc) ? *enc : kCGEncodingMacRoman;
} // encodingFromString


// Called when we leave this view
-(void)saveSettings {

    // If picker is active, just kill it
    if (pickerView)
    {
        [pickerView release];
        pickerView = nil;
    }               

    // Apply preferences ...            
    NSString * font  = [fontCell value];
    int        size  = [[fontSizeCell value] intValue];

    [textView setFont:font size:size];

    [textView setEncoding:[self encodingFromString:[encodingCell value]]];

} // saveSettings


- (void)tableRowSelected:(NSNotification *)notification 
{
    int           i    = [self selectedRow];
    struct CGRect rect = [trApp getOrientedViewRect];
    
    if (pickerView)
        [pickerView release];
    pickerView = nil;
    
    switch (i)
    {
        case 1: // font
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_Font];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;

        case 2: // font Size
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_FontSize];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;

        case 3: // Encoding
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_Encoding];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;

        case 5: // Colors
            {   
                [self saveSettings];
                [trApp showView:My_Color_View];
            }               
            break;
       
        default:
            [[self cellAtRow:i column:0] setSelected:NO];
            break;
            
    } // switch
    
} // tableRowSelected


- (int) numberOfColumnsInPickerView:(UIPickerView*)picker
{
     // Number of columns you want (1 column is like in when clicking an <select /> in Safari, multi columns like a date selector)
     return 1;
}


//datasource methods
- (int) pickerView:(UIPickerView*)picker numberOfRowsInColumn:(int)column{
    return [[pickerView getDataArray] count];
}


- (UIPickerTableCell*) pickerView:(UIPickerView*)picker tableCellForRow:(int)row inColumn:(int)column{
    UIPickerTableCell *cell = [[UIPickerTableCell alloc] initWithFrame: CGRectMake(0.0f, 0.0f, 320.0f, 32.0f)];
    
    [cell setTitle:[[pickerView getDataArray] objectAtIndex:row]];
    
    [cell setSelectionStyle:0];
    [cell setShowSelection:YES];
    [[cell iconImageView] setFrame:CGRectMake(0,0,0,0)];
    return cell;
}

// We get this message when the switch is changed
// Update the value the switch is associated with
- (void) handleSwitch:(id)switchid
{
    if (switchid == swipeOK)
        [trApp setSwipeOK:[swipeOK value] ? 1 : 0];

    else if (switchid == reverseTap)
        [trApp setReverseTap:[reverseTap value] ? 1 : 0];

    else if (switchid == invertScreen)
        [textView setInvertColors:[invertScreen value] ? true : false];

    else if (switchid == ignoreSingleLF)
        [textView setIgnoreSingleLF:[ignoreSingleLF value]  ? 1 : 0];

    else if (switchid == padMargins)
        [textView setPadMargins:[padMargins value] ? 1 : 0];

    else if (switchid == repeatLine)
        [textView setRepeatLine:[repeatLine value] ? 1 : 0];

} // handleSwitch


// Create the cells for the prefs table
- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable
    cellForRow:(int)row
    inGroup:(int)group
{
    UIPreferencesTableCell *cell;
    
    if (cells[group][row])
        return cells[group][row];

    cell = [ [ UIPreferencesTableCell alloc ] init ];
    [ cell setEnabled: YES ];

    switch (group) {
        case (0):
            switch (row) {
                case (0):
                    [ cell release ];
                    cell = [ [ UIPreferencesTableCell alloc ] init ];
                    [ cell setTitle:_T(@"Font") ];
                    [ cell setValue:[textView getFont] ];
                    [ cell setShowDisclosure:YES];
                    fontCell = cell;
                    break;
                case (1):
                    [ cell release ];
                    cell = [ [ UIPreferencesTableCell alloc ] init ];
                    [ cell setTitle:_T(@"Font Size") ];
                    [ cell setValue:[NSString stringWithFormat:@"%d", [textView getFontSize]] ];
                    [ cell setShowDisclosure:YES];
                    fontSizeCell = cell;
                    break;
                case (2):
                    [ cell release ];
                    cell = [ [ UIPreferencesTableCell alloc ] init ];
                    [ cell setTitle:_T(@"Encoding") ];
                    [ cell setValue:[NSString localizedNameOfStringEncoding:[textView getEncoding]] ];
                    [ cell setShowDisclosure:YES];
                    encodingCell = cell;
                    break;
           }
           break;
        case (1):
            switch (row) {
                case (0):
                    [ cell setTitle:_T(@"Select Colors") ];
                    [ cell setShowDisclosure:YES];
                    colorsCell = cell;
                    break;
                case (1):
                    [ cell setTitle:_T(@"Invert Screen") ];
                    invertScreen = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ invertScreen setValue: [textView getInvertColors] ? 1 : 0 ];
                    [ invertScreen addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: invertScreen ];
                    break;
                case (2):
                    [ cell setTitle:_T(@"Pad Margins") ];
                    padMargins = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ padMargins setValue: [textView getPadMargins] ? 1 : 0 ];
                    [ padMargins addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: padMargins ];
                    break;
                case (3):
                    [ cell setTitle:_T(@"Ignore Single LF") ];
                    ignoreSingleLF = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ ignoreSingleLF setValue: [textView getIgnoreSingleLF] ? 1 : 0 ];
                    [ ignoreSingleLF addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: ignoreSingleLF ];
                    break;
            }
            break;
        case (2):
            switch (row) {
                case (0):
                    [ cell setTitle:_T(@"Reverse Tap Zones") ];
                    reverseTap = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ reverseTap setValue: [trApp getReverseTap] ? 1 : 0 ];
                    [ reverseTap addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: reverseTap ];
                    break;
                case (1):
                    [ cell setTitle:_T(@"Repeat Previous Line") ];
                    repeatLine = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ repeatLine setValue: [textView getRepeatLine] ? 1 : 0 ];
                    [ repeatLine addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: repeatLine ];
                    break;
                case (2):
                    [ cell setTitle:_T(@"Smooth Scroll") ];
                    swipeOK = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ swipeOK setValue: [trApp getSwipeOK] ? 1 : 0 ];
                    [ swipeOK addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: swipeOK ];
                    break;
            }
            break;
        case (3):
            switch (row) {
                case (0):
                    {    
                        // volumeScroll = [[[UISegmentedControl alloc] initWithFrame:CGRectMake(20.0f, 3.0f, 280.0f, 55.0f)] autorelease];
                        volumeScroll = [[[MySegControl alloc] initWithFrame:CGRectMake(20.0f, 3.0f, 280.0f, 55.0f)] autorelease];
                        [volumeScroll setTextReader:trApp];
                        [volumeScroll insertSegment:0 withTitle:_T(@"Off")  animated:NO];
                        [volumeScroll insertSegment:1 withTitle:_T(@"Line") animated:NO];
                        [volumeScroll insertSegment:2 withTitle:_T(@"Page") animated:NO];
                        [volumeScroll selectSegment:[trApp getVolScroll]];
                        [cell addSubview: volumeScroll ];
                        [cell setDrawsBackground:NO];
                    }
                    break;
            }
            break;
        case (4):
            switch (row) {
                case (0):
                    [ cell setTitle: _T(@" ") ];
                    break;
                case (1):
                    [ cell setTitle: _T(@"http://code.google.com/p/iphonetextreader") ];
                    break;
                case (2):
                    [ cell setTitle: _T(@"email: iphonetextreader@gmail.com") ];
                    break;
            }
            break;
    }

    [ cell setShowSelection: NO ];
    cells[group][row] = cell;
    return cell;
}


- (void) setTextReader:(textReader*)tr {
    trApp = tr;
} // setTextReader


- (void) setTextView:(MyTextView*)tv {
    textView = tv;
} // setTextView


- (void) resize {
    struct CGRect FSrect = [trApp getOrientedViewRect];

    // Resize picker on rotation
    if (pickerView)
    {
        struct CGRect rect = [pickerView frame];
        
        rect.size.width = FSrect.size.width;
        
        [pickerView setFrame:rect];
    }
    
    FSrect.origin.y    += [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
    FSrect.size.height -= [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
    [self setFrame:FSrect];
    [self _updateVisibleCellsImmediatelyIfNecessary];
    
    [self setNeedsDisplay];
    
} // resize


- (void)navigationBar:(UINavigationBar*)navbar buttonClicked:(int)button 
{
    switch (button) {
        case 0: // About
            {
                // [trApp lockUIOrientation];
                NSString *Msg = [NSString stringWithFormat:
                                          //_T(@"version %@\nwritten by Jim Beesley\n\niphonetextreader@gmail.com\n\nhttp://code.google.com\t\t/p/iphonetextreader"),
                                          //TEXTREADER_VERSION];
                                          @"%@ %@\n%@\n\niphonetextreader@gmail.com\n\nhttp://code.google.com\t\t/p/iphonetextreader",
                                          _T(@"Version"),
                                          TEXTREADER_VERSION,
                                          _T(@"Written by Jim Beesley")];
                struct CGRect rect = [trApp getOrientedViewRect];
                UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
                NSString *aboutMsg = [NSString stringWithFormat:_T(@"About %@"), TEXTREADER_NAME];
                [alertSheet setTitle:aboutMsg];
                [alertSheet setBodyText:Msg];
                [alertSheet addButtonWithTitle:_T(@"OK")];
                [alertSheet setDelegate:self];
                [alertSheet popupAlertAnimated:YES];
            }
            break;

        case 1: // Done
            [self saveSettings];
            [trApp showView:My_Info_View];
            break;
    } // switch
    
} // navigationBar


// This view's alert sheets are just informational ...
// Dismiss them without doing anything special
- (void)alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button 
{
  [sheet dismissAnimated:YES];
  [sheet release];
} // alertSheet


- (void) setFont:(NSString*)font {
    [ fontCell setValue:font ];
} // setFont


- (void) setEncoding:(NSString*)enc {
    [ encodingCell setValue:enc ];    
} // setFont


- (void) setFontSize:(NSString*)fontSize {
    [ fontSizeCell setValue:fontSize ];
} // setFontSize


- (void)dealloc {
  [super dealloc];
} // dealloc


@end



// **********************************************************************
// Class for Picker
@implementation MyPickerView


-(BOOL)table:(UIPickerTable*)table canSelectRow:(int)row {
    [self removeFromSuperview];
    
    // Do something based on the ROW!!!!
    switch (type)
    {
        case kPicker_Type_None:
            break;

        case kPicker_Type_Encoding:
            [ prefsTable setEncoding:[dataArray  objectAtIndex:row] ];
            break;
            
        case kPicker_Type_Font:
            [ prefsTable setFont:[dataArray  objectAtIndex:row] ];
            break;
            
        case kPicker_Type_FontSize:
            [ prefsTable setFontSize:[dataArray  objectAtIndex:row] ];
            break;
    }
                
    return YES;
} // canSelectRow


-(void) setType:(PickerType)theType {

    int i;
    
    dataArray = [[NSMutableArray arrayWithCapacity:1] retain];
    
    type = theType;
    
    switch (type)
    {
        case kPicker_Type_None:
            break;

        case kPicker_Type_Font:
            {       
                // Based on code in Books.app       
                NSString * fontFolderPath = @"/System/Library/Fonts/";
                NSArray * fontsFolderContents = [[NSFileManager defaultManager] directoryContentsAtPath:fontFolderPath];
                NSEnumerator * enumerator = [fontsFolderContents objectEnumerator];
                NSString * font;

                NSArray *badFonts = 
                    [NSArray arrayWithObjects:
                    @"AppleGothicRegular.ttf",
                    @"DB_LCD_Temp-Black.ttf",
                    @"HelveticaNeue.ttf",
                    @"HelveticaNeueBold.ttf",
                    @"PhonepadTwo.ttf",
                    @"LockClock.ttf",
                    // @"arialuni.ttf",
                    @"Zapfino.ttf", nil];

                for (font = [enumerator nextObject]; font; font = [enumerator nextObject])
                {
                    if ( [[font pathExtension] isEqualToString:@"ttf"] 
                         && ![badFonts containsObject:font] )
                    {
                        [dataArray addObject:[font stringByDeletingPathExtension]];
                    }
                } // for
            }
            break;
            
        case kPicker_Type_FontSize:
            for(i=12; i<=32; i+=2)
                [dataArray addObject:[NSString stringWithFormat:@"%i", i]];
            break;

        case kPicker_Type_Encoding:
            {
                // Add a list of available encodings to the data array
                const NSStringEncoding *enc = [NSString availableStringEncodings];

                while (enc && *enc)
                   [dataArray addObject:[NSString localizedNameOfStringEncoding:*(enc++)]];
            }
            break;          
    }
    
} // setType


- (PickerType) getType {
    return type;
} // getType


-(void) setPrefs:(MyPreferencesTable*)prefs {
    prefsTable = prefs;
} // setPrefs


-(NSMutableArray*) getDataArray {
    return dataArray;
} // getDataArray


// Clean up picker !!!!
- (void)dealloc {
  [self removeFromSuperview];
  [dataArray release];
  [super dealloc];
} // dealloc


@end
