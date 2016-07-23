////////////////////////////////////////////////////////////////////////////////
/*
	RMSDeviceManager
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSDeviceManager.h"
#import "RMSDevice.h"


@interface RMSDeviceManager ()
{
}
@property (nonatomic) NSArray *deviceList;
@property (nonatomic) NSArray *inputDeviceList;
@property (nonatomic) NSArray *outputDeviceList;

@end

////////////////////////////////////////////////////////////////////////////////
@implementation RMSDeviceManager
////////////////////////////////////////////////////////////////////////////////

+ (instancetype) sharedInstance
{
	static RMSDeviceManager *gManager = nil;
	if (gManager == nil)
	{ gManager = [RMSDeviceManager new]; }
	
	return gManager;
}

////////////////////////////////////////////////////////////////////////////////

+ (NSArray *) availableDevices
{ return [[self sharedInstance] deviceList]; }

////////////////////////////////////////////////////////////////////////////////

+ (NSArray *) availableInputDevices
{ return [[self sharedInstance] inputDeviceList]; }

////////////////////////////////////////////////////////////////////////////////

+ (NSArray *) availableOutputDevices
{ return [[self sharedInstance] outputDeviceList]; }

////////////////////////////////////////////////////////////////////////////////

- (NSArray *) deviceList
{
	if (_deviceList == nil)
	{ [self refreshList]; }
	
	return _deviceList;
}

////////////////////////////////////////////////////////////////////////////////

- (NSArray *) inputDeviceList
{
	if (_inputDeviceList == nil)
	{
		NSArray *deviceList = [self deviceList];
		
		NSMutableArray *inputDeviceList = [NSMutableArray new];
		for (RMSDevice *device in deviceList)
		{
			if (device.inputChannelCount > 0)
			{ [inputDeviceList addObject:device]; }
		}
		
		_inputDeviceList = inputDeviceList;
	}
	
	return _inputDeviceList;
}

////////////////////////////////////////////////////////////////////////////////

- (NSArray *) outputDeviceList
{
	if (_outputDeviceList == nil)
	{
		NSArray *deviceList = [self deviceList];
		
		NSMutableArray *outputDeviceList = [NSMutableArray new];
		for (RMSDevice *device in deviceList)
		{
			if (device.outputChannelCount > 0)
			{ [outputDeviceList addObject:device]; }
		}
		
		_outputDeviceList = outputDeviceList;
	}
	
	return _outputDeviceList;
}

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{
	self = [super init];
	if (self != nil)
	{
		[self prepareDeviceListNotifications];
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////
#if TARGET_OS_IPHONE

- (void) prepareDeviceListNotifications
{
}

- (OSStatus) refreshList
{
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////
#else
////////////////////////////////////////////////////////////////////////////////

static const AudioObjectPropertyAddress gDeviceListProperty = {
kAudioHardwarePropertyDevices,
kAudioObjectPropertyScopeGlobal,
kAudioObjectPropertyElementMaster };

- (void) prepareDeviceListNotifications
{
	AudioObjectAddPropertyListener
	(kAudioObjectSystemObject, &gDeviceListProperty, DeviceListNote, (__bridge void *)self);
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus DeviceListNote(AudioObjectID inObjectID,
UInt32 addressCount, const AudioObjectPropertyAddress address[], void* clientData)
{
	UInt32 n = addressCount;
	BOOL deviceListChanged = NO;
	
	while (deviceListChanged == NO && n != 0)
	{
		n -= 1;
		deviceListChanged =
		(address[n].mSelector == kAudioHardwarePropertyDevices);
	}
	
	if (deviceListChanged == YES)
	{
		dispatch_async(dispatch_get_main_queue(),
		^{ [(__bridge RMSDeviceManager *)clientData refreshList]; });
	}
	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) refreshList
{
	_deviceList = nil;
	_inputDeviceList = nil;
	_outputDeviceList = nil;

	UInt32 size = 0;
	OSStatus error = AudioObjectGetPropertyDataSize
	(kAudioObjectSystemObject, &gDeviceListProperty, 0, NULL, &size);
	if (error != noErr) return error;

	if (size != 0)
	{
		AudioDeviceID *listPtr = malloc(size);
		if (listPtr != nil)
		{
			error = AudioObjectGetPropertyData
			(kAudioObjectSystemObject, &gDeviceListProperty, 0, NULL, &size, listPtr);
			
			UInt32 deviceCount = size / sizeof(AudioDeviceID);
			
			NSMutableArray *deviceList = [NSMutableArray new];
			for (UInt32 n=0; n!=deviceCount; n++)
			{
				RMSDevice *device = [RMSDevice instanceWithDeviceID:listPtr[n]];
				[deviceList addObject:device];
			}
			
			_deviceList = deviceList;
	
			free(listPtr);
			
			return noErr;
		}
		
		return memFullErr;
	}
	
	return paramErr;
}

#endif
////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////









