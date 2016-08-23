////////////////////////////////////////////////////////////////////////////////
/*
	RMSDevice
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSDevice.h"
#import "RMSUtilities.h"
#import "RMSAudioUnitUtilities.h"

////////////////////////////////////////////////////////////////////////////////

@interface RMSDevice ()
{
	UInt32 mChannelCount;
}

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *uniqueID;
@property (nonatomic, assign) UInt32 inputChannelCount;
@property (nonatomic, assign) UInt32 outputChannelCount;

@end

////////////////////////////////////////////////////////////////////////////////
@implementation RMSDevice
////////////////////////////////////////////////////////////////////////////////

+ (instancetype) instanceWithDeviceID:(AudioDeviceID)deviceID
{ return [[self alloc] initWithDeviceID:deviceID]; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{ return [self initWithDeviceID:0]; }

- (instancetype) initWithDeviceID:(AudioDeviceID)deviceID
{
	self = [super init];
	if (self != nil)
	{
		_deviceID = deviceID;
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////
#if TARGET_OS_IPHONE

- (NSString *) name
{ return self.portName; }

////////////////////////////////////////////////////////////////////////////////
#else
////////////////////////////////////////////////////////////////////////////////

- (NSString *) name
{
	if (_name == nil)
	{ [self getName]; }
	return [_name copy];
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) getName
{
	// get device name
	static const AudioObjectPropertyAddress propertyAddress = {
	kAudioObjectPropertyName,
	kAudioObjectPropertyScopeGlobal,
	kAudioObjectPropertyElementMaster };

	CFStringRef strRef = nil;
	UInt32 size = sizeof(CFStringRef);
	OSStatus error = AudioObjectGetPropertyData
	(self.deviceID, &propertyAddress, 0, NULL, &size, &strRef);

	if(strRef != nil)
	{
		_name = CFBridgingRelease(strRef);
	}
	
	return error;
}

////////////////////////////////////////////////////////////////////////////////

- (NSString *) uniqueID
{
	if (_uniqueID == nil)
	{ [self getUniqueID]; }
	return [_uniqueID copy];
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) getUniqueID
{
	static const AudioObjectPropertyAddress propertyAddress = {
	kAudioDevicePropertyDeviceUID,
	kAudioObjectPropertyScopeGlobal,
	kAudioObjectPropertyElementMaster };

	CFStringRef strRef = nil;
	UInt32 size = sizeof(CFStringRef);
	OSStatus error = AudioObjectGetPropertyData
	(self.deviceID, &propertyAddress, 0, NULL, &size, &strRef);

	if(strRef != nil)
	{
		_uniqueID = CFBridgingRelease(strRef);
	}
	
	return error;
}

////////////////////////////////////////////////////////////////////////////////

- (UInt32) inputChannelCount
{
	if (mChannelCount == 0)
	{ [self getChannelCounts]; }
	return _inputChannelCount;
}

////////////////////////////////////////////////////////////////////////////////

- (UInt32) outputChannelCount
{
	if (mChannelCount == 0)
	{ [self getChannelCounts]; }
	return _outputChannelCount;
}

////////////////////////////////////////////////////////////////////////////////

- (void) getChannelCounts
{
	_inputChannelCount = [self getInputChannelCount];
	_outputChannelCount = [self getOutputChannelCount];
	mChannelCount = _inputChannelCount+_outputChannelCount;
}

////////////////////////////////////////////////////////////////////////////////

- (UInt32) getInputChannelCount
{ return [self getChannelCountForScope:kAudioObjectPropertyScopeInput]; }

- (UInt32) getOutputChannelCount
{ return [self getChannelCountForScope:kAudioObjectPropertyScopeOutput]; }

////////////////////////////////////////////////////////////////////////////////

- (UInt32) getChannelCountForScope:(AudioObjectPropertyScope)scope
{
	UInt32 channelCount = 0;
	
	// get input stream config
	AudioObjectPropertyAddress propertyAddress =
	{ kAudioDevicePropertyStreamConfiguration, scope, 0 };
	
	AudioBufferList *bufferList = [self getPropertyData:&propertyAddress];
	if (bufferList != nil)
	{
		channelCount = RMSAudioBufferList_GetTotalChannelCount(bufferList);
		free(bufferList);
	}
	
	return channelCount;
}

////////////////////////////////////////////////////////////////////////////////

- (void *) getPropertyData:(const AudioObjectPropertyAddress *)address
{
	UInt32 size = [self getPropertySize:address];
	if (size != 0)
	{
		void *ptr = malloc(size);
		if (ptr != nil)
		{
			OSStatus error = AudioObjectGetPropertyData
			(self.deviceID, address, 0, NULL, &size, ptr);
			if (error == noErr)
			{
				return ptr;
			}
			
			free(ptr);
		}
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////

- (UInt32) getPropertySize:(const AudioObjectPropertyAddress *)address
{
	UInt32 size = 0;
	
	OSStatus error = AudioObjectGetPropertyDataSize
	(self.deviceID, address, 0, NULL, &size);
	if (error != noErr) size = 0;
	
	return size;
}

////////////////////////////////////////////////////////////////////////////////

- (UInt32) bufferSize
{
	UInt32 bufferSize = 0;
	OSStatus error = RMSAudioDeviceGetBufferFrameSize(self.deviceID, &bufferSize);
	if (error != noErr)
	{
	}
	
	return bufferSize;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) setBufferSize:(UInt32)bufferSize
{
	OSStatus result = RMSAudioDeviceSetBufferFrameSize(self.deviceID, bufferSize);
	return result;
}

////////////////////////////////////////////////////////////////////////////////
#endif
////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////

