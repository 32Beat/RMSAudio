////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUnitUtilities
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#ifndef RMSAudioUnitUtilities_h
#define RMSAudioUnitUtilities_h

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <Accelerate/Accelerate.h>

#if !TARGET_OS_IPHONE

OSStatus RMSAudioGetAvailableDevices(AudioObjectID **deviceList, UInt32 *count);
OSStatus RMSAudioGetDefaultInputDeviceID(AudioDeviceID *deviceID);
OSStatus RMSAudioGetDefaultOutputDeviceID(AudioDeviceID *deviceID);
OSStatus RMSAudioGetDeviceWithUniqueID(CFStringRef str, AudioDeviceID *deviceID);

OSStatus RMSAudioDeviceGetBaseClass(AudioDeviceID deviceID, AudioClassID *classID);
OSStatus RMSAudioDeviceGetClass(AudioDeviceID deviceID, AudioClassID *classID);
OSStatus RMSAudioDeviceGetName(AudioObjectID objectID, CFStringRef *str);
OSStatus RMSAudioDeviceGetUniqueID(AudioDeviceID deviceID, CFStringRef *str);
OSStatus RMSAudioDeviceGetNominalSampleRate(AudioDeviceID deviceID, Float64 *sampleRate);
OSStatus RMSAudioDeviceGetBufferFrameSize(AudioDeviceID deviceID, UInt32 *frameSize);
OSStatus RMSAudioDeviceSetBufferFrameSize(AudioDeviceID deviceID, UInt32 frameSize);

OSStatus AudioUnitAttachDevice
(AudioUnit audioUnit, AudioDeviceID deviceID);

#endif

AudioUnit NewAudioUnitWithDescription(AudioComponentDescription desc);

OSStatus AudioUnitEnableInputStream(AudioUnit audioUnit, UInt32 state);
OSStatus AudioUnitEnableOutputStream(AudioUnit audioUnit, UInt32 state);

OSStatus AudioUnitSetInputCallback
(AudioUnit audioUnit, AURenderCallback renderProc, void *renderInfo);
OSStatus AudioUnitSetRenderCallback
(AudioUnit audioUnit, AURenderCallback renderProc, void *renderInfo);

OSStatus RMSAudioUnitGetSampleRateAtIndex(AudioUnit audioUnit, AudioUnitScope unitScope,
AudioUnitElement streamIndex, Float64 *sampleRatePtr);
OSStatus RMSAudioUnitGetInputScopeSampleRateAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, Float64 *sampleRatePtr);
OSStatus RMSAudioUnitGetOutputScopeSampleRateAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, Float64 *sampleRatePtr);

OSStatus RMSAudioUnitGetFormatAtIndex(AudioUnit audioUnit, AudioUnitScope unitScope,
AudioUnitElement streamIndex, AudioStreamBasicDescription *audioFormat);
OSStatus RMSAudioUnitGetInputScopeFormatAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, AudioStreamBasicDescription *resultPtr);
OSStatus RMSAudioUnitGetOutputScopeFormatAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, AudioStreamBasicDescription *resultPtr);

OSStatus RMSAudioUnitSetFormatAtIndex(AudioUnit audioUnit, AudioUnitScope unitScope,
AudioUnitElement streamIndex, const AudioStreamBasicDescription *audioFormat);
OSStatus RMSAudioUnitSetInputScopeFormatAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, const AudioStreamBasicDescription *resultPtr);
OSStatus RMSAudioUnitSetOutputScopeFormatAtIndex(AudioUnit audioUnit,
AudioUnitElement streamIndex, const AudioStreamBasicDescription *resultPtr);

OSStatus RMSAudioUnitGetLatency(AudioUnit audioUnit, Float64 *valuePtr);
OSStatus RMSAudioUnitSetMaximumFramesPerSlice(AudioUnit audioUnit, UInt32 maxFrames);
OSStatus RMSAudioUnitGetMaximumFramesPerSlice(AudioUnit audioUnit, UInt32 *maxFrames);

OSStatus AudioUnitGetGlobalProperty
(AudioUnit audioUnit, AudioUnitPropertyID propertyID, void *resultPtr);
OSStatus AudioUnitSetGlobalProperty
(AudioUnit audioUnit, AudioUnitPropertyID propertyID, const void *sourcePtr);


#endif // RMSAudioUnitUtilities_h




