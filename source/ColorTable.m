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
//   * Allen Li for help with rotation lock and swipe/gestrues
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



#import "ColorTable.h"
#import "textReader.h"
#import "MyTextView.h"

static const int kUIControlEventMouseUpInside = 1 << 6;

// **********************************************************************
// Class for Preferences Page
@implementation MyColorTable

- (id)initWithFrame:(CGRect)rect {
    
    self = [ super initWithFrame: rect ];
    if (nil != self) {
    
        memset(groupcell, sizeof(groupcell), 0x00);
        memset(cells,     sizeof(groupcell), 0x00);
        
        [ self setDataSource: self ];
        [ self setDelegate: self ];
    }
    
    text_red = nil;
    text_green = nil;
    text_blue = nil;
//     text_alpha = nil;
    bkg_red = nil;
    bkg_green = nil;
    bkg_blue = nil;
//     bkg_alpha = nil;
    
    exampleCell = nil;
    
    return self;
} // initWithFrame


- (int)numberOfGroupsInPreferencesTable:(UIPreferencesTable *)aTable {

    /* Number of logical groups, including labels */
    return NUM_COLOR_GROUPS;
} // numberOfGroupsInPreferencesTable


- (int)preferencesTable:(UIPreferencesTable *)aTable
    numberOfRowsInGroup:(int)group
{
    switch (group) {
        case(1):
            // Example
            return 1; 

        case(0):
            // Text red, green, blue, // removed - alpha
            return 3;
            
        case(2):
            // Background red, green, blue, // removed - alpha
            return 3;
        
        case(3):
            // Web Site
            // Email address
            return 2;
    }
    return 0;
} // preferencesTable


- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable
    cellForGroup:(int)group
{
     if (groupcell[group] != NULL)
         return groupcell[group];

     groupcell[group] = [ [ UIPreferencesTableCell alloc ] init ];
     switch (group) {
         case (1):
             [ groupcell[group] setTitle: _T(@"Example Text") ];
             break;
         case (0):
             [ groupcell[group] setTitle: _T(@"Text Color") ];
             break;
         case (2):
             [ groupcell[group] setTitle: _T(@"Background Color") ];
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
        if (group < 3)
            return 40;
    }

    return proposed;
}


- (BOOL)preferencesTable:(UIPreferencesTable *)aTable
    isLabelGroup:(int)group
{
    if (group == 3)
        return YES;
        
    return NO;
}


- (void)tableRowSelected:(NSNotification *)notification 
{
    int           i    = [self selectedRow];

    [[self cellAtRow:i column:0] setSelected:NO];
    
} // tableRowSelected


- (void) setExampleTextColor {
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    [exampleCell setTitle:_T(@"This is how the text will look ...")];
    
    [[exampleCell titleTextLabel] sizeToFit];
    [[exampleCell valueTextLabel] sizeToFit];
    
    [[exampleCell titleTextLabel] setColor:CGColorCreate(colorSpace, &txtcolors.text_red)];
    [[exampleCell titleTextLabel] setBackgroundColor:CGColorCreate(colorSpace, &txtcolors.bkg_red)];
    
    [[exampleCell valueTextLabel] setColor:CGColorCreate(colorSpace, &txtcolors.text_red)];
    [[exampleCell valueTextLabel] setBackgroundColor:CGColorCreate(colorSpace, &txtcolors.bkg_red)];

    [[exampleCell titleTextLabel] setNeedsDisplay];

} // setExampleTextColor


// We get this message when the slider changes value
- (void) handleSlider:(id)sliderid
{
    float val = [(UISliderControl*)sliderid value];
    
    if (sliderid == text_red)
        txtcolors.text_red = val;
    else if (sliderid == text_green)
        txtcolors.text_green = val;
    else if (sliderid == text_blue)
        txtcolors.text_blue = val;
//     else if (sliderid == text_alpha)
//         txtcolors.text_alpha = val;
        
    else if (sliderid == bkg_red)
        txtcolors.bkg_red = val;
    else if (sliderid == bkg_green)
        txtcolors.bkg_green = val;
    else if (sliderid == bkg_blue)
        txtcolors.bkg_blue = val;
//     else if (sliderid == bkg_alpha)
//         txtcolors.bkg_alpha = val;
    else
        return;
        
    [self setExampleTextColor];

} // handleSwitch


- (UISliderControl*) addSliderToCell:(NSString*)title  forCell:(UIPreferencesTableCell*)cell init:(float)val 
{
    UISliderControl * slider;
    
    [ cell setTitle:title ];
    slider = [ [ UISliderControl alloc ]
        // initWithFrame:CGRectMake(85.0f, 9.0f, 215.0f, 30.0f) ];
        initWithFrame:CGRectMake(95.0f, 9.0f, 205.0f, 30.0f) ];
    [slider setMinValue:0.];
    [slider setMaxValue:1.];
    [slider setShowValue:YES];
    [slider addTarget:self action:@selector(handleSlider:) forEvents:7]; // 7=drag
    [slider addTarget:self action:@selector(handleSlider:) forEvents:2]; // 2=up
    [slider setValue:val];   
    [cell addSubview:slider];
} // addSliderToCell


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
        case (1):
            switch (row) {
                case (0):
                    exampleCell = cell;
                    [self setExampleTextColor];
                    break;
           }
           break;
        case (0):
            switch (row) {
                case (0):
                    text_red = [self addSliderToCell:_T(@"Red") forCell:cell init:txtcolors.text_red];
                    break;
                case (1):
                    text_green = [self addSliderToCell:_T(@"Green") forCell:cell init:txtcolors.text_green];
                    break;
                case (2):
                    text_blue = [self addSliderToCell:_T(@"Blue") forCell:cell init:txtcolors.text_blue];
                    break;
//                 case (3):
//                     text_alpha = [self addSliderToCell:_T(@"Alpha") forCell:cell init:txtcolors.text_alpha];
//                     break;
            }
            break;
        case (2):
            switch (row) {
                case (0):
                    bkg_red = [self addSliderToCell:_T(@"Red") forCell:cell init:txtcolors.bkg_red];
                    break;
                case (1):
                    bkg_green = [self addSliderToCell:_T(@"Green") forCell:cell init:txtcolors.bkg_green];
                    break;
                case (2):
                    bkg_blue = [self addSliderToCell:_T(@"Blue") forCell:cell init:txtcolors.bkg_blue];
                    break;
//                 case (3):
//                     bkg_alpha = [self addSliderToCell:_T(@"Alpha") forCell:cell init:txtcolors.bkg_alpha];
//                     break;
            }
            break;
        case (3):
            switch (row) {
                case (0):
                    [ cell setTitle: _T(@"http://code.google.com/p/iphonetextreader") ];
                    break;
                case (1):
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

    // Get the colors ...    
    txtcolors = [textView getTextColors];

} // setTextView


- (void) resize {
    struct CGRect FSrect = [trApp getOrientedViewRect];

    FSrect.origin.y    += [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
    FSrect.size.height -= [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
    [self setFrame:FSrect];
    [self _updateVisibleCellsImmediatelyIfNecessary];
    
    [self setNeedsDisplay];
    
} // resize


- (void)navigationBar:(UINavigationBar*)navbar buttonClicked:(int)button 
{
    switch (button) {
        case 0: // Cancel
            [trApp showView:My_Prefs_View];
            break;

        case 1: // Done
            // Apply New Colors !!!!!
            [textView setTextColors:&txtcolors];
            
            // Return to settings
            [trApp showView:My_Prefs_View];
            break;
            
    } // switch
    
} // navigationBar


- (void)dealloc {
  [super dealloc];
} // dealloc


@end



