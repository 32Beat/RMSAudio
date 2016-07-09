////////////////////////////////////////////////////////////////////////////////
/*
	RMSIndexView.m
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSIndexView.h"

////////////////////////////////////////////////////////////////////////////////
@implementation RMSIndexView
////////////////////////////////////////////////////////////////////////////////

- (void)drawRect:(NSRect)rect
{
	// Reverse direction if necessary
	if (self.direction != 0)
	{
		CGContextRef context = NSGraphicsGetCurrentContext();
		CGContextTranslateCTM(context, self.bounds.size.width, 0.0);
		CGContextScaleCTM(context, -1.0, 1.0);
	}

/*
	// White backing
	[[NSColor whiteColor] set];
	NSRectFill(rect);
*/
	// Black indicators < 0dB
    [[NSColor blackColor] set];
	[self drawIndicators];
	
	// Red indicators >= 0dB
    [[NSColor redColor] set];
	[self drawClipIndicators];
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawIndicators
{
	static const CGFloat DB[] = { -96.0, -48.0, -24.0, -12.0, -6.0, -3.0 };

	NSRect frame = self.bounds;
	CGFloat w = frame.size.width;

	frame.size.width = 1.0;
	NSRectFill(frame); // -inf

	for (UInt32 n=0; n!=sizeof(DB)/sizeof(CGFloat); n++)
	{
		frame.origin.x = floor(w*DB2DISPLAY(DB[n]));
		NSRectFill(frame);
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawClipIndicators
{
	static const CGFloat DB[] = { 0.0, +3.0, +6.0 };

	NSRect frame = self.bounds;
	CGFloat w = frame.size.width;
	frame.size.width = 1.0;

	for (UInt32 n=0; n!=sizeof(DB)/sizeof(CGFloat); n++)
	{
		frame.origin.x = floor(w*DB2DISPLAY(DB[n]));
		NSRectFill(frame);
	}
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////
