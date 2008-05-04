#import "FileTable.h"

@interface UIDeletableCell : UIImageAndTextTableCell
{
    FileTable *table;
}

- (void)setTable:(FileTable *)_table;

@end

