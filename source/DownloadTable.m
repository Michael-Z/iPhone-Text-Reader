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
             [ groupcell[group] setTitle: _T(@"Download Details") ];
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
    [wait setTitle:_T(@"Saving ...")];
    [wait setBodyText:[NSString stringWithFormat:_T(@"Saving to %@"), fullPath]];
} // threadShowSaving

- (void) threadReleaseWait {
    if (wait)
    {
        //[trApp unlockUIOrientation];
        [wait dismissAnimated:YES];
        [wait release];
        wait = nil;
    }
} // threadShowSaving

- (void) threadShowSaved {
    //[trApp lockUIOrientation];
    struct CGRect  rect     = [trApp getOrientedViewRect];
    UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
    [alertSheet setTitle:_T(@"Finished")];
    [alertSheet setBodyText:_T(@"Save complete!")];
    [alertSheet addButtonWithTitle:_T(@"OK")];
    [alertSheet setDelegate:trApp];
    [alertSheet popupAlertAnimated:YES];
    
    [trApp showView:My_File_View];
}

- (void) threadShowSaveErr {
    //[trApp lockUIOrientation];
    struct CGRect  rect     = [trApp getOrientedViewRect];
    UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
    [alertSheet setTitle:_T(@"Error Saving File")];
    [alertSheet setBodyText:[NSString stringWithFormat:
                              _T(@"Unable to save file as %@"),
                              fullPath]];
    [alertSheet addButtonWithTitle:_T(@"OK")];
    [alertSheet setDelegate:trApp];
    [alertSheet popupAlertAnimated:YES];
}

- (void) threadShowURLErr {
    //[trApp lockUIOrientation];
    struct CGRect  rect     = [trApp getOrientedViewRect];
    UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
    [alertSheet setTitle:_T(@"Error Loading From URL")];
    [alertSheet setBodyText:[NSString stringWithFormat:
                              _T(@"Unable to load file from URL %@"),
                              urlAddress]];
    [alertSheet addButtonWithTitle:_T(@"OK")];
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
        fullPath = [TEXTREADER_DEF_PATH stringByAppendingPathComponent:toFileName];                           
                        
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
                //[trApp lockUIOrientation];
                UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
                [alertSheet setTitle:_T(@"Error Invalid Save As File Name")];
                [alertSheet setBodyText:_T(@"The Save As file name can not contain slashes.")];
                [alertSheet addButtonWithTitle:_T(@"OK")];
                [alertSheet setDelegate:trApp];
                [alertSheet popupAlertAnimated:YES];
                return;
            }
            
            // Get the extensions (if any) on the name and on the 
            TextFileType urlType    = [trApp getFileType:urlAddress];
            TextFileType saveAsType = [trApp getFileType:toFileName];
            
            if (!urlType && !saveAsType)
            {
                //[trApp lockUIOrientation];
                UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
                [alertSheet setTitle:_T(@"Error Invalid Save As File Name")];
                [alertSheet setBodyText:_T(@"The URL or the Save As file name must have an extension of .pdb, .prc, .fb2, .htm, .html, .text, or .txt")];
                [alertSheet addButtonWithTitle:_T(@"OK")];
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
                toFileName = [[toFileName stringByAppendingPathExtension:[urlAddress pathExtension]] copy]; 
                saveAsType = urlType;
            }

            // Get the URL
            theURL =[[NSURL alloc] initWithString:urlAddress];
            if (!theURL)
            {
                //[trApp lockUIOrientation];
                UIAlertSheet * alertSheet = [[UIAlertSheet alloc] initWithFrame:rect];
                [alertSheet setTitle:_T(@"Error Invalid URL")];
                [alertSheet setBodyText:[NSString stringWithFormat:
                                          _T(@"Invalid URL %@"),
                                          urlAddress]];
                [alertSheet addButtonWithTitle:_T(@"OK")];
                [alertSheet setDelegate:trApp];
                [alertSheet popupAlertAnimated:YES];
                return;
            }
            
            // Show the loading message box         
            //[trApp lockUIOrientation];
            wait = [[UIAlertSheet alloc] initWithFrame:rect];
            [wait setTitle:_T(@"Downloading ...")];
            [wait setBodyText:[NSString stringWithFormat:
                                      _T(@"Downloading from URL %@"),
                                      urlAddress]];
            [wait setDelegate:trApp];
            //[wait addButtonWithTitle:_T(@"OK")];
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
                    [ cell setTitle:_T(@"Save As:") ];
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
                    [ cell setTitle:_T(@"Download File Now") ];
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
                    [ cell setTitle:[NSString stringWithFormat:@"%@ %@\n\n%@ %@ %@",
                                      _T(@"Enter the complete URL of the Text or PalmDoc file you want to download"),
                                      _T(@"and the Name you want it saved as locally."),
                                      _T(@"If you leave name blank"),
                                      TEXTREADER_NAME,
                                      _T(@"will try to figure out the name and extension based on the URL.") ]];
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
  //[trApp unlockUIOrientation];
  [sheet dismissAnimated:YES];
  [sheet release];
} // alertSheet


- (void)dealloc {
  [super dealloc];
} // dealloc


@end


