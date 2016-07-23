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
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *uniqueID;
@property (nonatomic, readonly) UInt32 inputChannelCount;
@property (nonatomic, readonly) UInt32 outputChannelCount;

+ (instancetype) instanceWithDeviceID:(AudioDeviceID)deviceID;

@end
////////////////////////////////////////////////////////////////////////////////



