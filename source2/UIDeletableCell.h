#import "FileTable.h"

@interface UIDeletableCell : UIImageAndTextTableCell
{
    FileTable  *table;
    textReader *trApp;
}

- (void)setTable:(FileTable *)_table;
- (void)setTextReader:(textReader *)trapp;

@end

