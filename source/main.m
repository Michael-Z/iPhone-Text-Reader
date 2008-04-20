#import "textReader.h"

int main(int argc, char **argv)
{
	int rVal = 0;

	NSAutoreleasePool *pool	= [[NSAutoreleasePool alloc] init];

	rVal = UIApplicationMain(argc, argv, [textReader class]);

	[pool release];

	return rVal;
}
