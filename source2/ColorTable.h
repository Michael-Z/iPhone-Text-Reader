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
#import <UIKit/UIPreferencesTable.h>
#import <UIKit/UIPreferencesTextTableCell.h>
#import <UIKit/UISwitchControl.h>
#import <UIKit/UISegmentedControl.h>
//#import <UIKit/UISlider.h>
#import <UIKit/UIPickerView.h>
#import <UIKit/UIPickerTable.h>
#import <UIKit/UIPickerTableCell.h>

#import "textReader.h"


// These are the MAX values - preferencesTable controls the actual number
#define NUM_COLOR_GROUPS      4
#define COLOR_CELLS_PER_GROUP 4



@class textReader;
@class MyTextView;



// **********************************************************************
// Class for Color Page
@interface MyColorTable : UIPreferencesTable
{
    UIPreferencesTableCell *cells[NUM_COLOR_GROUPS][COLOR_CELLS_PER_GROUP];
    UIPreferencesTableCell *groupcell[NUM_COLOR_GROUPS];

//    UISlider       *text_red;
//    UISlider       *text_green;
//    UISlider       *text_blue;
//     UISliderControl       *text_alpha;

//    UISlider       *bkg_red;
//    UISlider       *bkg_green;
//    UISlider       *bkg_blue;
//     UISliderControl       *bkg_alpha;

    UIPreferencesTableCell *exampleCell;

    MyColors               txtcolors;

    textReader            *trApp;
    MyTextView            *textView;

} // MyPreferencesTable


- (id)initWithFrame:(CGRect)rect;

- (int)numberOfGroupsInPreferencesTable:(UIPreferencesTable *)aTable;

- (UIPreferencesTableCell *)preferencesTable: (UIPreferencesTable *)aTable
                                cellForGroup:(int)group;

- (float)preferencesTable:(UIPreferencesTable *)aTable
             heightForRow:(int)row inGroup:(int)group
       withProposedHeight:(float)proposed;

- (BOOL)preferencesTable:(UIPreferencesTable *)aTable
            isLabelGroup:(int)group;

- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable
                                  cellForRow:(int)row
                                     inGroup:(int)group;

- (void) setTextReader:(textReader*)tr;
- (void) setTextView:(MyTextView*)tv;
- (void) resize;


@end

