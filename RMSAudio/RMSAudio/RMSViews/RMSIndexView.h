////////////////////////////////////////////////////////////////////////////////
/*
	RMSIndexView.h
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#if !TARGET_OS_IOS

#import <Cocoa/Cocoa.h>

static inline CGContextRef NSGraphicsGetCurrentContext(void)
{ return (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort]; }

#else

#import <UIKit/UIKit.h>
#define NSView 		UIView
#define NSColor 	UIColor
#define NSRect 		CGRect
#define NSRectFill 	UIRectFill
#define NSGraphicsGetCurrentContext UIGraphicsGetCurrentContext

#endif

////////////////////////////////////////////////////////////////////////////////
/*
	
*/
static inline double DB2RMS(double x)
{ return pow(10, x/20.0); }

static inline double RMS2DISPLAY(double x)
{ return pow(x/(x+1.0), (1.0/3.0)); }

static inline double DB2DISPLAY(double x)
{ return RMS2DISPLAY(DB2RMS(x)); }

////////////////////////////////////////////////////////////////////////////////

@interface RMSIndexView : NSView
@property (nonatomic, assign) NSUInteger direction;
@end
