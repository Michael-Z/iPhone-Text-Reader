#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import "FileTable.h"

@interface MainView : UIView
{
        FileTable *fileTable;
}
- (id)initWithFrame:(CGRect)frame;
- (void)dealloc;
@end

@interface MyApp : UIApplication
{
    UIWindow *window;
    MainView *mainView;
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
@end
