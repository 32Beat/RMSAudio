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
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *uniqueID;

+ (instancetype) instanceWithDeviceID:(AudioDeviceID)deviceID;
- (instancetype) initWithDeviceID:(AudioDeviceID)deviceID;
- (UInt32) inputChannelCount;
- (UInt32) outputChannelCount;

@end
////////////////////////////////////////////////////////////////////////////////



