#import "textReader.h"
#import "FileTable.h"
#import "UIDeletableCell.h"

@implementation UIDeletableCell

- (void)removeControlWillHideRemoveConfirmation:(id)fp8
{
    if ([[self title] length] > 0)
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
       
  if (fileName && [fileName length])
  {
      NSString *path = [[table getPath] stringByAppendingPathComponent:fileName];
      
      BOOL dir = false;
      BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&dir];

      if(exists) 
      {
        if(![[NSFileManager defaultManager] removeFileAtPath:path handler:nil]) 
        {
            NSString *errorMsg = [NSString stringWithFormat:
                                           //_T(@"Unable to delete file \"%@\" in directory \"%@\".\nPlease make sure both the directory and file exist and have write permissions set."), 
                                           //fileName, [table getPath]];
                                           @"%@ \"%@\" %@ \"%@\"%@\n%@",
                                           _T(@"Unable to delete file"), 
                                           fileName,
                                           _T(@"in directory"), 
                                           [table getPath],
                                           _T(@".dir_suffix"), // Just a "." in most languages ...
                                           _T(@"Please make sure both the directory and file exist and have write permissions set.")];
            CGRect rect = [[UIWindow keyWindow] bounds];
            UIAlertSheet * alertSheet = [[UIAlertSheet alloc] 
                                         initWithFrame:CGRectMake(0, rect.size.height-240, rect.size.width, 240)];
            [alertSheet setTitle:_T(@"Error deleting file")];
            [alertSheet setBodyText:errorMsg];
            [alertSheet addButtonWithTitle:_T(@"OK")];
            [alertSheet setDelegate:table];
            [alertSheet popupAlertAnimated:true];
        }
        else
        {
          [[table getTextReader] removeDefaults:fileName];
          
          // Kludge ... For some reason, removing the last entry from the fileList causes
          // an exception .. evrything else is OK
          //  [[table getFileList] removeObjectAtIndex: row];
          
          // Work around until I figure out what I'm doing wrong
          if (row < [[table getFileList] count]-1 &&
              [[[table getFileList] objectAtIndex:row+1] length] > 0)
            [[table getFileList] removeObjectAtIndex: row];
          else
          {
            [ self setImage:nil ];
            [ self setTitle:@"" ];          
            [ self setDisclosureStyle:0 ];
            [ self setShowDisclosure:NO ];
            [ self setEnabled:NO ];
            [[table getFileList] replaceObjectAtIndex:row withObject:@""];
          }
          
        } // if !deleted/else
        
      } // if exists
      
   } // if fileName
   
} // _willBeDeleted


// Save the table pointer
- (void)setTable:(FileTable *)_table {
    table = _table;
} // setTable


@end
