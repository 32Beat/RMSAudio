////////////////////////////////////////////////////////////////////////////////
/*
	RMSOutput
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAudioUnitPlatformIO.h"

@class RMSOutput;

@protocol RMSOutputDelegate
- (void) audioOutput:(RMSOutput *)output didChangeState:(UInt32)state;
@end

@interface RMSOutput : RMSAudioUnitPlatformIO
@property (nonatomic, weak) id<RMSOutputDelegate> delegate;

+ (instancetype) defaultOutput;
+ (instancetype) instanceWithDeviceID:(AudioDeviceID)deviceID;
- (instancetype) initWithDeviceID:(AudioDeviceID)deviceID;

- (NSTimeInterval) averageRenderTime;
- (NSTimeInterval) maximumRenderTime;
- (void) resetTimingInfo;

@end
