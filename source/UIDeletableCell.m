#import "textReader.h"
#import "FileTable.h"
#import "UIDeletableCell.h"

@implementation UIDeletableCell

- (void)removeControlWillHideRemoveConfirmation:(id)fp8
{
    [ self _showDeleteOrInsertion:NO
          withDisclosure:YES
          animated:YES
          isDelete:YES
          andRemoveConfirmation:YES
    ];
}

- (void)_willBeDeleted
{
  NSString *fileName = nil;
  int row = [table _rowForTableCell:self];

  /* Do something; this row is being deleted */
  if (table && [table getFileList])
  	fileName = [[table getFileList] objectAtIndex:row];   
       
  if (fileName)
  {
	  NSString *path = [NSString stringWithFormat:@"%@%@", [table getPath], fileName];
	  
	  BOOL dir = false;
	  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&dir];

	  if(exists) 
	  {
		if(![[NSFileManager defaultManager] removeFileAtPath:path handler:nil]) 
		{
			NSString *errorMsg = [NSString stringWithFormat:
										   @"Unable to delete file \"%@\" in directory \"%@\".\nPlease make sure the directory and file exist and the write permissions for user \"mobile\" are set.", 
										   fileName, [table getPath]];
			CGRect rect = [[UIWindow keyWindow] bounds];
			UIAlertSheet * alertSheet = [[UIAlertSheet alloc] 
			                             initWithFrame:CGRectMake(0, rect.size.height-240, rect.size.width, 240)];
			[alertSheet setTitle:@"Error deleting file"];
			[alertSheet setBodyText:errorMsg];
			[alertSheet addButtonWithTitle:@"OK"];
			[alertSheet setDelegate:self];
			[alertSheet popupAlertAnimated:true];
		}
		else
			[[table getTextReader] removeDefaults:fileName];
	  }
   }   
} // _willBeDeleted


// Save the table pointer
- (void)setTable:(FileTable *)_table {
    table = _table;
} // setTable


// This view's alert sheets are just informational ...
// Dismiss them without doing anything special
- (void)alertSheet:(UIAlertSheet *)sheet buttonClicked:(int)button 
{
  [sheet dismissAnimated:YES];
  [sheet release];
} // alertSheet


@end
