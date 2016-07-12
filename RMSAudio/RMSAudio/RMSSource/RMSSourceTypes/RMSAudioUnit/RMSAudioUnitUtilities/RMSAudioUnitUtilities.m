////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUtilities
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSAudioUnitUtilities.h"


////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioObjectGetGlobalProperty(AudioObjectID objectID,
AudioObjectPropertySelector selectorID, UInt32 resultSize, void *resultPtr)
{
	AudioObjectPropertyAddress address = {
		selectorID,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster };
	
	return AudioObjectGetPropertyData
	(objectID, &address, 0, nil, &resultSize, resultPtr);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark System Object Utilities
////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioGetAvailableDevices(AudioObjectID **deviceList, UInt32 *count)
{
	static const AudioObjectPropertyAddress address = {
		kAudioHardwarePropertyDevices,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster };

	OSStatus result = noErr;

	UInt32 size = 0;
	result = AudioObjectGetPropertyDataSize
	(kAudioObjectSystemObject, &address, 0, nil, &size);
	if (result != noErr) return result;

	AudioObjectID *ptr = malloc(size);
	if (ptr == nil) return memFullErr;
	
	result = AudioObjectGetPropertyData
	(kAudioObjectSystemObject, &address, 0, nil, &size, ptr);
	
	*deviceList = ptr;
	*count = size / sizeof(AudioObjectID);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioGetDefaultInputDeviceID(AudioDeviceID *deviceID)
{
	return RMSAudioObjectGetGlobalProperty(kAudioObjectSystemObject,
	kAudioHardwarePropertyDefaultInputDevice, sizeof(AudioDeviceID), deviceID);
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioGetDefaultOutputDeviceID(AudioDeviceID *deviceID)
{
	return RMSAudioObjectGetGlobalProperty(kAudioObjectSystemObject,
	kAudioHardwarePropertyDefaultOutputDevice, sizeof(AudioDeviceID), deviceID);
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioGetDeviceWithUniqueID(CFStringRef str, AudioDeviceID *deviceID)
{
	UInt32 count = 0;
	AudioDeviceID *deviceList = nil;
	OSStatus result = RMSAudioGetAvailableDevices(&deviceList, &count);
	if (deviceList != nil)
	{
		for (UInt32 n=0; n!=count; n++)
		{
			CFStringRef tstStr = nil;
			result = RMSAudioDeviceGetUniqueID(deviceList[n], &tstStr);
			if (tstStr != nil)
			{
				if (CFStringCompare(str, tstStr, 0) == kCFCompareEqualTo)
				{
					*deviceID = deviceList[n];
				}
				
				CFRelease(str);
			}
		}
		
		free(deviceList);
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark AudioDevice Utilities
////////////////////////////////////////////////////////////////////////////////
#if !TARGET_OS_IPHONE


OSStatus RMSAudioDeviceGetBaseClass(AudioDeviceID deviceID, AudioClassID *classID)
{
	return RMSAudioObjectGetGlobalProperty(deviceID,
	kAudioObjectPropertyBaseClass, sizeof(AudioClassID), classID);
}

OSStatus RMSAudioDeviceGetClass(AudioDeviceID deviceID, AudioClassID *classID)
{
	return RMSAudioObjectGetGlobalProperty(deviceID,
	kAudioObjectPropertyClass, sizeof(AudioClassID), classID);
}

OSStatus RMSAudioDeviceGetName(AudioDeviceID deviceID, CFStringRef *str)
{
	return RMSAudioObjectGetGlobalProperty(deviceID,
	kAudioObjectPropertyName, sizeof(CFStringRef), str);
}

OSStatus RMSAudioDeviceGetUniqueID(AudioDeviceID deviceID, CFStringRef *str)
{
	return RMSAudioObjectGetGlobalProperty(deviceID,
	kAudioDevicePropertyDeviceUID, sizeof(CFStringRef), str);
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioGetNominalSampleRate(AudioDeviceID deviceID, Float64 *sampleRate)
{
	return RMSAudioObjectGetGlobalProperty(deviceID,
	kAudioDevicePropertyNominalSampleRate, sizeof(Float64), sampleRate);
}

////////////////////////////////////////////////////////////////////////////////

#endif
////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark AudioUnit Utilities
////////////////////////////////////////////////////////////////////////////////

AudioUnit NewAudioUnitWithDescription(AudioComponentDescription desc)
{
	AudioComponent component = AudioComponentFindNext(nil, &desc);
	if (component != nil)
	{
		AudioComponentInstance instance = nil;
		OSStatus result = AudioComponentInstanceNew(component, &instance);
		if (result == noErr)
		{
			return instance;
		}
		else
		NSLog(@"AudioComponentInstanceNew error: %d", result);
	}
	else
	NSLog(@"%@", @"AudioComponent not found!");
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////

OSStatus AudioUnitEnableInputStream(AudioUnit audioUnit, UInt32 state)
{
	if (audioUnit == nil) return paramErr;
	
	AudioUnitElement inputBus = 1;

	return AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO,
	kAudioUnitScope_Input, inputBus, &state, sizeof(UInt32));
}

////////////////////////////////////////////////////////////////////////////////

OSStatus AudioUnitEnableOutputStream(AudioUnit audioUnit, UInt32 state)
{
	if (audioUnit == nil) return paramErr;
	
	AudioUnitElement outputBus = 0;

	return AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO,
	kAudioUnitScope_Output, outputBus, &state, sizeof(UInt32));
}

////////////////////////////////////////////////////////////////////////////////

OSStatus AudioUnitSetInputCallback
(AudioUnit audioUnit, AURenderCallback renderProc, void *renderInfo)
{
	if (audioUnit == nil) return paramErr;
	if (renderProc == nil) return paramErr;
	
	AURenderCallbackStruct rcInfo = { renderProc, renderInfo };

	return AudioUnitSetProperty \
		(audioUnit, kAudioOutputUnitProperty_SetInputCallback, \
		kAudioUnitScope_Global, 0, &rcInfo, sizeof(AURenderCallbackStruct));
}

////////////////////////////////////////////////////////////////////////////////

OSStatus AudioUnitSetRenderCallback
(AudioUnit audioUnit, AURenderCallback renderProc, void *renderInfo)
{
	if (audioUnit == nil) return paramErr;
	if (renderProc == nil) return paramErr;

	AURenderCallbackStruct rcInfo = { renderProc, renderInfo };
	
	return AudioUnitSetProperty \
		(audioUnit, kAudioUnitProperty_SetRenderCallback, \
		kAudioUnitScope_Input, 0, &rcInfo, sizeof(AURenderCallbackStruct));
}

////////////////////////////////////////////////////////////////////////////////
/*
	Attach an audio IO device to the audio unit. 
	If it is an output device, it will automatically be 
	attached to (bus 0, outputscope),
	If it is an input device, it will automatically be
	attached to (bus 1, inputscope),
*/

OSStatus AudioUnitAttachDevice(AudioUnit audioUnit, AudioDeviceID deviceID)
{
	if (audioUnit == nil) return paramErr;
//	if (deviceID == 0) return paramErr;
	
	UInt32 size = sizeof(deviceID);
	return AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice,
	kAudioUnitScope_Global, 0, &deviceID, size);
}


////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark AudioUnit Global Properties
////////////////////////////////////////////////////////////////////////////////

UInt32 AudioUnitGetGlobalPropertySize(AudioUnit audioUnit, AudioUnitPropertyID propertyID)
{
	switch(propertyID)
	{
		case kAudioUnitProperty_SampleRate:
			return sizeof(Float64);
			
		case kAudioOutputUnitProperty_IsRunning:
		case kAudioUnitProperty_MaximumFramesPerSlice:
			return sizeof(UInt32);
	}
	
	UInt32 size = 0;
	OSStatus result = AudioUnitGetPropertyInfo
	(audioUnit, propertyID, kAudioUnitScope_Global, 0, &size, nil);
	if (result != noErr)
	{
	}
	
	return size;
}

////////////////////////////////////////////////////////////////////////////////

OSStatus AudioUnitGetGlobalProperty
(AudioUnit audioUnit, AudioUnitPropertyID propertyID, void *resultPtr)
{
	if (audioUnit == nil) return paramErr;
	if (resultPtr == nil) return paramErr;
	
	UInt32 size = AudioUnitGetGlobalPropertySize(audioUnit, propertyID);
	return AudioUnitGetProperty(audioUnit, propertyID,
	kAudioUnitScope_Global, 0, resultPtr, &size);
}

////////////////////////////////////////////////////////////////////////////////

OSStatus AudioUnitSetGlobalProperty
(AudioUnit audioUnit, AudioUnitPropertyID propertyID, const void *sourcePtr)
{
	if (audioUnit == nil) return paramErr;
	if (sourcePtr == nil) return paramErr;
	
	UInt32 size = AudioUnitGetGlobalPropertySize(audioUnit, propertyID);
	return AudioUnitSetProperty(audioUnit, propertyID,
	kAudioUnitScope_Global, 0, sourcePtr, size);
}

////////////////////////////////////////////////////////////////////////////////

bool AudioUnitIsRunning(AudioUnit audioUnit)
{
	UInt32 state = 0;
	
	OSStatus result = AudioUnitGetGlobalProperty
	(audioUnit, kAudioOutputUnitProperty_IsRunning, &state);

	return state;
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioUnitGetMaximumFramesPerSlice(AudioUnit audioUnit, UInt32 *maxFrames)
{
	return AudioUnitGetGlobalProperty
	(audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, maxFrames);
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioUnitSetMaximumFramesPerSlice(AudioUnit audioUnit, UInt32 maxFrames)
{
	return AudioUnitSetGlobalProperty
	(audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, &maxFrames);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioUnitGetFormatAtIndex(AudioUnit audioUnit, AudioUnitScope unitScope,
AudioUnitElement streamIndex, AudioStreamBasicDescription *audioFormat)
{
	if (audioUnit == nil) return paramErr;
	if (audioFormat == nil) return paramErr;

	UInt32 size = sizeof(AudioStreamBasicDescription);
	return AudioUnitGetProperty
		(audioUnit, kAudioUnitProperty_StreamFormat, \
		unitScope, streamIndex, audioFormat, &size);
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioUnitGetInputScopeFormatAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, AudioStreamBasicDescription *resultPtr)
{ return RMSAudioUnitGetFormatAtIndex(audioUnit, kAudioUnitScope_Input, streamIndex, resultPtr); }

OSStatus RMSAudioUnitGetOutputScopeFormatAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, AudioStreamBasicDescription *resultPtr)
{ return RMSAudioUnitGetFormatAtIndex(audioUnit, kAudioUnitScope_Output, streamIndex, resultPtr); }

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioUnitSetFormatAtIndex(AudioUnit audioUnit, AudioUnitScope unitScope,
AudioUnitElement streamIndex, const AudioStreamBasicDescription *audioFormat)
{
	if (audioUnit == nil) return paramErr;
	if (audioFormat == nil) return paramErr;

	UInt32 size = sizeof(AudioStreamBasicDescription);
	return AudioUnitSetProperty
		(audioUnit, kAudioUnitProperty_StreamFormat, \
		unitScope, streamIndex, audioFormat, size);
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioUnitSetInputScopeFormatAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, const AudioStreamBasicDescription *resultPtr)
{ return RMSAudioUnitSetFormatAtIndex(audioUnit, kAudioUnitScope_Input, streamIndex, resultPtr); }

OSStatus RMSAudioUnitSetOutputScopeFormatAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, const AudioStreamBasicDescription *resultPtr)
{ return RMSAudioUnitSetFormatAtIndex(audioUnit, kAudioUnitScope_Output, streamIndex, resultPtr); }

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioUnitGetSampleRateAtIndex(AudioUnit audioUnit, AudioUnitScope unitScope,
AudioUnitElement streamIndex, Float64 *sampleRatePtr)
{
	if (audioUnit == nil) return paramErr;
	if (sampleRatePtr == nil) return paramErr;

	UInt32 size = sizeof(Float64);
	return AudioUnitGetProperty
		(audioUnit, kAudioUnitProperty_SampleRate, \
		unitScope, streamIndex, sampleRatePtr, &size);
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioUnitGetInputScopeSampleRateAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, Float64 *sampleRatePtr)
{ return RMSAudioUnitGetSampleRateAtIndex(audioUnit, kAudioUnitScope_Input, streamIndex, sampleRatePtr); }

OSStatus RMSAudioUnitGetOutputScopeSampleRateAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, Float64 *sampleRatePtr)
{ return RMSAudioUnitGetSampleRateAtIndex(audioUnit, kAudioUnitScope_Output, streamIndex, sampleRatePtr); }

////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////

