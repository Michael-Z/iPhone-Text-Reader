

#import <UIKit/UIKit.h>
#import <UIKit/UISimpleTableCell.h>
#import <UIKit/UIImageAndTextTableCell.h>
#import <UIKit/UITableColumn.h>
#import <UIKit/UIImage.h>
#import <GraphicsServices/GraphicsServices.h>

@class textReader;

@interface FileTable : UITable
{
    NSString *path;
    NSString *extension;
    NSMutableArray *fileList;
    UITableColumn *colFilename;

    textReader *trApp;
    UINavigationBar * navBar;
}
- (id)initWithFrame:(struct CGRect)rect;
- (void)setPath:(NSString *)_path;
- (NSString *)getPath;
- (void)reloadData;
- (int)swipe:(int)type withEvent:(struct __GSEvent *)event;
- (int)numberOfRowsInTable:(UITable *)_table;
- (UITableCell *)table:(UITable *)table cellForRow:(int)row column:(UITableColumn *)col;
- (void)_willDeleteRow:(int)row forTableCell:(id)cell viaEdge:(int)edge animateOthers:(BOOL)animate;
- (void)dealloc;

- (void) resize;
- (textReader*) getTextReader;
- (NSMutableArray *) getFileList;

- (void) setTextReader:(textReader*)tr;
- (void) setNavBar:(UINavigationBar*)bar;
@end

