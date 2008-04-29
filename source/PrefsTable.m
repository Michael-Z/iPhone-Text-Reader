


#import "PrefsTable.h"
#import "textReader.h"
#import "MyTextView.h"


// **********************************************************************
// Class for Preferences Page
@implementation MyPreferencesTable

- (id)initWithFrame:(CGRect)rect {
	pickerView = nil;
	
    self = [ super initWithFrame: rect ];
    if (nil != self) {
        int i, j;

        for(i=0;i<NUM_GROUPS;i++) {
            groupcell[i] = NULL;
            for(j=0;j<CELLS_PER_GROUP;j++)
                cells[i][j] = NULL;
        }

        [ self setDataSource: self ];
        [ self setDelegate: self ];
    }

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
            return 2; 

        case(1):
        	// Invert
        	// Ignore Single LF
        	// Pad Margins
            return 3;
            
        case(2):
        	// Web Site
        	// Email address
            return 2;
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
             [ groupcell[group] setTitle: @"Font Settings" ];
             break;
         case (1):
             [ groupcell[group] setTitle: @"Display Settings" ];
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
        if (group < 2)
            return 40; // JIMB BUG BUG
    }

    return proposed;
}


- (BOOL)preferencesTable:(UIPreferencesTable *)aTable
    isLabelGroup:(int)group
{
    if (group == 2)
        return YES;
        
    return NO;
}


- (void)tableRowSelected:(NSNotification *)notification 
{
	int           i    = [self selectedRow];
	struct CGRect rect = [trApp getOrientedViewRect];
	
	switch (i)
	{
		case 1: // font
			{	
				if (pickerView)
					[pickerView release];
				pickerView = [[MyPickerView alloc] initWithFrame:rect];
				[pickerView setDelegate: self];
				[pickerView setType:kPicker_Type_Font];
				[pickerView setPrefs:self];

				[self addSubview:pickerView];		
			}				
			break;

		case 2: // font Size
			{	
				if (pickerView)
					[pickerView release];
				pickerView = [[MyPickerView alloc] initWithFrame:rect];
				[pickerView setDelegate: self];
				[pickerView setType:kPicker_Type_FontSize];
				[pickerView setPrefs:self];

				[self addSubview:pickerView];		
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



// Create the cells for the prefs table
- (UIPreferencesTableCell *)preferencesTable:(UIPreferencesTable *)aTable
    cellForRow:(int)row
    inGroup:(int)group
{
    UIPreferencesTableCell *cell;
	
    if (cells[group][row] != NULL)
        return cells[group][row];

    cell = [ [ UIPreferencesTableCell alloc ] init ];
    [ cell setEnabled: YES ];

    switch (group) {
        case (0):
            switch (row) {
                case (0):
                    [ cell release ];
                    cell = [ [ UIPreferencesTableCell alloc ] init ];
                    [ cell setTitle:@"Font" ];
                    [ cell setValue:[textView getFont] ];
					[ cell setShowDisclosure:YES];
					fontCell = cell;
                    break;
                case (1):
                    [ cell release ];
                    cell = [ [ UIPreferencesTableCell alloc ] init ];
                    [ cell setTitle:@"Font Size" ];
                    [ cell setValue:[NSString stringWithFormat:@"%d", [textView getFontSize]] ];
					[ cell setShowDisclosure:YES];
					fontSizeCell = cell;
                    break;
           }
           break;
        case (1):
            switch (row) {
                case (0):
                    [ cell setTitle:@"Invert Screen" ];
                    invertScreen = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(200.0f, 9.0f, 120.0f, 30.0f) ];
                    [ invertScreen setValue: [textView getColor] ];
                    [ cell addSubview: invertScreen ];
                    break;
                case (1):
                    [ cell setTitle:@"Ignore Single LF" ];
                    ignoreNewLine = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(200.0f, 9.0f, 120.0f, 30.0f) ];
                    [ ignoreNewLine setValue: [textView getIgnoreNewLine] ? 1 : 0 ];
                    [ cell setEnabled: YES ];
                    [ cell addSubview: ignoreNewLine ];
                    break;
                case (2):
                    [ cell setTitle:@"Pad Margins" ];
                    padMargins = [ [ UISwitchControl alloc ]
                        initWithFrame:CGRectMake(200.0f, 9.0f, 120.0f, 30.0f) ];
                    [ padMargins setValue: [textView getPadMargins] ? 1 : 0 ];
                    [ cell setEnabled: YES ];
                    [ cell addSubview: padMargins ];
                    break;
            }
            break;
        case (2):
            switch (row) {
                case (0):
		            [ cell setTitle: @"http://code.google.com/p/iphonetextreader" ];
		            break;
                case (1):
		            [ cell setTitle: @"email: iphonetextreader@gmail.com" ];
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
				[trApp lockUIOrientation];
				NSString *Msg = [NSString stringWithFormat:
				                          @"version %@\nwritten by Jim Beesley\n\niphonetextreader@gmail.com\n\nhttp://code.google.com\t\t/p/iphonetextreader",
				                          TEXTREADER_VERSION];
				struct CGRect rect = [trApp getOrientedViewRect];
				UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
				NSString *aboutMsg = [NSString stringWithFormat:@"About %@", TEXTREADER_NAME];
				[alertSheet setTitle:aboutMsg];
				[alertSheet setBodyText:Msg];
				[alertSheet addButtonWithTitle:@"OK"];
				[alertSheet setDelegate:self];
				[alertSheet popupAlertAnimated:YES];
			}
			break;

		case 1: // Done
		
			// If picker is active, just kill it
			if (pickerView)
			{
				[pickerView release];
				pickerView = nil;
			}				
			
			// Apply preferences ...
			[textView setColor:[invertScreen value]];
			[textView setIgnoreNewLine:[ignoreNewLine value]];
			[textView setPadMargins:[padMargins value]];
			
			if ([[fontCell value] length] > 4)
				[textView setFont:[fontCell value]];
			
			int fontSize = [[fontSizeCell value] intValue];
			if (fontSize >= 8 && fontSize <= 34)
				[textView setFontSize:fontSize];
			
			[trApp showView:My_Info_View];
			break;
	} // switch
	
} // navigationBar


// This view's alert sheets are just informational ...
// Dismiss them without doing anything special
- (void)alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button 
{
  [trApp unlockUIOrientation];
  [sheet dismissAnimated:YES];
  [sheet release];
} // alertSheet


- (void) setFont:(NSString*)font {
	[ fontCell setValue:font ];
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
					@"arialuni.ttf",
					@"Zapfino.ttf", nil];

				for (font = [enumerator nextObject]; font; font = [enumerator nextObject])
				{
					if ([[font pathExtension] isEqualToString:@"ttf"] &&
					    ![badFonts containsObject:font])
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
	}
	
} // setType


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
