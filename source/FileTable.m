

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

    return self;
} // initWithFrame


- (void) setPath:(NSString *)_path {
    path = [ _path copy ];
} // setPath


- (void) setExtension:(NSString *)_extension {
    extension = [ _extension copy ];
} // setExtension


- (void) reloadData {
    NSFileManager *fileManager = [ NSFileManager defaultManager ];
    NSDirectoryEnumerator *dirEnum; 
    NSString *file;
    
    NSString * openFile = [trApp getFileName];
    int highlight = -1;

    if ([ fileManager fileExistsAtPath: path ] == NO) {
        return;
    } 

    [ fileList removeAllObjects ];
 
    dirEnum = [ [ NSFileManager defaultManager ] enumeratorAtPath: path ];
    while ((file = [ dirEnum nextObject ])) {
        if ([ file hasSuffix: extension ] == YES) {
            [ fileList addObject: file ];
            
            // Is this the currently open book?
            if (openFile && (highlight < 0) && [openFile isEqualToString:file])
            	highlight = [fileList count];
        }
    }    

    [ super reloadData ];
    
    // Highlight the currently open book
    if (highlight > 0)
    {
		[self scrollRowToVisible:highlight-1];
		[self highlightRow:highlight-1];
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
        UIDeletableCell *cell = [ [ UIDeletableCell alloc ] init ];
        [ cell setTable: self ];

        UIImageView *image = [ [ UIImage alloc ] 
              initWithContentsOfFile: [ [ NSString alloc ] 
              initWithFormat: @"/Applications/%@/icon.png", 
                              [ fileList  objectAtIndex: row ] ] ];
        [ cell setTitle: [ [ fileList objectAtIndex: row ]
        stringByDeletingPathExtension ]];
        [ cell setImage: image ];
		[ cell setShowDisclosure: YES ];
		[ cell setDisclosureStyle: 3 ];
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
	
	UIDeletableCell *cell = [self visibleCellForRow:row column:0];

	[ cell
	   _showDeleteOrInsertion: YES
	   withDisclosure: YES
	   animated: YES
	   isDelete: YES
	   andRemoveConfirmation: YES
	];

	return [ super swipe:type withEvent:event ];
	
} // swipe


- (void)_willDeleteRow:(int)row 
    forTableCell:(id)cell
    viaEdge:(int)edge
    animateOthers:(BOOL)animate 
{
    [ fileList removeObjectAtIndex: row ];
    [ super _willDeleteRow: row forTableCell: cell viaEdge: edge animateOthers: animate ];
} // _willDeleteRow


- (void)tableRowSelected:(NSNotification *)notification {
    NSString *fileName = [ fileList objectAtIndex: [ self selectedRow ] ];

    // Open the selected file ...
    [trApp openFile:fileName start:[trApp getDefaultStart:fileName]];
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

