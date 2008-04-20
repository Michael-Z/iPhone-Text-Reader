#import "MyExample.h"

int main(int argc, char **argv)
{
    NSAutoreleasePool *autoreleasePool = [ [ NSAutoreleasePool alloc ] init ];
    int returnCode = UIApplicationMain(argc, argv, [ MyApp class ]);
    [ autoreleasePool release ];
    return returnCode;
}

@implementation MyApp

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    window = [ [ UIWindow alloc ] initWithContentRect:
        [ UIHardware fullScreenApplicationContentRect ]
    ];

    CGRect rect = [ UIHardware fullScreenApplicationContentRect ];
    rect.origin.x = rect.origin.y = 0.0f;

    mainView = [ [ MainView alloc ] initWithFrame: rect ];

    [ window setContentView: mainView ];
    [ window orderFront: self ];
    [ window makeKey: self ];
    [ window _setHidden: NO ];
}
@end

@implementation MainView
- (id)initWithFrame:(CGRect)rect {

    self = [ super initWithFrame: rect ];
    if (nil != self) {

        fileTable = [ [ FileTable alloc ] initWithFrame: rect ];
        [ fileTable setPath: @"/Applications" ];
        [ fileTable setExtension: @"app" ];
        [ fileTable reloadData ];
        [ self addSubview: fileTable ];
    }

    return self;
}

- (void)dealloc
{
    [ self dealloc ];
    [ super dealloc ];
}
@end
