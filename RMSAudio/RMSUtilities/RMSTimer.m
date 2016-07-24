////////////////////////////////////////////////////////////////////////////////
/*
	RMSTimerView.m
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSTimer.h"


@interface RMSTimer ()
{
	NSTimer *mTimer;
	NSMutableArray *mObservers;
}
@end



@implementation RMSTimer

////////////////////////////////////////////////////////////////////////////////

static RMSTimer *g_timer = nil;

+ (void) initialize
{
	if (g_timer == nil)
	{ g_timer = [[self class] new]; }
}

////////////////////////////////////////////////////////////////////////////////

+ (void) addRMSTimerObserver:(id<RMSTimerProtocol>)observer
{ [g_timer addRMSTimerObserver:observer]; }

+ (void) removeRMSTimerObserver:(id<RMSTimerProtocol>)observer
{ [g_timer removeRMSTimerObserver:observer]; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Observer Management
////////////////////////////////////////////////////////////////////////////////

- (void) addRMSTimerObserver:(id<RMSTimerProtocol>)observer
{
	if ([observer respondsToSelector:@selector(globalRMSTimerDidFire)])
	{
		if (mObservers == nil)
		{ mObservers = [NSMutableArray new]; }

		if ([mObservers indexOfObjectIdenticalTo:observer] == NSNotFound)
		{
			[mObservers addObject:observer];
			if (mObservers.count != 0)
			{ [self startTimer]; }
		}
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeRMSTimerObserver:(id<RMSTimerProtocol>)observer
{
	if ([mObservers indexOfObjectIdenticalTo:observer] != NSNotFound)
	{
		[mObservers removeObject:observer];
		if (mObservers.count == 0)
		{ [self stopTimer]; }
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Timer Management
////////////////////////////////////////////////////////////////////////////////

- (void) startTimer
{
	if (mTimer == nil)
	{
		// set timer to appr 25 updates per second
		mTimer = [NSTimer timerWithTimeInterval:1.0/25.0
		target:self selector:@selector(timerDidFire:) userInfo:nil repeats:YES];
		
		// add tolerance down to appr 20 updates per second
		[mTimer setTolerance:(1.0/20.0)-(1.0/25.0)];
		
		// add to runloop
		[[NSRunLoop currentRunLoop] addTimer:mTimer
        forMode:NSRunLoopCommonModes];
		
		/*
			Note that a scheduledTimer will only run in default runloopmode,
			which means it doesn't fire during tracking or modal panels, etc...
		*/
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) stopTimer
{
	if (mTimer != nil)
	{
		[mTimer invalidate];
		mTimer = nil;
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) timerDidFire:(NSTimer *)timer
{
	if (mObservers.count != 0)
		[mObservers makeObjectsPerformSelector:
		@selector(globalRMSTimerDidFire)];
	else
		[self stopTimer];
}

////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////

@end








