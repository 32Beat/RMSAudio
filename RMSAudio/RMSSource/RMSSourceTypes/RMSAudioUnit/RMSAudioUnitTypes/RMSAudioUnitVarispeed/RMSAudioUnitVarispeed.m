////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUnitVarispeed
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSAudioUnitVarispeed.h"
#import "RMSUtilities.h"
#import "RMSAudio.h"


@interface RMSAudioUnitVarispeed ()
{
}
@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSAudioUnitVarispeed
////////////////////////////////////////////////////////////////////////////////
/*
	RMSSource callback = RMSAudioUnit callback = AudioUnitRender
	
	AudioUnitRender will trigger this renderCallback for input data
*/

static OSStatus renderCallback(
	void 							*inRefCon,
	AudioUnitRenderActionFlags 		*actionFlags,
	const AudioTimeStamp 			*timeStamp,
	UInt32							busNumber,
	UInt32							frameCount,
	AudioBufferList 				*bufferList)
{
// may need to translate timeStamp to sampleTime
// for now, return error

	AudioTimeStamp sampleTime;
	if ((timeStamp->mFlags & kAudioTimeStampSampleTimeValid)==0)
	{
		//
		timeStamp = &sampleTime;
		return paramErr;
	}

	RMSCallbackInfo info;
	info.frameIndex = timeStamp->mSampleTime;
	info.frameCount = frameCount;
	info.bufferListPtr = bufferList;
		
	OSStatus result = RunRMSChain(RMSSourceGetSource(inRefCon), &info);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

+ (AudioComponentDescription) componentDescription
{
	return
	(AudioComponentDescription) {
		.componentType = kAudioUnitType_FormatConverter,
		.componentSubType = kAudioUnitSubType_Varispeed,
		.componentManufacturer = kAudioUnitManufacturer_Apple,
		.componentFlags = 0,
		.componentFlagsMask = 0 };
}

////////////////////////////////////////////////////////////////////////////////

+ (instancetype)instanceWithSource:(RMSSource *)source
{ return [[self alloc] initWithSource:source]; }

- (instancetype)initWithSource:(RMSSource *)source;
{
	self = [super init];
	if (self != nil)
	{
		/*
			RMSSource callback = RMSAudioUnit callback = AudioUnitRender
			
			AudioUnitRender will trigger this renderCallback for input data
		*/
		AudioUnitSetRenderCallback(mAudioUnit, renderCallback, (__bridge void *)self);
		
		[self setSource:source];
		[self setRenderQuality:1.0];

		[self initializeAudioUnit];
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{ return [self initWithSource:nil]; }

////////////////////////////////////////////////////////////////////////////////

- (void) setSource:(RMSSource *)source
{
	[super setSource:source];
	
	if ([source respondsToSelector:@selector(getResultFormat:)])
	{
		AudioStreamBasicDescription streamFormat;
		OSStatus result = [(id)source getResultFormat:&streamFormat];
		if (result == noErr)
		{ [self setSourceFormat:&streamFormat]; }
	}
	else
	{
		AudioStreamBasicDescription streamFormat = RMSPreferredAudioFormat;
		streamFormat.mSampleRate = [source sampleRate];
		[self setSourceFormat:&streamFormat];
		//[self setInputSampleRate:[source sampleRate]];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (AudioUnitParameterValue) playbackRate
{
	AudioUnitParameterValue value = 0.0;
	AudioUnitGetParameter(mAudioUnit,
	kVarispeedParam_PlaybackRate, kAudioUnitScope_Global, 0, &value);
	return value;
}

- (OSStatus) setPlaybackRate:(AudioUnitParameterValue)value
{
	return AudioUnitSetParameter(mAudioUnit,
	kVarispeedParam_PlaybackRate, kAudioUnitScope_Global, 0, value, 0);
}

////////////////////////////////////////////////////////////////////////////////

- (AudioUnitParameterValue) playbackCents
{
	AudioUnitParameterValue value = 0.0;
	AudioUnitGetParameter(mAudioUnit,
	kVarispeedParam_PlaybackCents, kAudioUnitScope_Global, 0, &value);
	return value;
}

- (OSStatus) setPlaybackCents:(AudioUnitParameterValue)value
{
	return AudioUnitSetParameter(mAudioUnit,
	kVarispeedParam_PlaybackCents, kAudioUnitScope_Global, 0, value, 0);
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





