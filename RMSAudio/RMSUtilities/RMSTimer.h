////////////////////////////////////////////////////////////////////////////////
/*
	RMSTimer.h
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.

	RMSTimer
	--------
	Global timer object for firing on main at approximately 25 times per sec, 
	will fire during tracking and modal runloops.

	Purpose: to reduce CPU load by using a single global NSTimer for periodic 
	updates of multiple objects or views.

	Usage indication:
	If an object implements "globalRMSTimerDidFire" and is added to the timer, 
	it can for example generate updates for an rmsview at the mentioned rate.
	
	RMSTimer is not threadsafe and meant to be used on a single thread only.
*/
////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

@protocol RMSTimerProtocol <NSObject>
- (void) globalRMSTimerDidFire;
@end

@interface RMSTimer : NSObject
+ (void) addRMSTimerObserver:(id<RMSTimerProtocol>)observer;
+ (void) removeRMSTimerObserver:(id<RMSTimerProtocol>)observer;
@end
