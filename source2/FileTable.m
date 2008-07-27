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


#import "textReader.h"
#import "FileTable.h"
#import "UIDeletableCell.h"




@implementation FileTable


// MAke a copy of the current path ...
- (void) setPath:(NSString*)_path {

    NSFileManager *fileManager = [ NSFileManager defaultManager ];

    // Normalize the path ...
    if (_path)
    {
        _path = [_path stringByStandardizingPath];
        _path = [_path stringByResolvingSymlinksInPath];
    }

    // Make sure the path exists
    if (!_path || [_path length] < 1 || [fileManager fileExistsAtPath:_path] == NO) {
        _path = TEXTREADER_DEF_PATH;
        [[NSFileManager defaultManager] createDirectoryAtPath:_path attributes:nil];
    }

    // Clean up existing path storage
    if (path)
        [path release];

    // Save a copy of the current path ...
    path = [_path copy];

} // setPath



- (id)initWithFrame2:(struct CGRect)rect trApp:(textReader*)tr path:(NSString*)_path owner:(UIView*)owner {

    self = [ super initWithFrame:rect ];

    if (self)
    {
        trApp = tr;

        colFilename = [ [ UITableColumn alloc ]
                            initWithTitle: _T(@"Filename")
                            identifier:@"filename"
                            width:rect.size.width];

        [ self addTableColumn:colFilename ];

        [ self setSeparatorStyle:1 ];
        [ self setDelegate:self ];
        [ self setDataSource:self ];
        [ self setRowHeight:64 ];

        fileList = [ [ NSMutableArray alloc] init ];

        [self setPath:_path];

        // Create the navbar for this file table
        struct CGRect FSrect = [trApp getOrientedViewRect];

        FSrect.origin.y     += [UIHardware statusBarHeight];
        FSrect.size.height   = [UINavigationBar defaultSizeWithPrompt].height;

        navBar = [[UINavigationBar alloc] initWithFrame:FSrect];
        [navBar setBarStyle: 0];
        // [navBar showButtonsWithLeft:_T(@"..Up..") right:_T(@"Cancel") leftBack:YES];

        // Get the parent directory ..
        NSString * up = nil;

        // Can we actually go up?!?!
        if ([path length] > 1)
            up = [[path stringByDeletingLastPathComponent] lastPathComponent];

        [navBar showButtonsWithLeft:up
                              right:_T(@"Cancel")
                           leftBack:YES];

        [navBar pushNavigationItem:[[UINavigationItem alloc] initWithTitle: _T(@"Open Text File")]];
        [navBar setAutoresizingMask:kTopBarResizeMask];

        [navBar setDelegate:self];
        [owner  addSubview:navBar];

        [owner addSubview:self];

    }

    return self;

} // initWithFrame


- (NSString *)getPath {
    return path;
} // getPath


- (void) reloadData {

    NSArray * contents;

    NSString * openFile = [trApp getFileName];
    NSString * openPath = [trApp getFilePath];
    int highlight = -1;
    int i;

    // Clean out the old entries
    [ fileList removeAllObjects ];

    // Update the path in the nav Bar (shorten path if possible)
    [navBar setPrompt:[path stringByAbbreviatingWithTildeInPath]];

    // Add download option to list
    [fileList addObject:TEXTREADER_DOWNLOAD_TITLE];

    // Add parent directory option (unless we are at '/')
    if ([path length] > 1)
        [fileList addObject:TEXTREADER_PARENT_DIR];


    // Add directories
    contents = [[NSFileManager defaultManager] directoryContentsAtPath:path];
    for (i = 0; i < [contents count]; i++)
    {
        NSString * dir = [contents  objectAtIndex:i];
        NSString * fullpath = [path stringByAppendingPathComponent:dir];
        BOOL isDir = true;

        // Don't add cache directories here - add them in their proper spot ...
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullpath isDirectory:&isDir] && isDir &&
            [trApp getFileType:fullpath] != kTextFileTypeTRCache) {
            [fileList addObject:dir];
        }
    }

    // Add visible files
    [fileList addObjectsFromArray:[trApp getVisibleFiles:path]];


    // Quick check to find the file that matches the currently open file ...
    // If the paths are not the same, highlight the Download rather than looking for
    // a file match in thw wrong directory
    if (openPath && [path compare:openPath]==NSOrderedSame)
    {
        for (i = 0; i < [fileList count]; i++)
        {
            // Is this the currently open book?
            if ([openFile isEqualToString:[fileList objectAtIndex:i]])
            {
                highlight = i;
                break;
            }
        }
    }

    [ super reloadData ];

    // Highlight the currently open book
    if (highlight > 0)
    {
        [self scrollRowToVisible:highlight];
        [self highlightRow:highlight];
    }
    else
    {
        [self scrollRowToVisible:0];
        [self highlightRow:0];
    }

} // reloadData


- (int)numberOfRowsInTable:(UITable *)_table {
    return [ fileList count ];
} // numberOfRowsInTable


typedef enum _RowType {
    RowType_Unknown  = 0,
    RowType_TXT      = 1,
    RowType_PDB      = 2,
    RowType_HTML     = 3,
    RowType_FB2      = 4,
    RowType_RTF      = 5,
    RowType_CHM      = 6,
    RowType_ZIP      = 7,
    RowType_RAR      = 8,
    RowType_TRCache  = 9,
    RowType_Download = 10,
    RowType_Parent   = 11,
    RowType_Folder   = 12
} RowType;


// Set the image for this row ...
- (void) setRowImage:(int)row cell:(UIDeletableCell *)cell type:(RowType)rowType {

    NSString * iname      = nil;
    bool       isCoverArt = false;

    // Set default images
    switch (rowType)
    {
        case RowType_TXT:
        case RowType_PDB:
        case RowType_HTML:
        case RowType_FB2:
        case RowType_RTF:
        case RowType_CHM:
        case RowType_ZIP:
        case RowType_RAR:
        case RowType_TRCache:
        case RowType_Unknown:
            // These will be taken care of below
            break;

        case RowType_Download:
            iname = @"globedownload.png";
            break;
        case RowType_Parent:
            iname = @"folderup.png";
            break;
        case RowType_Folder:
            iname = @"folder.png";
            break;
    }

    // Load cover image if requested and available
    if (!iname)
    {
        iname = [trApp getCoverArt:[fileList objectAtIndex:row] path:path];
        if (iname)
            isCoverArt = true;
    }

    // Pick out the icon for this file type ...
    if (!iname)
    {
        switch (rowType)
        {
            case RowType_TXT:
                iname = @"txt.png";
                break;
            case RowType_PDB:
                iname = @"pdb.png";
                break;
            case RowType_CHM:
                iname = @"chm.png";
                break;
            case RowType_ZIP:
                iname = @"zip.png";
                break;
            case RowType_RAR:
                iname = @"rar.png";
                break;
            case RowType_HTML:
                iname = @"html.png";
                break;
            case RowType_FB2:
                iname = @"fb2.png";
                break;
            case RowType_RTF:
                iname = @"rtf.png";
                break;
            case RowType_TRCache:
                iname = @"cache.png";
                break;

            case RowType_Unknown:
            case RowType_Download:
            case RowType_Parent:
            case RowType_Folder:
                // These were taken care of above
                break;
        }
    }

    // Try to load the image
    if (iname)
    {
        UIImage *image = nil;

        if (isCoverArt)
            image = [UIImage imageAtPath:iname];
        else
            image = [UIImage applicationImageNamed:iname];

        [cell setImage: image];

        // Scale the image if needed
        if (isCoverArt)
            [trApp scaleImage:[cell iconImageView] maxheight:63 maxwidth:63 yOffset:0];
    }

} // setRowImage


- (void) setFileCell:(UIDeletableCell *)cell row:(int)row {

    NSString * file = [fileList objectAtIndex:row];

    [cell setTitle:[file stringByDeletingPathExtension]];
    [cell setShowDisclosure:YES];

    // We set a "fat" disclosure if the file has not been opened
    // (i.e. not the current one, and we don't have a position saved)
    if ([trApp getDefaultStart:file] < 1)
    {
        NSString * openFile = [trApp getFileName];

        if (!openFile || [openFile compare:file])
           [ cell setDisclosureStyle: 3 ];
    }

} // setFileCell


// Populate the table's rows ...
- (UITableCell *)table:(UITable *)table
  cellForRow:(int)row
  column:(UITableColumn *)col
{
    RowType     rowType = RowType_Unknown;

    if (col == colFilename) {
        BOOL isDir = true;

        UIDeletableCell *cell = [ [ UIDeletableCell alloc ] init ];
        [ cell setTable: self ];
        [ cell setTextReader: trApp ];

        // Set the icon for this row
        if (row == 0)
        {
            rowType = RowType_Download;
            [ cell setTitle: [ fileList objectAtIndex: row ] ];
        }

        else if ([[fileList objectAtIndex:row] length] < 1) // ignore blank entries
        {
            // do nothing
        }

        else if ([[fileList objectAtIndex:row] compare:TEXTREADER_PARENT_DIR]==NSOrderedSame) // handle parent/up ...
        {
            rowType = RowType_Parent;
            [ cell setTitle: [ fileList objectAtIndex: row ] ];
        }

        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeTRCache)
        {
            rowType = RowType_TRCache;
            [self setFileCell:cell row:row];
        }

        else if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:[fileList objectAtIndex:row]] isDirectory:&isDir] && isDir)
        {
            rowType = RowType_Folder;
            [ cell setTitle: [fileList objectAtIndex:row] ];
        }

        else
        {
            // Handle the other types ...
            switch ([trApp getFileType:[fileList objectAtIndex:row]])
            {
                case kTextFileTypeTXT:
                    rowType = RowType_TXT;
                    [self setFileCell:cell row:row];
                    break;
                case kTextFileTypePDB:
                    rowType = RowType_PDB;
                    [self setFileCell:cell row:row];
                    break;
                case kTextFileTypeCHM:
                    rowType = RowType_CHM;
                    [self setFileCell:cell row:row];
                    break;
                case kTextFileTypeZIP:
                    rowType = RowType_ZIP;
                    [self setFileCell:cell row:row];
                    break;
                case kTextFileTypeRAR:
                    rowType = RowType_RAR;
                    [self setFileCell:cell row:row];
                    break;
                case kTextFileTypeHTML:
                    rowType = RowType_HTML;
                    [self setFileCell:cell row:row];
                    break;
                case kTextFileTypeFB2:
                    rowType = RowType_FB2;
                    [self setFileCell:cell row:row];
                    break;
                case kTextFileTypeRTF:
                    rowType = RowType_RTF;
                    [self setFileCell:cell row:row];
                    break;

                default:
                    break;
            }
        }

        // Specify the proper image for this row
        [self setRowImage:row cell:cell type:rowType];

        return [ cell autorelease ];
    }

} // table



- (int)swipe:(int)type withEvent:(struct __GSEvent *)event;
{
    struct CGRect FSrect = [trApp getOrientedViewRect];

    CGPoint point= GSEventGetLocationInWindow(event);
    CGPoint offset = _startOffset;

    point = [trApp getOrientedPoint:point];

    point.y -= [UIHardware statusBarHeight] + [UINavigationBar defaultSizeWithPrompt].height;
    point.y += offset.y;

    int row = [self rowAtPoint:point];

    BOOL isDir = true;

    // We display the delete notification:
    //  If the starting point of the swipe is on the right 1/3 of the screen ...
    //  If this is NOT ".." up directory *and*
    //  If this file exists *and*
    //  If this is a cache file *or* not a directory
    //  (caches of CHM and ZIP files are actual directories)
    // Remember, we *can* delete directories if they are a trCache!
    if (point.x > FSrect.origin.x + FSrect.size.width * 2 / 3 &&
        row != 0 && // Download
        [[fileList objectAtIndex:row] compare:TEXTREADER_PARENT_DIR] != NSOrderedSame && // folderup
        [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:[fileList objectAtIndex:row]] isDirectory:&isDir] &&
        ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeTRCache || !isDir))
    {
        UIDeletableCell *cell = [self visibleCellForRow:row column:0];

        [ cell
           _showDeleteOrInsertion: YES
           withDisclosure: YES
           animated: YES
           isDelete: YES
           andRemoveConfirmation: YES
        ];
    }

    return [ super swipe:type withEvent:event ];

} // swipe


// ------------------------------
// Begin RAR Wrapper
// ------------------------------
// Called from the thread wrapper for extracting a RAR file ...
- (void) extractRAR {

    NSString *fileName = [ fileList objectAtIndex: [ self selectedRow ] ];
    NSString * infile  = [path stringByAppendingPathComponent:fileName];
    NSString * outdir  = [infile stringByAppendingPathExtension:TEXTREADER_CACHE_EXT];
    BOOL       isDir   = true;

    // Build the unrar command ...
    NSString * unrar = [NSString stringWithFormat:@"/Applications/textReader.app/unrar x -y \"%@\" \"%@/\"",
                                 infile, outdir];

    // Execute the unrar command ...
    system([unrar UTF8String]);

    // If the dir exists, hop into it, otherwise assume disaster ...
    if (![[NSFileManager defaultManager] fileExistsAtPath:outdir isDirectory:&isDir] || !isDir)
    {
        NSString *errorMsg = [NSString stringWithFormat:_T(@"Unable to unrar file %@"), infile];
        [trApp showDialog:_T(@"Error Caching RAR File")
                      msg:errorMsg
                  buttons:DialogButtons_OK];
    }
    else
    {
        // Drop into the new directory ...
        [trApp showFileTable:outdir];
    }

    // Dismiss the wait spinner
    [trApp hideWait];
    [self setEnabled:YES];

} // extractRAR


// We use the thread so we can pop the wait spinner, but then
// we need to do the actual work on the main thread so we
// don't mess up the Table ... sheesh ...
- (void) thrdExtractRAR:(id)ignored
{
    [self performSelectorOnMainThread:@selector(extractRAR)
                            withObject:nil waitUntilDone:YES];
} // thrdExtractRAR
// ------------------------------
// End RAR Wrapper
// ------------------------------



// ------------------------------
// Begin ZIP Wrapper
// ------------------------------
// Called from the thread wrapper for extracting a ZIP file ...
- (void) extractZIP {

    NSString *fileName = [ fileList objectAtIndex: [ self selectedRow ] ];
    NSString * infile  = [path stringByAppendingPathComponent:fileName];
    NSString * outdir  = [infile stringByAppendingPathExtension:TEXTREADER_CACHE_EXT];
    BOOL       isDir   = true;

    // Build the unzip command ...
    NSString * unzip = [NSString stringWithFormat:@"/usr/bin/unzip -o \"%@\" -d \"%@\"",
                                 infile, outdir];

    // Execute the unzip command ...
    system([unzip UTF8String]);

    // If the dir exists, hop into it, otherwise assume disaster ...
    if (![[NSFileManager defaultManager] fileExistsAtPath:outdir isDirectory:&isDir] || !isDir)
    {
        NSString *errorMsg = [NSString stringWithFormat:_T(@"Unable to unzip file %@"), infile];
        [trApp showDialog:_T(@"Error Caching ZIP File")
                      msg:errorMsg
                  buttons:DialogButtons_OK];
    }
    else
    {
        // Drop into the new directory ...
        [trApp showFileTable:outdir];
    }

    // Dismiss the wait spinner
    [trApp hideWait];
    [self setEnabled:YES];

} // extractZIP


// We use the thread so we can pop the wait spinner, but then
// we need to do the actual work on the main thread so we
// don't mess up the Table ... sheesh ...
- (void) thrdExtractZIP:(id)ignored
{
    [self performSelectorOnMainThread:@selector(extractZIP)
                            withObject:nil waitUntilDone:YES];
} // thrdExtractZIP
// ------------------------------
// End ZIP Wrapper
// ------------------------------




// ------------------------------
// Begin CHM Wrapper
// ------------------------------
// Called from the thread wrapper for extracting a CHM file ...
- (void) extractCHM {

    NSString *fileName = [ fileList objectAtIndex: [ self selectedRow ] ];
    NSString * infile  = [path stringByAppendingPathComponent:fileName];
    NSString * outdir  = [infile stringByAppendingPathExtension:TEXTREADER_CACHE_EXT];
    BOOL       isDir   = true;

    if (extract_chm((char*)[infile UTF8String], (char*)[outdir UTF8String]) ||
        ![[NSFileManager defaultManager] fileExistsAtPath:outdir isDirectory:&isDir] || !isDir)
    {
        NSString *errorMsg = [NSString stringWithFormat:_T(@"Unable to explode CHM file %@"), infile];
        [trApp showDialog:_T(@"Error Caching CHM File")
                      msg:errorMsg
                  buttons:DialogButtons_OK];
    }
    else
    {
        // Drop into the new directory ...
        [trApp showFileTable:outdir];
    }

    // Dismiss the wait spinner
    [trApp hideWait];
    [self setEnabled:YES];

} // extractCHM


// We use the thread so we can pop the wait spinner, but then
// we need to do the actual work on the main thread so we
// don't mess up the Table ... sheesh ...
- (void) thrdExtractCHM:(id)ignored
{
    [self performSelectorOnMainThread:@selector(extractCHM)
                            withObject:nil waitUntilDone:YES];
} // thrdExtractCHM
// ------------------------------
// End CHM Wrapper
// ------------------------------


// Handle navBar buttons ...
- (void) navigationBar:(UINavigationBar*)navBar buttonClicked:(int) button
{

    switch (button) {
        case 0: // Cancel
            [trApp showView:My_Info_View];
            break;

        case 1: // "..Up.."
            {
                NSString * newPath = [[path stringByAppendingPathComponent:@".."] stringByStandardizingPath];

                // If user said to delete cache dir and we are leaving a cache dir, delete it
                if ([trApp getDeleteCacheDir] && [trApp getFileType:path] == kTextFileTypeTRCache)
                    [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];

                [trApp showFileTable:newPath];
            }
            break;

    } // switch

} // navigationBar



- (void)tableRowSelected:(NSNotification *)notification {

    NSString *fileName = [ fileList objectAtIndex: [ self selectedRow ] ];
    BOOL isDir = true;

    // Handle download ...
    if ([fileName isEqualToString:TEXTREADER_DOWNLOAD_TITLE])
    {
        [trApp showView:My_Download_View];
    }
    else if ([fileName length] < 1)
    {
        // Do nothing ... ignore blank entries ...
    }
    else if ([fileName compare:TEXTREADER_PARENT_DIR] == NSOrderedSame) // folderup
    {
        // Select the "..up.." button
        [self navigationBar:nil buttonClicked:1];
    }
    else if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:fileName] isDirectory:&isDir] &&
              isDir) // directory
    {
        NSString * newPath = [[path stringByAppendingPathComponent:fileName] stringByStandardizingPath];

        [trApp showFileTable:newPath];
    }
    else if ([trApp getFileType:fileName] == kTextFileTypeCHM)
    {
        // Disable input to the view and show spinner while we extract
        [trApp showWait];

        // Start the thread to
        [NSThread detachNewThreadSelector:@selector(thrdExtractCHM:)
                                 toTarget:self
                               withObject:nil];
    }
    else if ([trApp getFileType:fileName] == kTextFileTypeZIP)
    {
        // Disable input to the view and show spinner while we extract
        [trApp showWait];

        // Start the thread to
        [NSThread detachNewThreadSelector:@selector(thrdExtractZIP:)
                                 toTarget:self
                               withObject:nil];
    }
    else if ([trApp getFileType:fileName] == kTextFileTypeRAR)
    {
        // Disable input to the view and show spinner while we extract
        [trApp showWait];

        // Start the thread to
        [NSThread detachNewThreadSelector:@selector(thrdExtractRAR:)
                                 toTarget:self
                               withObject:nil];
    }
    else // Must be a text or pdb file ...
    {
        // Open the selected file ...
        [trApp openFile:fileName path:path];
        [trApp showView:My_Text_View];
    }

} // tableRowSelected


- (void)dealloc {
    [ path release ];
    [ colFilename release ];
    [ fileList release ];
    [ super dealloc ];
} // dealloc


- (void) setTextReader:(textReader*)tr {
    trApp = tr;
} // setTextReader


- (textReader*) getTextReader {
    return trApp;
} // setTextReader


- (NSMutableArray *) getFileList {
    return fileList;
} // getFileList


- (void) resize {
    struct CGRect FSrect = [trApp getOrientedViewRect];

    FSrect.origin.y    += [UIHardware statusBarHeight] + [UINavigationBar defaultSizeWithPrompt].height;
    FSrect.size.height -= [UIHardware statusBarHeight] + [UINavigationBar defaultSizeWithPrompt].height;
    [self setFrame:FSrect];
    [self _updateVisibleCellsImmediatelyIfNecessary];

} // resize




- (void)table:(UITable *) table deleteRow:(int) row
{
} // deleteRow





@end

