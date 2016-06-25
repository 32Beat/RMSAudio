////////////////////////////////////////////////////////////////////////////////
/*
	RMSOutput
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAudioUnitPlatformIO.h"

@interface RMSOutput : RMSAudioUnitPlatformIO

+ (instancetype) defaultOutput;

- (NSTimeInterval) averageRenderTime;
- (NSTimeInterval) maximumRenderTime;
- (void) resetTimingInfo;

@end
