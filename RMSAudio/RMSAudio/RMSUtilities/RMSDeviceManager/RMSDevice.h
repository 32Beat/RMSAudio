////////////////////////////////////////////////////////////////////////////////
/*
	RMSDevice
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAudio.h"

////////////////////////////////////////////////////////////////////////////////
@interface RMSDevice : NSObject
@property (nonatomic, readonly) AudioDeviceID deviceID;

+ (instancetype) instanceWithDeviceID:(AudioDeviceID)deviceID;
- (instancetype) initWithDeviceID:(AudioDeviceID)deviceID;

@end
////////////////////////////////////////////////////////////////////////////////



