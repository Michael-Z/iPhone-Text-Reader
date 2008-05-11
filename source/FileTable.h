
//
//   textReader.app -  kludged up by Jim Beesley
//   This incorporates inspiration, code, and examples from (among others)
//	 * The iPhone Dev Team for toolchain and more!
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

