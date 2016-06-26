////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUtilities
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSAudioUnitUtilities.h"


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

bool AudioUnitIsRunning(AudioUnit audioUnit)
{
	UInt32 size = sizeof(UInt32);
	UInt32 state = 0;
	
	OSStatus result = AudioUnitGetProperty(audioUnit, kAudioOutputUnitProperty_IsRunning,
	kAudioUnitScope_Global, 0, &state, &size);
	if (result != noErr)
	{}
	
	return state;
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


OSStatus RMSAudioUnitGetMaximumFramesPerSlice(AudioUnit audioUnit, UInt32 *maxFrames)
{
	if (audioUnit == nil) return paramErr;
	if (maxFrames == nil) return paramErr;
	
	UInt32 size = sizeof(UInt32);
	return AudioUnitGetProperty(audioUnit, kAudioUnitProperty_MaximumFramesPerSlice,
	kAudioUnitScope_Global, 0, maxFrames, &size);
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioUnitSetMaximumFramesPerSlice(AudioUnit audioUnit, UInt32 maxFrames)
{
	if (audioUnit == nil) return paramErr;
	
	UInt32 size = sizeof(UInt32);
	return AudioUnitSetProperty(audioUnit, kAudioUnitProperty_MaximumFramesPerSlice,
	kAudioUnitScope_Global, 0, &maxFrames, size);
}

////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////

