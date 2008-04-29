

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
#define NUM_GROUPS 3
#define CELLS_PER_GROUP 3



@class textReader;
@class MyTextView;
@class MyPreferencesTable;


typedef enum _PickerType {
	kPicker_Type_None     = 0,
	kPicker_Type_Font     = 1,
	kPicker_Type_FontSize = 2
} PickerType;

// **********************************************************************
// Class for Picker
@interface MyPickerView: UIPickerView{

	MyPreferencesTable *prefsTable;

	NSMutableArray     *dataArray;

	PickerType			type;

} // MyPickerView

-(BOOL)table:(UIPickerTable*)table canSelectRow:(int)row;

-(void) setType:(PickerType)theType;
-(void) setPrefs:(MyPreferencesTable*)prefs;
-(NSMutableArray*) getDataArray;

@end



// **********************************************************************
// Class for Preferences Page
@interface MyPreferencesTable : UIPreferencesTable
{
    UIPreferencesTableCell *cells[NUM_GROUPS][CELLS_PER_GROUP];
    UIPreferencesTableCell *groupcell[NUM_GROUPS];

    UISwitchControl    *invertScreen;
    UISwitchControl    *ignoreNewLine;
    UISwitchControl    *padMargins;

    textReader		   *trApp;
    MyTextView		   *textView;

	MyPickerView	   *pickerView;

	UIPreferencesTableCell *fontCell;
	UIPreferencesTableCell *fontSizeCell;

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
- (void) setTextView:(MyTextView*)tv;
- (void) resize;

- (void) setFont:(NSString*)font;
- (void) setFontSize:(NSString*)fontSize;

@end

