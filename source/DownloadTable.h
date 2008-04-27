

#import <UIKit/UIKit.h>
#import <UIKit/UIPreferencesTable.h>
#import <UIKit/UIPreferencesTextTableCell.h>
#import <UIKit/UISwitchControl.h>
#import <UIKit/UISegmentedControl.h>
#import <UIKit/UISliderControl.h>
#import <UIKit/UIPickerView.h>
#import <UIKit/UIPickerTable.h>
#import <UIKit/UIPickerTableCell.h>



// These are the MAX values - preferencesTable controls the actual number
#define NUM_DOWN_GROUPS 3
#define CELLS_PER_DOWN_GROUP 2


@class textReader;



// **********************************************************************
// Class for Download Page
@interface MyDownloadTable : UIPreferencesTable
{
    UIPreferencesTableCell *cells[NUM_DOWN_GROUPS][CELLS_PER_DOWN_GROUP];
    UIPreferencesTableCell *groupcell[NUM_DOWN_GROUPS];

	UIPreferencesTableCell *urlCell;
	UIPreferencesTableCell *saveAsCell;
	UIPreferencesTableCell *downloadCell;


	NSString     * urlAddress;
	NSString     * toFileName;
	NSURL        * theURL;
	NSString     * fullPath;
	UIAlertSheet * wait;



    textReader		   *trApp;

} // MyPreferencesTable


- (id)initWithFrame:(CGRect)rect;
- (int)numberOfGroupsInPreferencesTable:(UIPreferencesTable *)aTable;
- (UIPreferencesTableCell *)preferencesTable: (UIPreferencesTable *)aTable
    cellForGroup:(int)group;
- (float)preferencesTable:(UIPreferencesTable *)aTable
    heightForRow:(int)row inGroup:(int)group withProposedHeight:(float)proposed;
- (BOOL)preferencesTable:(UIPreferencesTable *)aTable isLabelGroup:(int)group;
- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable
    cellForRow:(int)row inGroup:(int)group;

- (void) setTextReader:(textReader*)tr;
- (void) resize;

@end

