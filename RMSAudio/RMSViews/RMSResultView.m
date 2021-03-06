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
	rmsresult_t mLevels;

	CGFloat mAvg;
	CGFloat mMax;
	CGFloat mHld;
	CGFloat mClp;
	
	CGFloat mMaxM;
	CGFloat mHldM;
	size_t mHldCount;
	
	
	RMSIndexView *mIndexView;
}
@end


#define kRMSDefaultResponseTime 	450
#define kRMSDefaultFrameRate 		24
#define kRMSDefaultDecayRate  		(0.001*kRMSDefaultResponseTime*kRMSDefaultFrameRate)
#define kRMSDefaultMultiplier 		(kRMSDefaultDecayRate/(kRMSDefaultDecayRate+1.0))

////////////////////////////////////////////////////////////////////////////////
@implementation RMSResultView
////////////////////////////////////////////////////////////////////////////////

- (void) setLevels:(rmsresult_t)levels
{
	mLevels = levels;
	
	mAvg = (levels.avg);
	[self updateMaxLevel];
	[self updateHoldLevel];
	
	[self setNeedsDisplayInRect:self.bounds];
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateMaxLevel
{
	// lazily initialize response multiplier
	if (mMaxM == 0.0)
	{ mMaxM = kRMSDefaultMultiplier; }
	
	// reduce view value
	mMax *= mMaxM;

	// check if view value dropped below latest model value
	if (mMax <= mLevels.max)
	{
		mMax = mLevels.max;
		if (mClp < mMax)
		{ mClp = mMax; }
	}
	
	if (mAvg > mMax)
	{ mAvg = mMax; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateHoldLevel
{
	if (mHldCount != 0)
	{
		mHldCount -= 1;
	}
	else
	{
		if (mHldM == 0.0)
		{ mHldM = kRMSDefaultMultiplier; }
		
		mHld *= mHldM;
	}

	if (mHld <= mLevels.max)
	{
		mHld = mLevels.max;
		
		if (self.holdTime == 0)
		{ self.holdTime = 1000.0; }
		
		mHldCount = 24 * (0.001 * self.holdTime);
	}
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
#pragma mark
////////////////////////////////////////////////////////////////////////////////

#if !TARGET_OS_IPHONE
- (BOOL) isOpaque
{ return !(self.bckColor.alphaComponent < 1.0); }
#else
- (BOOL) isFlipped
{ return YES; }
#endif

////////////////////////////////////////////////////////////////////////////////

- (void)drawRect:(NSRect)rect
{
#if !TARGET_OS_IPHONE
	[[self bckColor] set];
	NSRectFill(self.bounds);
#endif

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
	
	[[NSColor colorWithWhite:0.9 alpha:1.0] set];

#if TARGET_OS_IPHONE
	UIRectFrameUsingBlendMode(self.bounds, kCGBlendModeMultiply);
#else
	NSFrameRectWithWidthUsingOperation(self.bounds, 1.0, NSCompositeMultiply);
#endif
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawHorizontal
{
	// Destination = frame
	NSRect frame = self.bounds;
	
	// scale values to width
	double W = frame.size.width;
	
	// Average
	[[self avgColor] set];
	frame.size.width = round(W * RMS2DISPLAY(mAvg));
	NSRectFill(frame);

	[[self maxColor] set];
	frame.origin.x += frame.size.width;
	frame.size.width = round(W * RMS2DISPLAY(mMax));
	frame.size.width -= frame.origin.x;
	NSRectFill(frame);
	
	if (mHld <= 1.0)
	[[self hldColor] set];
	else
	[[self clpColor] set];
	
	frame.origin.x += frame.size.width;
	frame.size.width = round(W * RMS2DISPLAY(mHld));
	frame.size.width -= frame.origin.x;
	NSRectFill(frame);
	
	if (mClp <= 1.0)
	[[self hldColor] set];
	else
	[[self clpColor] set];
	
	frame = self.bounds;
	frame.origin.x += round(W * RMS2DISPLAY(mClp));
	frame.size.width = 1.0;
	NSRectFill(frame);
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawVertical
{
	// Destination = frame
	NSRect frame = self.bounds;
	
	// scale values to height
	double S = frame.size.height;
	
	// Average
	[[self avgColor] set];
	frame.size.height = round(S * RMS2DISPLAY(mAvg));
	NSRectFill(frame);

	[[self maxColor] set];
	frame.origin.y += frame.size.height;
	frame.size.height = round(S * RMS2DISPLAY(mMax));
	frame.size.height -= frame.origin.y;
	NSRectFill(frame);
	
	if (mHld <= 1.0)
	[[self hldColor] set];
	else
	[[self clpColor] set];
	
	frame.origin.y += frame.size.height;
	frame.size.height = round(S * RMS2DISPLAY(mHld));
	frame.size.height -= frame.origin.y;
	NSRectFill(frame);

	if (mClp <= 1.0)
	[[self hldColor] set];
	else
	[[self clpColor] set];
	
	frame = self.bounds;
	frame.origin.y += round(S * RMS2DISPLAY(mClp));
	frame.size.height = 1.0;
	NSRectFill(frame);
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////






