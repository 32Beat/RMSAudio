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
OSStatus RMSAudioDeviceGetElementName(AudioDeviceID deviceID, UInt32 index, CFStringRef *str);

OSStatus RMSAudioDeviceGetBaseClass(AudioDeviceID deviceID, AudioClassID *classID);
OSStatus RMSAudioDeviceGetClass(AudioDeviceID deviceID, AudioClassID *classID);
OSStatus RMSAudioGetNominalSampleRate(AudioDeviceID deviceID, Float64 *sampleRate);
OSStatus RMSAudioDeviceGetName(AudioObjectID objectID, CFStringRef *str);
OSStatus RMSAudioDeviceGetUniqueID(AudioDeviceID deviceID, CFStringRef *str);

OSStatus RMSAudioGetAvailableDevices(AudioObjectID **deviceList, UInt32 *count);
OSStatus RMSAudioGetDefaultInputDeviceID(AudioDeviceID *deviceID);
OSStatus RMSAudioGetDefaultOutputDeviceID(AudioDeviceID *deviceID);
OSStatus RMSAudioGetDeviceWithUniqueID(CFStringRef str, AudioDeviceID *deviceID);
#endif

AudioUnit NewAudioUnitWithDescription(AudioComponentDescription desc);

OSStatus AudioUnitEnableInputStream(AudioUnit audioUnit, UInt32 state);
OSStatus AudioUnitEnableOutputStream(AudioUnit audioUnit, UInt32 state);

OSStatus AudioUnitAttachDevice
(AudioUnit audioUnit, AudioDeviceID deviceID);
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

OSStatus RMSAudioUnitSetMaximumFramesPerSlice(AudioUnit audioUnit, UInt32 maxFrames);
OSStatus RMSAudioUnitGetMaximumFramesPerSlice(AudioUnit audioUnit, UInt32 *maxFrames);

#endif // RMSAudioUnitUtilities_h




