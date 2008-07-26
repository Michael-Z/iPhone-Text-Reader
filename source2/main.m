#import "textReader.h"


int main(int argc, char **argv)
{
    NSAutoreleasePool *autoreleasePool = [ 
        [ NSAutoreleasePool alloc ] init
    ];
    UIApplicationUseLegacyEvents(1);
    int returnCode = UIApplicationMain(argc, argv, @"textReader", @"textReader");
    [ autoreleasePool release ];
    return returnCode;
}
