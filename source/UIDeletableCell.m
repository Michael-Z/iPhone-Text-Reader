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
                                           @"%@ \"%@\" %@ \"%@\"%@\n%@",
                                           _T(@"Unable to delete file"), 
                                           fileName,
                                           _T(@"in directory"), 
                                           [table getPath],
                                           _T(@".dir_suffix"), // Just a "." in most languages ...
                                           _T(@"Please make sure both the directory and file exist and have write permissions set.")];
            [trApp showDialog:_T(@"Error deleting file")
                            msg:errorMsg
                         buttons:DialogButtons_OK];
        }
        else
        {
          // If we just deleted a cache file, ask if we should delete the original
          if ([trApp getFileType:fileName] == kTextFileTypeTRCache)
          {
              NSString * origfile = [fileName stringByDeletingPathExtension];
           
              path   = [[table getPath] stringByAppendingPathComponent:origfile];
              dir    = false;
              exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&dir];
           
              if (exists && !dir)
              {
                  // Save file name so we know what to delete 
                  [trApp rememberOpenFile:origfile path:[table getPath]];

                  // Display msg Cache File Deleted!\nDo you also want to delete the original file %@?
                  NSString *errorMsg = [NSString stringWithFormat:
                                                 @"%@\n%@ %@?",
                                                 _T(@"Cache File Deleted!"), 
                                                 _T(@"Do you also want to delete the original file"), 
                                                 origfile];                                         
                  [trApp showDialog:_T(@"Delete Cache File")
                                msg:errorMsg
                            buttons:DialogButtons_DeleteCache];
              }
          }
        
          // We removed a file, so remove it's saved current position
          [[table getTextReader] removeDefaults:fileName];
          
          // Is this the currently open file?  If so, we need to blank out the name
          // since it is no longer available to reload
          // JIMB BUG BUG - close the currently open eBook?!?!?
          if ([trApp getFileName] && [trApp getFilePath] &&
              ![fileName compare:[trApp getFileName]] &&
              ![[table getPath] compare:[trApp getFilePath]])
              [trApp  closeCurrentFile];
          
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
          
          // [table reloadData];
          
        } // if !deleted/else
        
      } // if exists
      
   } // if fileName
   
} // _willBeDeleted


// Save the table pointer
- (void)setTable:(FileTable *)_table {
    table = _table;
} // setTable

- (void)setTextReader:(textReader *)trapp {
    trApp = trapp;
} // setTextReader



@end
