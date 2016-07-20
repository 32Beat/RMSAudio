////////////////////////////////////////////////////////////////////////////////
/*
	RMSDeviceManager
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSDeviceManager.h"
#import "RMSDevice.h"


static const AudioObjectPropertyAddress gDeviceListProperty = {
kAudioHardwarePropertyDevices,
kAudioObjectPropertyScopeGlobal,
kAudioObjectPropertyElementMaster };

@interface RMSDeviceManager ()
{
	NSMutableArray *mDeviceList;
}
@property (nonatomic) NSArray *deviceList;
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

- (NSArray *) deviceList
{
	if (_deviceList == nil)
	{ [self refreshList]; }
	
	return _deviceList;
}

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{
	self = [super init];
	if (self != nil)
	{
		AudioObjectAddPropertyListener
		(kAudioObjectSystemObject, &gDeviceListProperty, DeviceListNote, (__bridge void *)self);
	}
	
	return self;
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

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////









