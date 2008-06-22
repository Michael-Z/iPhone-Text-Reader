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

- (id)initWithFrame:(struct CGRect)rect {
    self = [ super initWithFrame: rect ];
    if (nil != self) {


        colFilename = [ [ UITableColumn alloc ]
                            initWithTitle: _T(@"Filename")
                            identifier:@"filename"
                            width: rect.size.width];

        [ self addTableColumn: colFilename ];

        [ self setSeparatorStyle: 1 ];
        [ self setDelegate: self ];
        [ self setDataSource: self ];
        [ self setRowHeight: 64 ];
        
        fileList = [ [ NSMutableArray alloc] init ];
    }
    
    path = nil;

    return self;
} // initWithFrame

- (void) setNavBar:(UINavigationBar*)bar {
    navBar = bar;
}


- (void) setPath:(NSString *)_path {

    if (!_path || [_path length] < 1)
        _path = TEXTREADER_DEF_PATH;


    NSString * newPath = [_path copy];
    if (path)
        [path release];
        
    path = newPath;
} // setPath


- (NSString *)getPath {
    return path;
} // getPath


- (void) reloadData {
    NSFileManager *fileManager = [ NSFileManager defaultManager ];
    NSArray * contents;
    
    NSString * openFile = [trApp getFileName];
    NSString * openPath = [trApp getFilePath];
    int highlight = -1;
    int i;
    
    // Normalize the path ...
    [self setPath:[path stringByStandardizingPath]];
    [self setPath:[path stringByResolvingSymlinksInPath]];

    // Make sure the path exists
    if (!path || [fileManager fileExistsAtPath:path] == NO) {
        [self setPath:TEXTREADER_DEF_PATH];
        [[NSFileManager defaultManager] createDirectoryAtPath:path attributes:nil];    
    } 

    // If the paths are not the same, highlight the Download rather than looking for 
    // a file match in thw wrong directory
    if ([path compare:openPath]!=NSOrderedSame)
    {
        highlight = 0;
    }


    // Clean out the old entries
    [ fileList removeAllObjects ];

    // Update the path in the nav Bar (shorten path if possible)
    [navBar pushNavigationItem:[[UINavigationItem alloc] initWithTitle:[path stringByAbbreviatingWithTildeInPath]]];

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
        BOOL isDir = true;

        if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:dir] isDirectory:&isDir] && isDir) {
            [fileList addObject:dir];            
        }
    }

    // Add files
    contents = [[NSFileManager defaultManager] directoryContentsAtPath:path];
    for (i = 0; i < [contents count]; i++)
    {
        NSString * file = [contents  objectAtIndex:i];
        BOOL isDir = false;
        TextFileType ftype = [trApp getFileType:file];

        if (ftype &&
            [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:file] isDirectory:&isDir] && 
            !isDir) {
            
            // Show all text files
            // Only show FB2, PDB and HTML files that do not have a cached text version
            if (ftype == kTextFileTypeTXT || ftype == kTextFileTypeTRCache || 
                ![[NSFileManager defaultManager] fileExistsAtPath:[[path stringByAppendingPathComponent:file] stringByAppendingPathExtension:TEXTREADER_CACHE_EXT] isDirectory:&isDir])         
            {
                [fileList addObject:file];
            
                // Is this the currently open book?
                if (openFile && (highlight < 0) && [openFile isEqualToString:file])
                    highlight = [fileList count];
            }
        }
    }

    [ super reloadData ];
    
    // Highlight the currently open book
    if (highlight > 0)
    {
        [self scrollRowToVisible:highlight-1];
        [self highlightRow:highlight-1];
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
    RowType_TRCache  = 6,
    RowType_Download = 7,
    RowType_Parent   = 8,
    RowType_Folder   = 9 
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
        
        else if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:[fileList objectAtIndex:row]] isDirectory:&isDir] && isDir)
        {
            rowType = RowType_Folder;
            [ cell setTitle: [fileList objectAtIndex:row] ];
        }               
        
        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeTXT)
        {
            rowType = RowType_TXT;
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }
        
        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypePDB)
        {
            rowType = RowType_PDB;
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }

        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeHTML)
        {
            rowType = RowType_HTML;
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }
        
        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeFB2)
        {
            rowType = RowType_FB2;
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }
        
        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeRTF)
        {
            rowType = RowType_RTF;
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }
        
        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeTRCache)
        {
            rowType = RowType_TRCache;
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }
        
        // Specify the proper image for this row
        [self setRowImage:row cell:cell type:rowType];
        
        return [ cell autorelease ];
    } 
    
} // table


- (int)swipe:(int)type withEvent:(struct __GSEvent *)event;
{
    CGPoint point= GSEventGetLocationInWindow(event);
    CGPoint offset = _startOffset;

    point = [trApp getOrientedPoint:point];

    point.y -= [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
    point.y += offset.y;

    int row = [self rowAtPoint:point];
    
    BOOL isDir = true;
    
    if (row != 0 && // Download
        [[fileList objectAtIndex:row] compare:TEXTREADER_PARENT_DIR] != NSOrderedSame && // folderup
        [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:[fileList objectAtIndex:row]] isDirectory:&isDir] && 
        !isDir)// directory
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


- (void)_willDeleteRow:(int)row 
    forTableCell:(id)cell
    viaEdge:(int)edge
    animateOthers:(BOOL)animate 
{
    BOOL isDir = true;
    
    if (row != 0 && // Download
        [[fileList objectAtIndex:row] compare:TEXTREADER_PARENT_DIR] != NSOrderedSame && // folderup
        [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:[fileList objectAtIndex:row]] isDirectory:&isDir] && 
        !isDir)// directory
    {
        //[ fileList removeObjectAtIndex: row ]; // now done in delete cell
        [ super _willDeleteRow:row forTableCell:cell viaEdge:edge animateOthers:animate ];
        if (row >= [fileList count])
            [self reloadData];
    }
    
} // _willDeleteRow


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
    else if (([fileName compare:TEXTREADER_PARENT_DIR] == NSOrderedSame) || // folderup
             ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:fileName] isDirectory:&isDir] && 
              isDir)) // directory
    {
        // [self setPath:[path stringByAppendingPathComponent:fileName]];
        // [self reloadData];
        [trApp showFileTable:[path stringByAppendingPathComponent:fileName]];
    }
    else // Must be a text or pdb file ...
    {
        // Open the selected file ...
        [trApp openFile:fileName path:path];
        [trApp showView:My_Text_View];
    }
    
} // tableRowSelected


- (void)dealloc {
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

    FSrect.origin.y    += [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
    FSrect.size.height -= [UIHardware statusBarHeight] + [UINavigationBar defaultSize].height;
    [self setFrame:FSrect];
    [self _updateVisibleCellsImmediatelyIfNecessary];
    
} // resize



@end

