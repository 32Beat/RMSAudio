////////////////////////////////////////////////////////////////////////////////
/*
	RMSResultView.h
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAudio.h"

// TODO: move to RMSViews.h ?
#if !TARGET_OS_DESKTOP
#define NSView 		UIView
#define NSColor 	UIColor
#define NSRect 		CGRect
#define NSRectFill 	UIRectFill
#endif

////////////////////////////////////////////////////////////////////////////////

#import "rmslevels.h"

enum RMSViewDirection
{
	eRMSViewDirectionAuto = 0,
	eRMSViewDirectionE = 1,
	eRMSViewDirectionS = 2,
	eRMSViewDirectionW = 3,
	eRMSViewDirectionN = 4
};

@interface RMSResultView : NSView

@property (nonatomic) CGFloat holdTime;

@property (nonatomic) NSColor *bckColor;
@property (nonatomic) NSColor *avgColor;
@property (nonatomic) NSColor *maxColor;
@property (nonatomic) NSColor *hldColor;
@property (nonatomic) NSColor *clpColor;

@property (nonatomic, assign) NSUInteger direction;

- (void) setLevels:(rmsresult_t)result;

@end




