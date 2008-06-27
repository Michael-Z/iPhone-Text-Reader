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

NSString  *TextAlignmentNames[6];


// **********************************************************************
// Class for Preferences Page
@implementation MyPreferencesTable


- (int) indentFromString:(NSString *)str {
    if (![str compare:_T(@"Original") options:kCFCompareCaseInsensitive])
        return -1;
    else if (![str compare:_T(@"None") options:kCFCompareCaseInsensitive])
        return 0;
    else if (![str compare:_T(@"1 blank") options:kCFCompareCaseInsensitive])
        return 1;
    else if (![str compare:_T(@"2 blanks") options:kCFCompareCaseInsensitive])
        return 2;
    else if (![str compare:_T(@"3 blanks") options:kCFCompareCaseInsensitive])
        return 3;
    else if (![str compare:_T(@"4 blanks") options:kCFCompareCaseInsensitive])
        return 4;
    else if (![str compare:_T(@"5 blanks") options:kCFCompareCaseInsensitive])
        return 5;
    else if (![str compare:_T(@"6 blanks") options:kCFCompareCaseInsensitive])
        return 6;
        
    return 0;
    
} // indentFromString

- (NSString*) stringFromIndent:(int)indent {
    switch (indent)
    {
        case -1:
            return _T(@"Original");
        case 1:
            return _T(@"1 blank");
        case 2:
            return _T(@"2 blanks");
        case 3:
            return _T(@"3 blanks");
        case 4:
            return _T(@"4 blanks");
        case 5:
            return _T(@"5 blanks");
        case 6:
            return _T(@"6 blanks");
        default:
        case 0:
            return _T(@"None");
    }
    
} // stringFromIndent


- (AlignText) alignmentFromString:(NSString *)str {
    AlignText ta;
    
    for (ta = Align_Left; ta <= Align_Justified2; ta++)
    {
        if (![str compare:TextAlignmentNames[ta] options:kCFCompareCaseInsensitive])
            return ta;
    }
    
    // Default to left alignment
    return Align_Left;
    
} // alignmentFromString

- (id)initWithFrame:(CGRect)rect {
    pickerView = nil;
    
    self = [ super initWithFrame: rect ];
    if (nil != self) {
    
        memset(groupcell, sizeof(groupcell), 0x00);
        memset(cells,     sizeof(groupcell), 0x00);
        
        [ self setDataSource: self ];
        [ self setDelegate: self ];
    }
    
    TextAlignmentNames[0] = _T(@"Align Left");
    TextAlignmentNames[1] = _T(@"Align Center");
    TextAlignmentNames[2] = _T(@"Align Right");
    TextAlignmentNames[3] = _T(@"Word Justified");
    TextAlignmentNames[4] = _T(@"Character Justified");
    TextAlignmentNames[5] = nil;
    
    invertScreen = nil;
    cacheAll = nil;
    ignoreSingleLF = nil;
    padMargins = nil;
    indentParagraphsCell = nil;
    reverseTap = nil;
    swipeOK = nil;
    fileScroll = nil;
    repeatLine = nil;
    fontZoom = nil;

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
            // Font Zoom
            // Encoding
            // Encoding2
            // Encoding3
            // Encoding4
            // cache all
            return 8; 

        case(1):
            // Colors
            // Background
            // Invert            
            // Show Cover Art
            // Pad Margins
            // Align Text
            // Indent Margins
            return 7;
            
        case(2):
            // Strip Line Feeds
            return 1;
            
        case(3):
            // Show Status Bar
            return 1;
            
        case(4):
            // Reverse Tap
            // Repeat Line
            // Smooth Scroll
            // File Scroll
            return 4;
        
        case(5):
            // Volume Scroll
            return 1;
            
        case(6):
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
             [ groupcell[group] setTitle: _T(@"Strip Line Feeds") ];
             break;
         case (3):
             [ groupcell[group] setTitle: _T(@"Show Status Bar") ];
             break;
         case (4):
             [ groupcell[group] setTitle: _T(@"Scroll Settings") ];
             break;
         case (5):
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
        if (group < NUM_GROUPS-1)
            return 40;
    }

    return proposed;
}


- (BOOL)preferencesTable:(UIPreferencesTable *)aTable
    isLabelGroup:(int)group
{
    if (group == NUM_GROUPS-1)
        return YES;
        
    return NO;
}


- (void) killPicker {
    // If picker is active, just kill it
    if (pickerView)
    {
        [pickerView removeFromSuperview];
        [pickerView release];
        pickerView = nil;
    }               
} // killPicker


- (void)tableRowSelected:(NSNotification *)notification 
{
    int           i    = [self selectedRow];
    struct CGRect rect = [trApp getOrientedViewRect];
    
    if (pickerView)
    {
        [pickerView removeFromSuperview];
        [pickerView release];
        pickerView = nil;
    }
    
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

        case 4: // Encoding
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_Encoding];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;



        case 5: // Encoding2
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_Encoding2];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;
        case 6: // Encoding3
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_Encoding3];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;
        case 7: // Encoding4
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_Encoding4];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;
        case 10: // Colors
            {   
                [self killPicker];
                [trApp showView:My_Color_View];
            }               
            break;
            
        case 11: // Background
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_BkgImage];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;

        case 15: // textAlignment
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_TextAlignment];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;
            
        case 16: // Indent Paragraphs
            {   
                pickerView = [[MyPickerView alloc] initWithFrame:rect];
                [pickerView setDelegate: self];
                [pickerView setType:kPicker_Type_IndentParagraphs];
                [pickerView setPrefs:self];

                [self addSubview:pickerView];       
            }               
            break;
            
        default:
            [[self cellAtRow:i column:0] setSelected:NO];
            return;
            
    } // switch
    
    // Scroll to top so picker is visible
    [self scrollAndCenterTableCell:fontCell animated:YES];
    
} // tableRowSelected


- (int) numberOfColumnsInPickerView:(UIPickerView*)picker
{
     // Number of columns you want (1 column is like in when clicking an <select /> in Safari, multi columns like a date selector)
     return 1;
}


//datasource methods
- (int) pickerView:(UIPickerView*)picker numberOfRowsInColumn:(int)column{
    return [[pickerView getDataArray] count];
} // pickerView numberOfRowsInColumn


- (UIPickerTableCell*) pickerView:(UIPickerView*)picker tableCellForRow:(int)row inColumn:(int)column{
    UIPickerTableCell *cell = [[UIPickerTableCell alloc] initWithFrame: CGRectMake(0.0f, 0.0f, 320.0f, 32.0f)];
    
    [cell setTitle:[[pickerView getDataArray] objectAtIndex:row]];
    
    [cell setSelectionStyle:0];
    [cell setShowSelection:YES];
    [[cell iconImageView] setFrame:CGRectMake(0,0,0,0)];
    
    return cell;
} // pickerView tableCellForRow


// We get this message when the switch is changed
// Update the value the switch is associated with
- (void) handleSwitch:(id)switchid
{
    if (switchid == swipeOK)
        [trApp setSwipeOK:[swipeOK value] ? 1 : 0];

    else if (switchid == fileScroll)
        [trApp setFileScroll:[fileScroll value] ? 1 : 0];

    else if (switchid == reverseTap)
        [trApp setReverseTap:[reverseTap value] ? 1 : 0];

    else if (switchid == showCoverArt)
        [trApp setShowCoverArt:[showCoverArt value] ? 1 : 0];

    else if (switchid == invertScreen)
        [textView setInvertColors:[invertScreen value] ? true : false];

    else if (switchid == padMargins)
        [textView setPadMargins:[padMargins value] ? 1 : 0];

    else if (switchid == repeatLine)
        [textView setRepeatLine:[repeatLine value] ? 1 : 0];

    else if (switchid == fontZoom)
        [textView setFontZoom:[fontZoom value] ? 1 : 0];

    else if (switchid == cacheAll)
        [textView setCacheAll:[cacheAll value] ? 1 : 0];

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
                    [ cell setTitle:_T(@"Font") ];
                    [ cell setValue:[textView getFont] ];
                    [ cell setShowDisclosure:YES];
                    fontCell = cell;
                    break;
                case (1):
                    [ cell setTitle:_T(@"Font Size") ];
                    [ cell setValue:[NSString stringWithFormat:@"%d", [textView getFontSize]] ];
                    [ cell setShowDisclosure:YES];
                    fontSizeCell = cell;
                    break;
                case (2):
                    [ cell setTitle:_T(@"Font Zoom") ];
                    fontZoom = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ fontZoom setValue: [textView getFontZoom] ? 1 : 0 ];
                    [ fontZoom addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: fontZoom ];
                    break;
                case (3):
                    [ cell setTitle:_T(@"Encoding") ];
                    [ cell setValue:[trApp stringFromEncoding:[textView getEncodings][0]] ];
                    [ cell setShowDisclosure:YES];
                    encodingCell = cell;
                    break;
                case (4):
                    [ cell setTitle:_T(@"2nd Encoding") ];
                    [ cell setValue:[trApp stringFromEncoding:[textView getEncodings][1]] ];
                    [ cell setShowDisclosure:YES];
                    encoding2Cell = cell;
                    break;
                case (5):
                    [ cell setTitle:_T(@"3rd Encoding") ];
                    [ cell setValue:[trApp stringFromEncoding:[textView getEncodings][2]] ];
                    [ cell setShowDisclosure:YES];
                    encoding3Cell = cell;
                    break;
                case (6):
                    [ cell setTitle:_T(@"4th Encoding") ];
                    [ cell setValue:[trApp stringFromEncoding:[textView getEncodings][3]] ];
                    [ cell setShowDisclosure:YES];
                    encoding4Cell = cell;
                    break;
                case (7):
                    [ cell setTitle:_T(@"Cache All Files") ];
                    cacheAll = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ cacheAll setValue: [textView getCacheAll] ? 1 : 0 ];
                    [ cacheAll addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: cacheAll ];
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
                    [ cell setTitle:_T(@"Background") ];
                    [ cell setValue:[textView getBkgImage] ];
                    [ cell setShowDisclosure:YES];
                    bkgImageCell = cell;
                    break;
                case (2):
                    [ cell setTitle:_T(@"Invert Screen") ];
                    invertScreen = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ invertScreen setValue: [textView getInvertColors] ? 1 : 0 ];
                    [ invertScreen addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: invertScreen ];
                    break;
                case (3):
                    [ cell setTitle:_T(@"Show Cover Art") ];
                    showCoverArt = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ showCoverArt setValue: [trApp getShowCoverArt] ? 1 : 0 ];
                    [ showCoverArt addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: showCoverArt ];
                    break;
                case (4):
                    [ cell setTitle:_T(@"Pad Margins") ];
                    padMargins = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ padMargins setValue: [textView getPadMargins] ? 1 : 0 ];
                    [ padMargins addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: padMargins ];
                    break;
                case (5):
                    [ cell setTitle:_T(@"Align Text") ];
                    [ cell setValue:TextAlignmentNames[[textView getTextAlignment]] ];
                    [ cell setShowDisclosure:YES];
                    textAlignmentCell = cell;
                    break;
                case (6):
                    [ cell setTitle:_T(@"Indent Paragraphs") ];
                    [ cell setValue:[self stringFromIndent:[textView getIndentParagraphs]] ];
                    [ cell setShowDisclosure:YES];
                    indentParagraphsCell = cell;
                    break;
            }
            break;
        case (2):
            switch (row) {
                case (0):
                    ignoreSingleLF = [[[UISegmentedControl alloc] initWithFrame:CGRectMake(10.0f, 3.0f, 300.0f, 55.0f)] autorelease];
                    [ignoreSingleLF insertSegment:IgnoreLF_Off    withTitle:_T(@"Off")  animated:NO];
                    [ignoreSingleLF insertSegment:IgnoreLF_Single withTitle:_T(@"Single") animated:NO];
                    [ignoreSingleLF insertSegment:IgnoreLF_Format withTitle:_T(@"Format") animated:NO];
                    [ignoreSingleLF selectSegment:[textView getIgnoreSingleLF]];
                    [ignoreSingleLF setDelegate:self];
                    [cell addSubview: ignoreSingleLF ];
                    [cell setDrawsBackground:NO];
                    break;
            }
            break;
        case (3):
            switch (row) {
                case (0):
                    showStatus = [[[UISegmentedControl alloc] initWithFrame:CGRectMake(10.0f, 3.0f, 300.0f, 55.0f)] autorelease];
                    [showStatus insertSegment:ShowStatus_Off    withTitle:_T(@"Off")   animated:NO];
                    [showStatus insertSegment:ShowStatus_Light  withTitle:_T(@"Solid") animated:NO];
                    [showStatus insertSegment:ShowStatus_Dark   withTitle:_T(@"Clear") animated:NO];
                    [showStatus selectSegment:[trApp getShowStatus]];
                    [showStatus setDelegate:self];
                    [cell addSubview: showStatus ];
                    [cell setDrawsBackground:NO];
                    break;
            }
            break;
        case (4):
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
                case (3):
                    [ cell setTitle:_T(@"File Scroll") ];
                    fileScroll = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                    [ fileScroll setValue: [trApp getFileScroll] ? 1 : 0 ];
                    [ fileScroll addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                    [[ cell titleTextLabel] sizeToFit];
                    [ cell addSubview: fileScroll ];
                    break;
            }
            break;
        case (5):
            switch (row) {
                case (0):
                    volumeScroll = [[[UISegmentedControl alloc] initWithFrame:CGRectMake(10.0f, 3.0f, 300.0f, 55.0f)] autorelease];
                    [volumeScroll insertSegment:VolScroll_Off withTitle:_T(@"Off")  animated:NO];
                    [volumeScroll insertSegment:VolScroll_Line withTitle:_T(@"Line") animated:NO];
                    [volumeScroll insertSegment:VolScroll_Page withTitle:_T(@"Page") animated:NO];
                    [volumeScroll selectSegment:[trApp getVolScroll]];
                    [volumeScroll setDelegate:self];
                    [cell addSubview: volumeScroll ];
                    [cell setDrawsBackground:NO];
                    break;
            }
            break;
        case (6):
            switch (row) {
                case (0):
                    [ cell setTitle: _T(@" ") ];
                    break;
                case (1):
                    [ cell setTitle: TEXTREADER_HOMEPAGE ];
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
    
} // preferencesTable


- (void) segmentedControl:(UISegmentedControl *)segment selectedSegmentChanged:(int)seg
{
    if (segment == volumeScroll)
    {
        [trApp setVolScroll:seg];
    }
    else if (segment == ignoreSingleLF)
    {
        [textView setIgnoreSingleLF:seg];
    }
    else if (segment == showStatus)
    {
        [trApp setShowStatus:seg];
    }
    
} // selectedSegmentChanged


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
                                          @"%@ %@\n%@\n\niphonetextreader@gmail.com\n\nhttp://code.google.com\t\t/p/iphonetextreader",
                                          _T(@"Version"),
                                          TEXTREADER_VERSION,
                                          _T(@"Written by Jim Beesley")];
                NSString *aboutMsg = [NSString stringWithFormat:_T(@"About %@"), TEXTREADER_NAME];
                [trApp showDialog:aboutMsg
                                msg:Msg
                             buttons:DialogButtons_OKWebsite];
            }
            break;

        case 1: // Done
            [self killPicker];
            [trApp showView:My_Info_View];
            break;
    } // switch
    
} // navigationBar



// Save the encodings
-(void)saveEncodings {

    NSStringEncoding encodings[4] = {
                                        [trApp encodingFromString:[encodingCell  value]],
                                        [trApp encodingFromString:[encoding2Cell value]],
                                        [trApp encodingFromString:[encoding3Cell value]],
                                        [trApp encodingFromString:[encoding4Cell value]]
                                    };

    [textView setEncodings:encodings];
        
} // saveEncodings


// Save the font/size
- (bool) saveFont:(NSString*)font size:(int)size {
    return [textView setFont:font size:size];    
} // saveFont


- (void) setFont:(NSString*)font {
    if ([self saveFont:font size:[[fontSizeCell value] intValue]])
        [fontCell setValue:font];
} // setFont


- (void) setFontSize:(NSString*)fontSize {
    if ([self saveFont:[fontCell value] size:[fontSize intValue]])
        [fontSizeCell setValue:fontSize];
} // setFontSize


- (void) setBkgImage:(NSString*)name {
    if ([textView setBkgImage:name])
        [bkgImageCell setValue:[textView getBkgImage]];
} // setBkgImage


- (void) setEncoding:(NSString*)enc {
    [ encodingCell setValue:enc ];    
    [self saveEncodings];
} // setEncoding


- (void) setEncoding2:(NSString*)enc {
    [ encoding2Cell setValue:enc ];    
    [self saveEncodings];
} // setEncoding2


- (void) setEncoding3:(NSString*)enc {
    [ encoding3Cell setValue:enc ];    
    [self saveEncodings];
} // setEncoding3


- (void) setEncoding4:(NSString*)enc {
    [ encoding4Cell setValue:enc ];    
    [self saveEncodings];
} // setEncoding4


- (void) setTextAlignment:(NSString*)ta {
    [ textAlignmentCell setValue:ta ];
    [textView setTextAlignment:[self alignmentFromString:ta]];    
} // setTextAlignment


- (void) setIndentParagraphs:(NSString*)indent {
    [ indentParagraphsCell setValue:indent ];
    [textView setIndentParagraphs:[self indentFromString:indent]];    
} // setIndentParagraphs


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
            
        case kPicker_Type_Encoding2:
            [ prefsTable setEncoding2:[dataArray  objectAtIndex:row] ];
            break;
            
        case kPicker_Type_Encoding3:
            [ prefsTable setEncoding3:[dataArray  objectAtIndex:row] ];
            break;
            
        case kPicker_Type_Encoding4:
            [ prefsTable setEncoding4:[dataArray  objectAtIndex:row] ];
            break;
            
        case kPicker_Type_Font:
            [ prefsTable setFont:[dataArray  objectAtIndex:row] ];
            break;
            
        case kPicker_Type_FontSize:
            [ prefsTable setFontSize:[dataArray  objectAtIndex:row] ];
            break;
            
        case kPicker_Type_TextAlignment:
            [ prefsTable setTextAlignment:[dataArray  objectAtIndex:row] ];
            break;

        case kPicker_Type_IndentParagraphs:
            [ prefsTable setIndentParagraphs:[dataArray  objectAtIndex:row] ];
            break;

        case kPicker_Type_BkgImage:
            [ prefsTable setBkgImage:[dataArray  objectAtIndex:row] ];
            break;
            
    }
                
    return YES;
    
} // canSelectRow


// Remember what the picker is "picking"
-(void) setType:(PickerType)theType {

    int i;
    
    if (dataArray)
        [dataArray release];
        
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

                // These don't look very good, so weed them out up front ...
                NSArray *badFonts = [NSArray arrayWithObjects:
                        @"AppleGothicRegular.ttf",
                        @"DB_LCD_Temp-Black.ttf",
                        @"HelveticaNeue.ttf",
                        @"HelveticaNeueBold.ttf",
                        @"PhonepadTwo.ttf",
                        @"LockClock.ttf",
                        // @"arialuni.ttf",
                        @"Zapfino.ttf", 
                        nil];

                for (font = [enumerator nextObject]; font; font = [enumerator nextObject])
                {
                    if ( [[font pathExtension] isEqualToString:@"ttf"] 
                         && ![badFonts containsObject:font] )
                        [dataArray addObject:[font stringByDeletingPathExtension]];
                    
                } // for each font
            }
            break;
            
        case kPicker_Type_FontSize:
            for(i=10; i<=34; i++)
                [dataArray addObject:[NSString stringWithFormat:@"%i", i]];
            break;

        case kPicker_Type_TextAlignment:
            {
                AlignText ta;
                for(ta=Align_Left; ta<=Align_Justified2; ta++)
                    [dataArray addObject:TextAlignmentNames[ta]];
            }
            break;

        case kPicker_Type_IndentParagraphs:
            [dataArray addObject:_T(@"Original")];
            [dataArray addObject:_T(@"None")];
            [dataArray addObject:_T(@"1 blank")];
            [dataArray addObject:_T(@"2 blanks")];
            [dataArray addObject:_T(@"3 blanks")];
            [dataArray addObject:_T(@"4 blanks")];
            [dataArray addObject:_T(@"5 blanks")];
            [dataArray addObject:_T(@"6 blanks")];
            break;

        case kPicker_Type_BkgImage:
            [dataArray addObject:_T(@"None")];
            
            NSString * path = [[NSString alloc] initWithFormat:@"/Applications/%@.app/images", TEXTREADER_NAME];
            NSArray  * contents = [[NSFileManager defaultManager] directoryContentsAtPath:path];
            for (i = 0; i < [contents count]; i++)
            {
                NSString * file = [contents objectAtIndex:i];
                BOOL isDir = false;

                if ([[NSFileManager defaultManager] 
                      fileExistsAtPath:[path stringByAppendingPathComponent:file] 
                      isDirectory:&isDir] && !isDir) 
                {
                    NSString * ext = [file pathExtension];
                    
                    if (![ext compare:@"png" options:kCFCompareCaseInsensitive]  ||
                        ![ext compare:@"jpg" options:kCFCompareCaseInsensitive]  ||
                        ![ext compare:@"jpeg" options:kCFCompareCaseInsensitive] ||
                        ![ext compare:@"bmp" options:kCFCompareCaseInsensitive])
                        [dataArray addObject:file];
                }
                
            } // for each file in images directory
            break;

        case kPicker_Type_Encoding:
        case kPicker_Type_Encoding2:
        case kPicker_Type_Encoding3:
        case kPicker_Type_Encoding4:
            {
                // Add No Encoding Specified to 2/3/4 but not 0 ...
                if (type != kPicker_Type_Encoding)
                    [dataArray addObject:TEXTREADER_ENC_NONE_NAME];
                
                // Special case GB2312
                [dataArray addObject:TEXTREADER_GB2312_NAME];
                
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
