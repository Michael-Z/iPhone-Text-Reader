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


extern TREncoding trEncodings[];
extern int        trEncodingsL;

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


- (id)initWithFrame:(CGRect)rect trApp:(textReader*)tr {

    trApp = tr;

    self = [ super initWithFrame: rect ];
    if (self) {

        memset(groupcell, sizeof(groupcell), 0x00);
        memset(cells,     sizeof(groupcell), 0x00);

        [ self setDataSource: self ];
        [ self setDelegate: self ];

        TextAlignmentNames[0] = _T(@"Align Left");
        TextAlignmentNames[1] = _T(@"Align Center");
        TextAlignmentNames[2] = _T(@"Align Right");
        TextAlignmentNames[3] = _T(@"Word Justified");
        TextAlignmentNames[4] = _T(@"Character Justified");
        TextAlignmentNames[5] = nil;

        textSettings = nil;
        displaySettings = nil;
        scrollSettings = nil;
        otherSettings = nil;

        invertScreen = nil;
        padMargins = nil;
        reverseTap = nil;
        repeatLine = nil;
        swipeOK = nil;
        showCoverArt = nil;
        fontZoom = nil;
        cacheAll = nil;
        deleteCacheDir = nil;
        searchWrap = nil;
        searchWord = nil;
        textView = nil;
        pickerView = nil;
        fontCell = nil;
        fontSizeCell = nil;
        encodingCell = nil;
        encoding2Cell = nil;
        encoding3Cell = nil;
        encoding4Cell = nil;
        colorsCell = nil;
        textAlignmentCell = nil;
        bkgImageCell = nil;
        indentParagraphsCell = nil;
        ignoreSingleLF = nil;
        showStatus = nil;
        volumeScroll = nil;
        fileScroll = nil;
        rememberURL = nil;

    }

    return self;
}


/*
    switch ([trApp getCurrentView])
    {
        case My_Text_Prefs_View:
            break;
        case My_Display_Prefs_View:
            break;
        case My_Scroll_Prefs_View:
            break;
        case My_Other_Prefs_View:
            break;
        default:
        case My_Prefs_View:
            break;
    }
*/
- (int)numberOfGroupsInPreferencesTable:(UIPreferencesTable *)aTable {

    /* Number of logical groups, including labels */
    switch ([trApp getCurrentView])
    {
        case My_Text_Prefs_View:
            return 2;

        case My_Display_Prefs_View:
            return 4;

        case My_Scroll_Prefs_View:
            return 4;

        case My_Other_Prefs_View:
            return 3;

        default:
        case My_Prefs_View:
            return 5;
    }
} // numberOfGroupsInPreferencesTable


- (int)preferencesTable:(UIPreferencesTable *)aTable
    numberOfRowsInGroup:(int)group
{
    switch ([trApp getCurrentView])
    {
        case My_Text_Prefs_View:
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
                    // Delete Cache Dir
                    return 9;
                case(1):
                    // Web Site
                    // Email address
                    return 2;
            }
            break;
        case My_Display_Prefs_View:
            switch (group) {
                case(0):
                    // Colors
                    // Background
                    // Invert
                    // Show Cover Art
                    // Pad Margins
                    // Align Text
                    // Indent Margins
                    return 7;
                case(1):
                    // Strip Line Feeds
                    return 1;
                case(2):
                    // Show Status Bar
                    return 1;
                case(3):
                    // Web Site
                    // Email address
                    return 2;
            }
            break;
        case My_Scroll_Prefs_View:
            switch (group) {
                case(0):
                    // Reverse Tap
                    // Repeat Line
                    // Smooth Scroll
                    return 3;
                case(1):
                    // File Scroll
                    return 1;
                case(2):
                    // Volume Scroll
                    return 1;
                case(3):
                    // Web Site
                    // Email address
                    return 2;
            }
            break;
        case My_Other_Prefs_View:
            switch (group) {
                case(0):
                    // search wrap
                    // search word
                    return 2;
                case(1):
                    // remember URL
                    return 1;
                case(2):
                    // Web Site
                    // Email address
                    return 2;
            }
            break;
        default:
        case My_Prefs_View:
            switch (group) {
                case(0):
                    // text settings
                    return 1;
                case(1):
                    // display settings
                    return 1;
                case(2):
                    // scroll settings
                    return 1;
                case(3):
                    // other settings
                    return 1;
                case(4):
                    // Web Site
                    // Email address
                    return 2;
            }
            break;
    }

    return 0;

} // numberOfRowsInGroup


- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable
    cellForGroup:(int)group
{
     if (groupcell[group] != NULL)
         return groupcell[group];

    groupcell[group] = [ [ UIPreferencesTableCell alloc ] init ];
    switch ([trApp getCurrentView])
    {
        case My_Text_Prefs_View:
            if (group == 0)
               [ groupcell[group] setTitle: _T(@"Text Settings") ];
            break;
        case My_Display_Prefs_View:
            if (group == 0)
               [ groupcell[group] setTitle: _T(@"Display Settings") ];
            else if (group == 1)
               [ groupcell[group] setTitle: _T(@"Strip Line Feeds") ];
            else if (group == 2)
               [ groupcell[group] setTitle: _T(@"Show Status Bar") ];
            break;
        case My_Scroll_Prefs_View:
            if (group == 0)
               [ groupcell[group] setTitle: _T(@"Scroll Settings") ];
            else if (group == 1)
               [ groupcell[group] setTitle: _T(@"Scroll To Next File") ];
            else if (group == 2)
               [ groupcell[group] setTitle: _T(@"Volume Button Scroll") ];
            break;
        case My_Other_Prefs_View:
            if (group == 0)
               [ groupcell[group] setTitle: _T(@"Other Settings") ];
            else if (group == 1)
               [ groupcell[group] setTitle: _T(@"Download Settings") ];
            break;
        default:
        case My_Prefs_View:
            if (group == 0)
               [ groupcell[group] setTitle: _T(@"Settings") ];
            break;
    }

    return groupcell[group];
} // cellForGroup


- (float)preferencesTable:(UIPreferencesTable *)aTable
    heightForRow:(int)row
    inGroup:(int)group
    withProposedHeight:(float)proposed
{
    if (row == -1) {
        switch ([trApp getCurrentView])
        {
            case My_Text_Prefs_View:
                if (group == 0)
                    return 40;
                return 8;
            case My_Display_Prefs_View:
                if (group < 3)
                    return 40;
                return 8;
            case My_Scroll_Prefs_View:
                if (group < 3)
                    return 40;
                return 8;
            case My_Other_Prefs_View:
                if (group < 2)
                    return 40;
                return 8;
            default:
            case My_Prefs_View:
                if (group == 0)
                    return 40;
                return 8;
        }
    }


//    /* Return height for group titles */
//    if (row == -1) {
//        if (group < NUM_GROUPS-1)
//           return 40;
//    }

    return proposed;
} // withProposedHeight


- (BOOL)preferencesTable:(UIPreferencesTable *)aTable
    isLabelGroup:(int)group
{

    switch ([trApp getCurrentView])
    {
        case My_Text_Prefs_View:
            if (group == 1)
                return YES;
            break;
        case My_Display_Prefs_View:
            if (group == 3)
                return YES;
            break;
        case My_Scroll_Prefs_View:
            if (group == 3)
                return YES;
            break;
        case My_Other_Prefs_View:
            if (group == 2)
                return YES;
            break;
        default:
        case My_Prefs_View:
            if (group == 4)
                return YES;
            break;
    }

    return NO;
} // isLabelGroup


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

    [[self cellAtRow:i column:0] setSelected:NO];

    switch ([trApp getCurrentView])
    {
        case My_Text_Prefs_View:
            switch (i) {
                case 1: // font
                    {
                        //rect.origin.y = [fontCell frame].origin.y;
                        pickerView = [[MyPickerView alloc] initWithFrame:rect];
                        [pickerView setDelegate: self];
                        [pickerView setType:kPicker_Type_Font];
                        [pickerView setPrefs:self];

                        [self addSubview:pickerView];
                        [self scrollAndCenterTableCell:fontCell animated:YES];
                    }
                    break;
                case 2: // font Size
                    {
                        //rect.origin.y = [fontSizeCell frame].origin.y;
                        pickerView = [[MyPickerView alloc] initWithFrame:rect];
                        [pickerView setDelegate: self];
                        [pickerView setType:kPicker_Type_FontSize];
                        [pickerView setPrefs:self];

                        [self addSubview:pickerView];
                        [self scrollAndCenterTableCell:fontCell animated:YES];
                    }
                    break;
                case 4: // Encoding
                    {
                        //rect.origin.y = [encodingCell frame].origin.y;
                        pickerView = [[MyPickerView alloc] initWithFrame:rect];
                        [pickerView setDelegate: self];
                        [pickerView setType:kPicker_Type_Encoding];
                        [pickerView setPrefs:self];

                        [self addSubview:pickerView];
                        [self scrollAndCenterTableCell:fontCell animated:YES];
                    }
                    break;
                case 5: // Encoding2
                    {
                        //rect.origin.y = [encoding2Cell frame].origin.y;
                        pickerView = [[MyPickerView alloc] initWithFrame:rect];
                        [pickerView setDelegate: self];
                        [pickerView setType:kPicker_Type_Encoding2];
                        [pickerView setPrefs:self];

                        [self addSubview:pickerView];
                        [self scrollAndCenterTableCell:fontCell animated:YES];
                    }
                    break;
                case 6: // Encoding3
                    {
                        //rect.origin.y = [encoding3Cell frame].origin.y;
                        pickerView = [[MyPickerView alloc] initWithFrame:rect];
                        [pickerView setDelegate: self];
                        [pickerView setType:kPicker_Type_Encoding3];
                        [pickerView setPrefs:self];

                        [self addSubview:pickerView];
                        [self scrollAndCenterTableCell:fontCell animated:YES];
                    }
                    break;
                case 7: // Encoding4
                    {
                        //rect.origin.y = [encoding4Cell frame].origin.y;
                        pickerView = [[MyPickerView alloc] initWithFrame:rect];
                        [pickerView setDelegate: self];
                        [pickerView setType:kPicker_Type_Encoding4];
                        [pickerView setPrefs:self];

                        [self addSubview:pickerView];
                        [self scrollAndCenterTableCell:fontCell animated:YES];
                    }
                    break;
            }
            break;
        case My_Display_Prefs_View:
            switch (i) {
                case 1: // Colors
                    {
                        [self killPicker];
                        [trApp showView:My_Color_View];
                    }
                    break;
                case 2: // Background
                    {
                        //rect.origin.y = [bkgImageCell frame].origin.y;
                        pickerView = [[MyPickerView alloc] initWithFrame:rect];
                        [pickerView setDelegate: self];
                        [pickerView setType:kPicker_Type_BkgImage];
                        [pickerView setPrefs:self];

                        [self addSubview:pickerView];
                        [self scrollAndCenterTableCell:colorsCell animated:YES];
                    }
                    break;
                case 6: // textAlignment
                    {
                        //rect.origin.y = [textAlignmentCell frame].origin.y;
                        pickerView = [[MyPickerView alloc] initWithFrame:rect];
                        [pickerView setDelegate: self];
                        [pickerView setType:kPicker_Type_TextAlignment];
                        [pickerView setPrefs:self];

                        [self addSubview:pickerView];
                        [self scrollAndCenterTableCell:colorsCell animated:YES];
                    }
                    break;
                case 7: // Indent Paragraphs
                    {
                        //rect.origin.y = [indentParagraphsCell frame].origin.y;
                        pickerView = [[MyPickerView alloc] initWithFrame:rect];
                        [pickerView setDelegate: self];
                        [pickerView setType:kPicker_Type_IndentParagraphs];
                        [pickerView setPrefs:self];

                        [self addSubview:pickerView];
                        [self scrollAndCenterTableCell:colorsCell animated:YES];
                    }
                    break;
            }
            break;
        case My_Scroll_Prefs_View:
            break;
        case My_Other_Prefs_View:
            break;
        default:
        case My_Prefs_View:
            switch (i) {
                case 1: // text settings
                    [trApp showView:My_Text_Prefs_View];
                    break;
                case 3: // display settings
                    [trApp showView:My_Display_Prefs_View];
                    break;
                case 5: // scroll settings
                    [trApp showView:My_Scroll_Prefs_View];
                    break;
                case 7: // other settings
                    [trApp showView:My_Other_Prefs_View];
                    break;
            }
            break;
    }

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

    else if (switchid == searchWrap)
        [trApp setSearchWrap:[searchWrap value] ? 1 : 0];

    else if (switchid == searchWord)
        [trApp setSearchWord:[searchWord value] ? 1 : 0];

    else if (switchid == rememberURL)
        [trApp setRememberURL:[rememberURL value] ? 1 : 0];

    else if (switchid == deleteCacheDir)
        [trApp setDeleteCacheDir:[deleteCacheDir value] ? 1 : 0];

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


    switch ([trApp getCurrentView])
    {
        case My_Text_Prefs_View:
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
                        case (8):
                            [ cell setTitle:_T(@"Delete Cache Dir") ];
                            deleteCacheDir = [ [ UISwitchControl alloc ]
                                initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                            [ deleteCacheDir setValue: [trApp getDeleteCacheDir] ? 1 : 0 ];
                            [ deleteCacheDir addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                            [[ cell titleTextLabel] sizeToFit];
                            [ cell addSubview: deleteCacheDir ];
                            break;
                   }
                   break;
                case (1):
                    switch (row) {
                        case (0):
                            [ cell setTitle: TEXTREADER_HOMEPAGE ];
                            break;
                        case (1):
                            [ cell setTitle: _T(@"email: iphonetextreader@gmail.com") ];
                            break;
                    }
                    break;
            }
            break;
        case My_Display_Prefs_View:
            switch (group) {
                case (0):
                    switch (row) {
                        case (0):
                            [ cell setTitle:_T(@"Select Colors") ];
                            [ cell setShowDisclosure:YES];
                            [ cell setEnabled:YES ];
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
                case (1):
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
                case (2):
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
                case (3):
                    switch (row) {
                        case (0):
                            [ cell setTitle: TEXTREADER_HOMEPAGE ];
                            break;
                        case (1):
                            [ cell setTitle: _T(@"email: iphonetextreader@gmail.com") ];
                            break;
                    }
                    break;
            }
            break;
        case My_Scroll_Prefs_View:
            switch (group) {
                case (0):
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
                case (1):
                    fileScroll = [[[UISegmentedControl alloc] initWithFrame:CGRectMake(10.0f, 3.0f, 300.0f, 55.0f)] autorelease];
                    [fileScroll insertSegment:VolScroll_Off withTitle:_T(@"Off")  animated:NO];
                    [fileScroll insertSegment:VolScroll_Line withTitle:[NSString stringWithFormat:@"<%@<", _T(@"Left")] animated:NO];
                    [fileScroll insertSegment:VolScroll_Page withTitle:[NSString stringWithFormat:@">%@>", _T(@"Right")] animated:NO];
                    [fileScroll selectSegment:[trApp getFileScroll]];
                    [fileScroll setDelegate:self];
                    [cell addSubview: fileScroll ];
                    [cell setDrawsBackground:NO];
                    break;
                case (2):
                    volumeScroll = [[[UISegmentedControl alloc] initWithFrame:CGRectMake(10.0f, 3.0f, 300.0f, 55.0f)] autorelease];
                    [volumeScroll insertSegment:VolScroll_Off withTitle:_T(@"Off")  animated:NO];
                    [volumeScroll insertSegment:VolScroll_Line withTitle:_T(@"Line") animated:NO];
                    [volumeScroll insertSegment:VolScroll_Page withTitle:_T(@"Page") animated:NO];
                    [volumeScroll selectSegment:[trApp getVolScroll]];
                    [volumeScroll setDelegate:self];
                    [cell addSubview: volumeScroll ];
                    [cell setDrawsBackground:NO];
                    break;
                case (3):
                    switch (row) {
                        case (0):
                            [ cell setTitle: TEXTREADER_HOMEPAGE ];
                            break;
                        case (1):
                            [ cell setTitle: _T(@"email: iphonetextreader@gmail.com") ];
                            break;
                    }
                    break;
            }
            break;
        case My_Other_Prefs_View:
            switch (group) {
                case (0):
                    switch (row) {
                        case (0):
                            [ cell setTitle:_T(@"Match Whole Words") ];
                            searchWord = [ [ UISwitchControl alloc ]
                                initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                            [ searchWord setValue: [trApp getSearchWord] ? 1 : 0 ];
                            [ searchWord addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                            [[ cell titleTextLabel] sizeToFit];
                            [ cell addSubview: searchWord ];
                            break;
                        case (1):
                            [ cell setTitle:_T(@"Wrap Searches") ];
                            searchWrap = [ [ UISwitchControl alloc ]
                                initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                            [ searchWrap setValue: [trApp getSearchWrap] ? 1 : 0 ];
                            [ searchWrap addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                            [[ cell titleTextLabel] sizeToFit];
                            [ cell addSubview: searchWrap ];
                            break;
                    }
                    break;
                case (1):
                    switch (row) {
                        case (0):
                            [ cell setTitle:_T(@"Remember Last URL") ];
                            rememberURL = [ [ UISwitchControl alloc ]
                                initWithFrame:CGRectMake(205.0f, 9.0f, 120.0f, 30.0f) ];
                            [ rememberURL setValue: [trApp getRememberURL] ? 1 : 0 ];
                            [ rememberURL addTarget:self action:@selector(handleSwitch:) forEvents:kUIControlEventMouseUpInside ];
                            [[ cell titleTextLabel] sizeToFit];
                            [ cell addSubview: rememberURL ];
                            break;
                    }
                    break;
                case (2):
                    switch (row) {
                        case (0):
                            [ cell setTitle: TEXTREADER_HOMEPAGE ];
                            break;
                        case (1):
                            [ cell setTitle: _T(@"email: iphonetextreader@gmail.com") ];
                            break;
                    }
                    break;
            }
            break;
        default:
        case My_Prefs_View:
            switch (group) {
                case (0):
                    [ cell setTitle:_T(@"Text Settings") ];
                    [ cell setShowDisclosure:YES];
                    [ cell setDisclosureStyle: 3 ];
                    textSettings = cell;
                    break;
                case (1):
                    [ cell setTitle:_T(@"Display Settings") ];
                    [ cell setShowDisclosure:YES];
                    [ cell setDisclosureStyle: 3 ];
                    displaySettings = cell;
                    break;
                case (2):
                    [ cell setTitle:_T(@"Scroll Settings") ];
                    [ cell setShowDisclosure:YES];
                    [ cell setDisclosureStyle: 3 ];
                    colorsCell = cell;
                    break;
                case (3):
                    [ cell setTitle:_T(@"Other Settings") ];
                    [ cell setShowDisclosure:YES];
                    [ cell setDisclosureStyle: 3 ];
                    otherSettings = cell;
                    break;
                case (4):
                    switch (row) {
                        case (0):
                            [ cell setTitle: TEXTREADER_HOMEPAGE ];
                            break;
                        case (1):
                            [ cell setTitle: _T(@"email: iphonetextreader@gmail.com") ];
                            break;
                    }
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
    else if (segment == fileScroll)
    {
        [trApp setFileScroll:seg];
    }

} // selectedSegmentChanged


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

            switch ([trApp getCurrentView])
            {
                case My_Text_Prefs_View:

                    [textView setFontZoom:[fontZoom value] ? 1 : 0];
                    [textView setCacheAll:[cacheAll value] ? 1 : 0];
                    [trApp setDeleteCacheDir:[deleteCacheDir value] ? 1 : 0];

                    [trApp showView:My_Prefs_View];
                    break;
                case My_Display_Prefs_View:

                    [textView setInvertColors:[invertScreen value] ? true : false];
                    [trApp setShowCoverArt:[showCoverArt value] ? 1 : 0];
                    [textView setPadMargins:[padMargins value] ? 1 : 0];

                    [trApp showView:My_Prefs_View];
                    break;
                case My_Scroll_Prefs_View:

                    [trApp setReverseTap:[reverseTap value] ? 1 : 0];
                    [textView setRepeatLine:[repeatLine value] ? 1 : 0];
                    [trApp setSwipeOK:[swipeOK value] ? 1 : 0];

                    [trApp showView:My_Prefs_View];
                    break;
                case My_Other_Prefs_View:

                    [trApp setSearchWrap:[searchWrap value] ? 1 : 0];
                    [trApp setSearchWord:[searchWord value] ? 1 : 0];
                    [trApp setRememberURL:[rememberURL value] ? 1 : 0];

                    [trApp showView:My_Prefs_View];
                    break;
                default:
                case My_Prefs_View:
                    [trApp showView:My_Info_View];
                    break;
            }

    } // switch

} // navigationBar



// Save the encodings
-(void)saveEncodings {

    NSStringEncoding encodings[4] =
            {
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
                int family;
                NSArray * familyNames = [UIFont familyNames];
                for (family = 0; family < [familyNames count]; family++)
                {
                    [dataArray addObjectsFromArray:[UIFont fontNamesForFamilyName:[familyNames objectAtIndex:family]]];

                    // int name;
                    // NSArray * fontNames = [UIFont fontNamesForFamilyName:[familyNames objectAtIndex:family]];
                    // for (name = 0; name < [fontNames count]; name++)
                    //     [dataArray addObject:[fontNames  objectAtIndex:name]];

                }





//                 // Based on code in Books.app
//                 NSString * fontFolderPath = @"/System/Library/Fonts/";
//                 NSArray * fontsFolderContents = [[NSFileManager defaultManager] directoryContentsAtPath:fontFolderPath];
//                 NSEnumerator * enumerator = [fontsFolderContents objectEnumerator];
//                 NSString * font;
//
//                 // These don't look very good, so weed them out up front ...
//                 NSArray *badFonts = [NSArray arrayWithObjects:
//                         @"AppleGothicRegular.ttf",
//                         @"DB_LCD_Temp-Black.ttf",
//                         @"HelveticaNeue.ttf",
//                         @"HelveticaNeueBold.ttf",
//                         @"PhonepadTwo.ttf",
//                         @"LockClock.ttf",
//                         // @"arialuni.ttf",
//                         @"Zapfino.ttf",
//                         nil];
//
//                 for (font = [enumerator nextObject]; font; font = [enumerator nextObject])
//                 {
//                     if ( [[font pathExtension] isEqualToString:@"ttf"]
//                          && ![badFonts containsObject:font] )
//                         [dataArray addObject:[font stringByDeletingPathExtension]];
//
//                 } // for each font
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

                // // Add a list of available encodings to the data array
                // const NSStringEncoding *enc = [NSString availableStringEncodings];

                // while (enc && *enc)
                //    [dataArray addObject:[NSString localizedNameOfStringEncoding:*(enc++)]];

                int i;
                for (i = 0; i < trEncodingsL; i++)
                    [dataArray addObject:trEncodings[i].name];

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
