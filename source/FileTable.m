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
                            initWithTitle: @"Filename"
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
            if (ftype == kTextFileTypeTXT || 
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


- (UITableCell *)table:(UITable *)table 
  cellForRow:(int)row 
  column:(UITableColumn *)col
{  
    if (col == colFilename) {
        BOOL isDir = true;
        
        UIDeletableCell *cell = [ [ UIDeletableCell alloc ] init ];
        [ cell setTable: self ];

        // Set the icon for this row
        if (row == 0) 
        {
            // Download path ...
            UIImageView *image = [ [ UIImage alloc ] 
                  initWithContentsOfFile: [ [ NSString alloc ] 
                  initWithFormat: @"/Applications/%@.app/globedownload.png", 
                                  TEXTREADER_NAME ] ];
            [ cell setImage: image ];
            [ cell setTitle: [ fileList objectAtIndex: row ] ];
        }
        
        else if ([[fileList objectAtIndex:row] length] < 1) // ignore blank entries
        {
            // do nothing
        }
        
        else if ([[fileList objectAtIndex:row] compare:TEXTREADER_PARENT_DIR]==NSOrderedSame) // handle parent/up ...
        {
            UIImageView *image = [ [ UIImage alloc ] 
                  initWithContentsOfFile: [ [ NSString alloc ] 
                  initWithFormat: @"/Applications/%@.app/folderup.png", 
                                  TEXTREADER_NAME ] ];
            [ cell setImage: image ];
            [ cell setTitle: [ fileList objectAtIndex: row ] ];
        }
        
        else if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:[fileList objectAtIndex:row]] isDirectory:&isDir] && isDir)
        {
            UIImageView *image = [ [ UIImage alloc ] 
                  initWithContentsOfFile: [ [ NSString alloc ] 
                  initWithFormat: @"/Applications/%@.app/folder.png", 
                                  TEXTREADER_NAME ] ];
            [ cell setImage: image ];
            [ cell setTitle: [fileList objectAtIndex:row] ];
        }               
        
        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeTXT)
        {
            UIImageView *image = [ [ UIImage alloc ] 
                  initWithContentsOfFile: [ [ NSString alloc ] 
                  initWithFormat: @"/Applications/%@.app/txt.png", 
                                  TEXTREADER_NAME ] ];
            [ cell setImage: image ];
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }
        
        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypePDB)
        {
            UIImageView *image = [ [ UIImage alloc ] 
                  initWithContentsOfFile: [ [ NSString alloc ] 
                  initWithFormat: @"/Applications/%@.app/pdb.png", 
                                  TEXTREADER_NAME ] ];
            [ cell setImage: image ];
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }

        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeHTML)
        {
            UIImageView *image = [ [ UIImage alloc ] 
                  initWithContentsOfFile: [ [ NSString alloc ] 
                  initWithFormat: @"/Applications/%@.app/html.png", 
                                  TEXTREADER_NAME ] ];
            [ cell setImage: image ];
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }
        
        else if ([trApp getFileType:[fileList objectAtIndex:row]] == kTextFileTypeFB2)
        {
            // JIMB BUG BUG - need fb2 icon!!!
            UIImageView *image = [ [ UIImage alloc ] 
                  initWithContentsOfFile: [ [ NSString alloc ] 
                  initWithFormat: @"/Applications/%@.app/html.png", 
                                  TEXTREADER_NAME ] ];
            [ cell setImage: image ];
            [ cell setTitle: [ [ fileList objectAtIndex: row ]
                               stringByDeletingPathExtension ]];
            [ cell setShowDisclosure: YES ];
            [ cell setDisclosureStyle: 3 ];
        }
        
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
        [self setPath:[path stringByAppendingPathComponent:fileName]];
        [self reloadData];
    }
    else // Must be a text or pdb file ...
    {
        // Open the selected file ...
        [trApp openFile:fileName path:path];
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


// This view's alert sheets are just informational ...
// Dismiss them without doing anything special
- (void)alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button 
{
  [sheet dismissAnimated:YES];
  [sheet release];
} // alertSheet

@end

