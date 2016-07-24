////////////////////////////////////////////////////////////////////////////////
/*
	RMSInput
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAudio.h"

@interface RMSInput : RMSAudioUnitPlatformIO

+ (NSArray *) availableDevices;

+ (instancetype) defaultInput;
+ (instancetype) instanceWithDevice:(RMSDevice *)device;
+ (instancetype) instanceWithDevice:(RMSDevice *)device error:(NSError **)errorPtr;

@end
