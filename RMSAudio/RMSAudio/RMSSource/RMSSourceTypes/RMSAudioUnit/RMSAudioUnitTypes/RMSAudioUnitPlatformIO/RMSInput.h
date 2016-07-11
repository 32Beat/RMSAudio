////////////////////////////////////////////////////////////////////////////////
/*
	RMSInput
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAudioUnitPlatformIO.h"

@interface RMSInput : RMSAudioUnitPlatformIO

+ (NSArray *) availableDevices;
+ (AudioDeviceID) deviceWithName:(NSString *)name;

+ (instancetype) defaultInput;
+ (instancetype) instanceWithDeviceID:(AudioDeviceID)deviceID;
- (instancetype) initWithDeviceID:(AudioDeviceID)deviceID;

@end
