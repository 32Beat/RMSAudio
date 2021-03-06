////////////////////////////////////////////////////////////////////////////////
/*
	RMSDevice
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSDevice.h"
#import "RMSUtilities.h"


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
	const AudioObjectPropertyAddress propertyAddress = {
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
	const AudioObjectPropertyAddress propertyAddress = {
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
	[self getInputChannelCount];
	[self getOutputChannelCount];
	mChannelCount = _inputChannelCount+_outputChannelCount;
}

////////////////////////////////////////////////////////////////////////////////

- (void) getInputChannelCount
{
	// get input stream config
	const AudioObjectPropertyAddress propertyAddress = {
	kAudioDevicePropertyStreamConfiguration,
	kAudioObjectPropertyScopeInput, 0 };
	
	AudioBufferList *bufferList = [self getPropertyData:&propertyAddress];
	if (bufferList != nil)
	{
		_inputChannelCount = RMSAudioBufferList_GetTotalChannelCount(bufferList);
		free(bufferList);
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) getOutputChannelCount
{
	// get output stream config
	const AudioObjectPropertyAddress propertyAddress = {
	kAudioDevicePropertyStreamConfiguration,
	kAudioObjectPropertyScopeOutput, 0 };
	
	AudioBufferList *bufferList = [self getPropertyData:&propertyAddress];
	if (bufferList != nil)
	{
		_outputChannelCount = RMSAudioBufferList_GetTotalChannelCount(bufferList);
		free(bufferList);
	}
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
#endif
////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////

