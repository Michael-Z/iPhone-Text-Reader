


#import "DownloadTable.h"
#import "textReader.h"


// **********************************************************************
// Class for Download Page
@implementation MyDownloadTable

- (id)initWithFrame:(CGRect)rect {
    self = [ super initWithFrame: rect ];
    if (nil != self) {
        int i, j;

        for(i=0;i<NUM_DOWN_GROUPS;i++) {
            groupcell[i] = NULL;
            for(j=0;j<CELLS_PER_DOWN_GROUP;j++)
                cells[i][j] = NULL;
        }

        [ self setDataSource: self ];
        [ self setDelegate: self ];
    }

    return self;
}


- (int)numberOfGroupsInPreferencesTable:(UIPreferencesTable *)aTable {

    /* Number of logical groups, including labels */
    return NUM_DOWN_GROUPS;
}


- (int)preferencesTable:(UIPreferencesTable *)aTable
    numberOfRowsInGroup:(int)group
{
    switch (group) {
        case(0):
            return 2; 

        case(1):
            return 1;
            
        case(2):
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
             [ groupcell[group] setTitle: @"Download Details" ];
             break;
     }
     return groupcell[group];
}


- (float)preferencesTable:(UIPreferencesTable *)aTable
    heightForRow:(int)row
    inGroup:(int)group
    withProposedHeight:(float)proposed
{
    if (row == -1 && group != 1)
     	return 30;

    return proposed;
}


- (BOOL)preferencesTable:(UIPreferencesTable *)aTable
    isLabelGroup:(int)group
{       
    return (group == 2) ? YES : NO;
}


// ---------------------------------------------
// Thread specific code ...
// ---------------------------------------------

// Quickie thread helper funcs
- (void) threadShowSaving {
	[wait setTitle:@"Saving ..."];
	[wait setBodyText:[NSString stringWithFormat:@"Saving to %@", fullPath]];
} // threadShowSaving

- (void) threadReleaseWait {
	if (wait)
	{
		[trApp unlockUIOrientation];
		[wait dismissAnimated:YES];
		[wait release];
		wait = nil;
	}
} // threadShowSaving

- (void) threadShowSaved {
	[trApp lockUIOrientation];
	struct CGRect  rect     = [trApp getOrientedViewRect];
	UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
	[alertSheet setTitle:@"Finished"];
	[alertSheet setBodyText:@"Save complete!"];
	[alertSheet addButtonWithTitle:@"OK"];
	[alertSheet setDelegate:trApp];
	[alertSheet popupAlertAnimated:YES];
	
	[trApp showView:My_File_View];
}

- (void) threadShowSaveErr {
	[trApp lockUIOrientation];
	struct CGRect  rect     = [trApp getOrientedViewRect];
	UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
	[alertSheet setTitle:@"Error Saving File"];
	[alertSheet setBodyText:[NSString stringWithFormat:
							  @"Unable to save file as %@",
							  fullPath]];
	[alertSheet addButtonWithTitle:@"OK"];
	[alertSheet setDelegate:trApp];
	[alertSheet popupAlertAnimated:YES];
}

- (void) threadShowURLErr {
	[trApp lockUIOrientation];
	struct CGRect  rect     = [trApp getOrientedViewRect];
	UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
	[alertSheet setTitle:@"Error Loading From URL"];
	[alertSheet setBodyText:[NSString stringWithFormat:
							  @"Unable to load file from URL %@",
							  urlAddress]];
	[alertSheet addButtonWithTitle:@"OK"];
	[alertSheet setDelegate:trApp];
	[alertSheet popupAlertAnimated:YES];
} // threadShowSaving


// Worker thread to do the actual download ...
- (void)downLoadFile:(id)ignored
{
	NSString  * file     = nil;
	bool        hadError = false; 


	// Load the file ...
	file = [NSString stringWithContentsOfURL:theURL];

	if (!file || [file length] < 1)
	{
		// Get rid of the wait msg
		[self performSelectorOnMainThread:@selector(threadReleaseWait) 
		                        withObject:nil waitUntilDone:YES];
		                        
		// Show error
		[self performSelectorOnMainThread:@selector(threadShowURLErr) 
		                        withObject:nil waitUntilDone:YES];
		hadError = true;
	}
	else
	{	
		// Figure out where to save the file
		fullPath = [NSString stringWithFormat:
							  @"%@%@",
							  TEXTREADER_DEF_PATH, toFileName];
						
		// Switch to showing the saving ... msg
		[self performSelectorOnMainThread:@selector(threadShowSaving) 
		                        withObject:nil waitUntilDone:YES];	

		// Write out the new file
		if (![file writeToFile:fullPath atomically:YES])
		{
			// Get rid of the wait msg
			[self performSelectorOnMainThread:@selector(threadReleaseWait) 
									withObject:nil waitUntilDone:YES];

			// Show error
			[self performSelectorOnMainThread:@selector(threadShowSaveErr) 
									withObject:nil waitUntilDone:YES];
			hadError = true;
		}
	}

	if (!hadError)
	{
		// Get rid of the wait msg
		[self performSelectorOnMainThread:@selector(threadReleaseWait) 
								withObject:nil waitUntilDone:YES];

		// Show success
		[self performSelectorOnMainThread:@selector(threadShowSaved) 
								withObject:nil waitUntilDone:YES];
	}
	
} //  downloadFile

// ---------------------------------------------
// End thread specific code
// ---------------------------------------------



- (void)tableRowSelected:(NSNotification *)notification 
{
	struct CGRect rect = [trApp getOrientedViewRect];
	
	switch ([self selectedRow])
	{
		case 4: // Do the download!!			
		
			// Get the address and name
			urlAddress = [urlCell value];
			toFileName = [saveAsCell value];
			
			// Validate address and name!!!
			
			// Name can not have embedded slashes
			if (toFileName && [toFileName rangeOfString:@"/"].location != NSNotFound)
			{
				[trApp lockUIOrientation];
				UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
				[alertSheet setTitle:@"Error Invalid Save As File Name"];
				[alertSheet setBodyText:@"The Save As file name can not contain slashes."];
				[alertSheet addButtonWithTitle:@"OK"];
				[alertSheet setDelegate:trApp];
				[alertSheet popupAlertAnimated:YES];
				return;
			}
			
			// Get the extensions (if any) on the name and on the 
			TextFileType urlType    = [trApp getFileType:urlAddress];
			TextFileType saveAsType = [trApp getFileType:toFileName];
			
			if (!urlType && !saveAsType)
			{
				[trApp lockUIOrientation];
				UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
				[alertSheet setTitle:@"Error Invalid Save As File Name"];
				[alertSheet setBodyText:@"The URL or the Save As file name must have an extension of .pdb, .text, or .txt"];
				[alertSheet addButtonWithTitle:@"OK"];
				[alertSheet setDelegate:trApp];
				[alertSheet popupAlertAnimated:YES];
				return;
			}
			
			// Try to get the last part of the URL if the save as name is blank
			if ([toFileName length] < 1)
			{
				toFileName = [[urlAddress lastPathComponent] copy];
			}

		    // Add URL extension to save as file name if needed
		    else if (!saveAsType)
		    {
		    	toFileName = [[toFileName stringByAppendingPathExtension: 
		    	                             (urlType == kTextFileTypeTXT) ? @".txt" : @".pdb"] copy];
		    	saveAsType = urlType;
		    }

			// Get the URL
			theURL =[[NSURL alloc] initWithString:urlAddress];
			if (!theURL)
			{
				[trApp lockUIOrientation];
				UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
				[alertSheet setTitle:@"Error Invalid URL"];
				[alertSheet setBodyText:[NSString stringWithFormat:
										  @"Invalid URL %@",
										  urlAddress]];
				[alertSheet addButtonWithTitle:@"OK"];
				[alertSheet setDelegate:trApp];
				[alertSheet popupAlertAnimated:YES];
				return;
			}
			
			// Show the loading message box			
			[trApp lockUIOrientation];
			wait = [[UIAlertSheet alloc] initWithFrame:rect];
			[wait setTitle:@"Downloading ..."];
			[wait setBodyText:[NSString stringWithFormat:
									  @"Downloading from URL %@",
									  urlAddress]];
			[wait setDelegate:trApp];
			//[wait addButtonWithTitle:@"OK"];
			[wait popupAlertAnimated:YES];

			// Start the load thread
  	  		[NSThread detachNewThreadSelector:@selector(downLoadFile:)
		 							 toTarget:self
								   withObject:nil];
			break;
			  		
	} // switch
	
	
} // tableRowSelected


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
                    cell = [ [ UIPreferencesTextTableCell alloc ] init ];
                    [ cell setTitle:@"URL:" ];
                    [ cell setValue:@"http://" ];
                    
//[ cell setValue:@"http://www.gutenberg.org/files/15772/15772-8.txt" ];
                    
					[ cell setShowDisclosure:YES];
					urlCell = cell;
					
					UITextField *tf = [(UIPreferencesTextTableCell*)cell textField];
					//[tf setPreferredKeyboardType:0];
					[tf setInitialSelectionBehavior:1];
					[tf setAutoCapsType:0];
					[tf setReturnKeyType:4];
					[tf setAutoEnablesReturnKey:NO];
					[cell addSubview:tf];    					
                    break;
                case (1):
                    [ cell release ];
                    cell = [ [ UIPreferencesTextTableCell alloc ] init ];
                    [ cell setTitle:@"Save As:" ];
                    [ cell setValue:@"" ];

//[ cell setValue:@"Aza test.txt" ];

					[ cell setShowDisclosure:YES];
					saveAsCell = cell;
                    break;
           }
           break;
           
        case (1):
            switch (row) {
                case (0):
                    [ cell release ];
                    cell = [ [ UIPreferencesTableCell alloc ] init ];
                    [ cell setTitle:@"Download File Now" ];
                    [ cell setValue:@"" ];
					[ cell setShowDisclosure:YES];
					downloadCell = cell;
                    break;
            }
            break;
            
        case (2):
            switch (row) {
                case (0):
		            [ cell setTitle: @"" ]; // A bit of blank space ...
		            break;
                case (1):
		            [ cell setTitle:[NSString stringWithFormat:@"%@%@%@%@%@",
									  @"Enter the complete URL of the Text or PalmDoc file you want to download ",
									  @"and the Name you want it saved as locally.\n\n",
									  @"If you leave name blank ",
		             			  	  TEXTREADER_NAME,
		             				  @" will try to figure out the name and extension based on the URL." ]];
		            break;
		    } // switch row
            break;
            
    } // switch group

    [ cell setShowSelection: NO ];
    cells[group][row] = cell;
    return cell;
}


- (void) setTextReader:(textReader*)tr {
	trApp = tr;
} // setTextReader


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
		case 0: // Not used
			break;

		case 1: // Done
			[trApp showView:My_File_View];
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


- (void)dealloc {
  [super dealloc];
} // dealloc


@end


