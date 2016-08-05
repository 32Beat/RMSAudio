////////////////////////////////////////////////////////////////////////////////
/*
	RMSDevice
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////
#if !TARGET_OS_IPHONE
#import <CoreAudio/CoreAudio.h>
@interface RMSDevice : NSObject
#else
#import <AVFoundation/AVFoundation.h>
typedef UInt32 AudioDeviceID;
@interface RMSDevice : AVAudioSessionPortDescription
#endif

@property (nonatomic, readonly) AudioDeviceID deviceID;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *uniqueID;
@property (nonatomic, readonly) UInt32 inputChannelCount;
@property (nonatomic, readonly) UInt32 outputChannelCount;

+ (instancetype) instanceWithDeviceID:(AudioDeviceID)deviceID;

- (OSStatus) setBufferSize:(UInt32)bufferSize;

@end
////////////////////////////////////////////////////////////////////////////////



