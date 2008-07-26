/*
    UIOrientingApplication -- iPhone / iPod Touch UIKit Class
    ©2008 James Yopp; LGPL License

    Application re-orients the display automatically to match the physical orientation of the hardware.
    Display can be locked / unlocked to prevent this behavior, and can be manually oriented with lockUIToOrientation.
*/


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIApplication.h>
#import <GraphicsServices/GraphicsServices.h>


#define resize_SpringLeft           0x01
#define resize_SpringWidth          0x02
#define resize_SpringRight          0x04
#define resize_SpringTop            0x08
#define resize_SpringHeight         0x10
#define resize_SpringBottom         0x20
#define kMainAreaResizeMask (resize_SpringWidth | resize_SpringHeight)
#define kTopBarResizeMask resize_SpringWidth
#define kBottomBarResizeMask (resize_SpringWidth | resize_SpringTop)


typedef enum _ShowStatus {
    ShowStatus_Off    = 0,
    ShowStatus_Light  = 1,
    ShowStatus_Dark   = 2,
} ShowStatus;


@interface UIOrientingApplication : UIApplication {
    CGRect FullKeyBounds;
    CGRect FullContentBounds;
    int orientations[7];
    int orientationDegrees;
    bool orientationLocked;
    float reorientationDuration;
    int orientation;
    unsigned int oCode;
    ShowStatus curStatus;
    bool initialized;
}

- (id) init;
- (void) setInitialized: (bool)b;
- (bool) isInitialized;

- (void) lockUIOrientation;
- (void) lockUIToOrientation: (unsigned int)o_code;
- (void) unlockUIOrientation;
- (void) setUIOrientation: (unsigned int)o_code;
- (void) setAngleForOrientation: (unsigned int)o_code toDegrees: (int)degrees;
- (int)  getOrientation;
- (unsigned int) getOrientCode;
- (void) showStatusBar:(ShowStatus)ss;
- (ShowStatus) getShowStatusBar;

- (void) deviceOrientationChanged: (GSEvent*)event;
- (CGRect) windowBounds;
- (CGRect) contentBounds;
- (bool) orientationLocked;

@end
