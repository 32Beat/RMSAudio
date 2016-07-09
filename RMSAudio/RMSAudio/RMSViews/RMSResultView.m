////////////////////////////////////////////////////////////////////////////////
/*
	RMSResultView.m
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSResultView.h"
#import "RMSIndexView.h"


@interface RMSResultView ()
{
	// Represented data
	rmslevels_t mLevels;
	
	RMSIndexView *mIndexView;
}
@end

////////////////////////////////////////////////////////////////////////////////
@implementation RMSResultView
////////////////////////////////////////////////////////////////////////////////

- (void) setLevels:(rmslevels_t)levels
{	
	dispatch_async(dispatch_get_main_queue(),
	^{
		mLevels = levels;
		[self setNeedsDisplayInRect:self.bounds];
	});
}

////////////////////////////////////////////////////////////////////////////////

- (NSRect) frameForIndexView
{
	NSRect frame = self.bounds;
	frame.size.height *= 5.0/25.0;
	return frame;
}

////////////////////////////////////////////////////////////////////////////////

- (RMSIndexView *) indexView
{
	if (mIndexView == nil)
	{
		// Compute top half of frame
		NSRect frame = [self frameForIndexView];
		
		// Create levels view with default drawing direction
		mIndexView = [[RMSIndexView alloc] initWithFrame:frame];
		mIndexView.direction = self.direction;
		
		// Add as subview
		[self addSubview:mIndexView];
	}
	
	return mIndexView;
}

////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Drawing
////////////////////////////////////////////////////////////////////////////////

#define HSBCLR(h, s, b) \
[NSColor colorWithHue:h/360.0 saturation:s brightness:b alpha:1.0]

- (NSColor *) bckColor
{
	if (_bckColor == nil)
	{ _bckColor = HSBCLR(0.0, 0.0, 0.5); }
	return _bckColor;
}

- (NSColor *) avgColor
{
	if (_avgColor == nil)
	{ _avgColor = HSBCLR(120.0, 0.6, 0.9); }
	return _avgColor;
}

- (NSColor *) maxColor
{
	if (_maxColor == nil)
	{ _maxColor = HSBCLR(120.0, 0.5, 1.0); }
	return _maxColor;
}

- (NSColor *) hldColor
{
	if (_hldColor == nil)
	{ _hldColor = HSBCLR(0.0, 0.0, 0.25); }
	return _hldColor;
}

- (NSColor *) clpColor
{
	if (_clpColor == nil)
	{ _clpColor = HSBCLR(0.0, 1.0, 1.0); }
	return _clpColor;
}

////////////////////////////////////////////////////////////////////////////////
#if !TARGET_OS_IPHONE
- (BOOL) isOpaque
{ return !(self.bckColor.alphaComponent < 1.0); }
#else
- (BOOL) isFlipped
{ return YES; }
#endif

- (void)drawRect:(NSRect)rect
{
	// If direction == auto, adjust according to rectangle
	if (self.direction == 0)
	{
		self.direction = self.bounds.size.width > self.bounds.size.height ?
		eRMSViewDirectionE : eRMSViewDirectionN;
	}
	
	// uneven direction is horizontal
	if (self.direction & 0x01)
	{
		// Reverse direction if necessary
		if (self.direction & 0x02)
		{
			CGContextRef context = NSGraphicsGetCurrentContext();
			CGContextTranslateCTM(context, self.bounds.size.width, 0.0);
			CGContextScaleCTM(context, -1.0, 1.0);
		}
		
		[self drawHorizontal];
	}
	else
	{
		if ((self.direction == eRMSViewDirectionS)==self.isFlipped)
		{
			CGContextRef context = NSGraphicsGetCurrentContext();
			CGContextTranslateCTM(context, 0.0, self.bounds.size.height);
			CGContextScaleCTM(context, 1.0, -1.0);
		}

		[self drawVertical];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawHorizontal
{
	// Source = mLevels
	rmslevels_t levels = mLevels;
	// Destination = frame
	NSRect frame = self.bounds;
	
	// scale values to width
	double W = frame.size.width;
	
	// Average
	[[self avgColor] set];
	frame.size.width = round(W * RMS2DISPLAY(levels.mAvg));
	NSRectFill(frame);

	[[self maxColor] set];
	frame.origin.x += frame.size.width;
	frame.size.width = round(W * RMS2DISPLAY(levels.mMax));
	frame.size.width -= frame.origin.x;
	NSRectFill(frame);
/*
	if (levels.mHld < 1.0)
	[[self hldColor] set];
	else
	[[self clpColor] set];
	
	frame.origin.x += frame.size.width;
	frame.size.width = round(W * RMS2DISPLAY(levels.mHld));
	frame.size.width -= frame.origin.x;
	NSRectFill(frame);
*/
	[[self bckColor] set];
	frame.origin.x += frame.size.width;
	frame.size.width = W;
	frame.size.width -= frame.origin.x;
	NSRectFill(frame);
	
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawVertical
{
	// Source = mLevels
	rmslevels_t levels = mLevels;
	// Destination = frame
	NSRect frame = self.bounds;
	
	// scale values to height
	double S = frame.size.height;
	
	// Average
	[[self avgColor] set];
	frame.size.height = round(S * RMS2DISPLAY(levels.mAvg));
	NSRectFill(frame);

	[[self maxColor] set];
	frame.origin.y += frame.size.height;
	frame.size.height = round(S * RMS2DISPLAY(levels.mMax));
	frame.size.height -= frame.origin.y;
	NSRectFill(frame);
/*
	if (levels.mHld < 1.0)
	[[self hldColor] set];
	else
	[[self clpColor] set];
	
	frame.origin.y += frame.size.height;
	frame.size.height = round(S * RMS2DISPLAY(levels.mHld));
	frame.size.height -= frame.origin.y;
	NSRectFill(frame);
*/
	[[self bckColor] set];
	frame.origin.y += frame.size.height;
	frame.size.height = S;
	frame.size.height -= frame.origin.y;
	NSRectFill(frame);
	
}

////////////////////////////////////////////////////////////////////////////////

- (NSRect) boundsWithRatio:(double)ratio
{
	NSRect bounds = self.bounds;

	// Adjust for display scale
	ratio = RMS2DISPLAY(ratio);
	
	if (_direction == 0)
	{ _direction = (bounds.size.width > bounds.size.height) ? 1 : 4; }
	
	if (_direction & 0x01)
	{
		bounds.size.width *= ratio;
		if (_direction & 0x02)
		bounds.origin.x += self.bounds.size.width - bounds.size.width;
	}
	else
	{
		bounds.size.height *= ratio;
		if (_direction & 0x02)
		bounds.origin.y += self.bounds.size.height - bounds.size.height;
	}
	
	return bounds;
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////






