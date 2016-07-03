////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUnit
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAudioUnit.h"
#import "RMSAudioUnitUtilities.h"
#import "RMSAudio.h"

@interface RMSAudioUnit ()
{
	BOOL mAudioUnitIsInitialized;
	
	UInt32 mDefaultBusIndex;
}
@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSAudioUnit
////////////////////////////////////////////////////////////////////////////////
/*
	The RMSCallback for an RMSAudioUnit defaults to calling AudioUnitRender
*/
static OSStatus renderCallback(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	__unsafe_unretained RMSAudioUnit *rmsSource = \
	(__bridge __unsafe_unretained RMSAudioUnit *)rmsObject;
	
	AudioUnitRenderActionFlags actionFlags = 0;
	AudioTimeStamp timeStamp;
	timeStamp.mSampleTime = infoPtr->frameIndex;
	timeStamp.mFlags = kAudioTimeStampSampleTimeValid;
	
	return AudioUnitRender(rmsSource->mAudioUnit,
	&actionFlags, &timeStamp, rmsSource->mDefaultBusIndex, infoPtr->frameCount, infoPtr->bufferListPtr);
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
/*
	Following implementation allows all subclasses to use [super init]
	for initialization by overwriting the class componentdescription, or
	alternatively default to an instance of AUHAL.
	
	We use a class global componentDescription since an instance->componentDescription 
	should generally reflect the current internal state of an object.
	
	initWithDescription: ensures that we are responsible for creating the audioUnit, 
	and hence also should dispose of it properly.

	Technically we might want to include a default initializer that supplies the audioUnit,
	e.g. initWithAudioUnit: since RMSAudioUnit merely is an audioUnit controller object, 
	but that would make it less clear who's responsible for disposing the audioUnit.
*/

#if TARGET_OS_IPHONE
#define kAudioUnitSubType_PlatformIO kAudioUnitSubType_RemoteIO
#else
#define kAudioUnitSubType_PlatformIO kAudioUnitSubType_HALOutput
#endif


+ (AudioComponentDescription) componentDescription
{
	return
	(AudioComponentDescription) {
		.componentType = kAudioUnitType_Output,
		.componentSubType = kAudioUnitSubType_PlatformIO,
		.componentManufacturer = kAudioUnitManufacturer_Apple,
		.componentFlags = 0,
		.componentFlagsMask = 0 };
}

- (instancetype) init
{ return [self initWithDescription:[[self class] componentDescription]]; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) initWithAUPlaformIO
{
	return [self initWithDescription:
	(AudioComponentDescription){
		.componentType = kAudioUnitType_Output,
		.componentSubType = kAudioUnitSubType_PlatformIO,
		.componentManufacturer = kAudioUnitManufacturer_Apple,
		.componentFlags = 0,
		.componentFlagsMask = 0
	}];
}

////////////////////////////////////////////////////////////////////////////////
// Default initializer

+ (instancetype) instanceWithDescription:(AudioComponentDescription)desc
{ return [[self alloc] initWithDescription:desc]; }

- (instancetype) initWithDescription:(AudioComponentDescription)desc
{
	self = [super init];
	if (self != nil)
	{
		mAudioUnit = NewAudioUnitWithDescription(desc);
		if (mAudioUnit == nil) return nil;
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	if (mAudioUnit != nil)
	{ AudioComponentInstanceDispose(mAudioUnit); }
	mAudioUnit = nil;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////


- (OSStatus) initializeAudioUnit
{
	OSStatus result = AudioUnitInitialize(mAudioUnit);
	if (result == noErr)
	{ mAudioUnitIsInitialized = YES; }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) uninitializeAudioUnit
{
	OSStatus result = AudioUnitUninitialize(mAudioUnit);
	if (result == noErr)
	{ mAudioUnitIsInitialized = NO; }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (void) setSampleRate:(Float64)sampleRate
{
	[super setSampleRate:sampleRate];

	AudioStreamBasicDescription streamFormat;
	OSStatus result = [self getResultFormat:&streamFormat];
	if (result == noErr)
	{
		// Check for actual change of sampleRate
		if (streamFormat.mSampleRate != sampleRate)
		{
			streamFormat.mSampleRate = sampleRate;
			result = [self setResultFormat:&streamFormat];
			// kAudioUnitErr_PropertyNotWritable
		}
	}
}

////////////////////////////////////////////////////////////////////////////////

- (Float64) inputScopeSampleRate
{
	// Get inputscope format for this->audiounit
	AudioStreamBasicDescription streamFormat;
	OSStatus result = [self getSourceFormat:&streamFormat];
	if (result == noErr)
	{ return streamFormat.mSampleRate; }
	
	return 0.0;
}

////////////////////////////////////////////////////////////////////////////////

- (void) setInputSampleRate:(Float64)sampleRate
{
	// Get inputscope format for this->audiounit
	AudioStreamBasicDescription streamFormat;
	OSStatus result = [self getSourceFormat:&streamFormat];
	if (result == noErr)
	{
		// Check for actual change of sampleRate
		if (streamFormat.mSampleRate != sampleRate)
		{
			// Set inputscope format for this->audiounit with new sampleRate
			streamFormat.mSampleRate = sampleRate;
			result = [self setSourceFormat:&streamFormat];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) getSourceFormat:(AudioStreamBasicDescription *)streamInfoPtr
{
	OSStatus result = RMSAudioUnitGetInputScopeFormatAtIndex
	(mAudioUnit, mDefaultBusIndex, streamInfoPtr);
	
	if (result != noErr)
	{ NSLog(@"getSourceFormat returned %d", result); }

	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) setSourceFormat:(const AudioStreamBasicDescription *)streamInfoPtr
{
	if (mAudioUnitIsInitialized)
	AudioUnitUninitialize(mAudioUnit);
	
	OSStatus result = RMSAudioUnitSetInputScopeFormatAtIndex
	(mAudioUnit, mDefaultBusIndex, streamInfoPtr);
	
	if (result != noErr)
	{ NSLog(@"setSourceFormat returned %d", result); }

	if (mAudioUnitIsInitialized)
	AudioUnitInitialize(mAudioUnit);

	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) getResultFormat:(AudioStreamBasicDescription *)streamInfoPtr
{
	OSStatus result = RMSAudioUnitGetOutputScopeFormatAtIndex(mAudioUnit, mDefaultBusIndex, streamInfoPtr);
	if (result != noErr)
	{ NSLog(@"getResultFormat returned %d", result); }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) setResultFormat:(const AudioStreamBasicDescription *)streamInfoPtr
{
	if (mAudioUnitIsInitialized)
	AudioUnitUninitialize(mAudioUnit);

	OSStatus result = RMSAudioUnitSetOutputScopeFormatAtIndex(mAudioUnit, mDefaultBusIndex, streamInfoPtr);
	if (result != noErr)
	{ NSLog(@"setResultFormat returned %d", result); }

	if (mAudioUnitIsInitialized)
	AudioUnitInitialize(mAudioUnit);

	return result;
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////







