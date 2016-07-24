////////////////////////////////////////////////////////////////////////////////
/*
	RMSInput
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSInput.h"
#import "RMSAudio.h"
#import "RMSRingBuffer.h"
#import <AVFoundation/AVFoundation.h>
#import <mach/mach_time.h>



@interface RMSInput ()
{
	double mStartTime;
	UInt64 mSampleCount;
	double mNominalSampleRate;
	
	Float64 mSourceSampleRate;
	
	UInt64 mInputStart;
	double mInputRate;

	UInt64 mOutputStart;
	double mOutputRate;
	
	UInt32 mInputIsBusy;
	UInt32 mOutputIsBusy;
	
	UInt32 mMaxFrameCount;
	RMSRingBuffer mRingBuffer;
}
@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSInput
////////////////////////////////////////////////////////////////////////////////

//#define RMSInputDeviceReports

#ifdef RMSInputDeviceReports

static inline OSStatus RMSInputDeviceUpdateInputRate(__unsafe_unretained RMSInput *rmsObject)
{
	// Update timing and rate
	if (rmsObject->mInputIndex == 0)
	{ rmsObject->mInputStart = mach_absolute_time(); }
	else
	{
		double time = (1.0e-9)*(mach_absolute_time() - rmsObject->mInputStart);
		rmsObject->mInputRate = rmsObject->mInputIndex/time;

		static double lastTime = 0.0;
		if (lastTime <= time-1.0)
		{
			lastTime = time;
			NSLog(@"inputrate = %lf", rmsObject->mInputRate);
		}
	}
	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

static inline OSStatus RMSInputDeviceUpdateOutputRate(__unsafe_unretained RMSInput *rmsObject)
{
	// Update timing and rate
	if (rmsObject->mOutputIndex == 0)
	{ rmsObject->mOutputStart = mach_absolute_time(); }
	else
	{
		double time = (1.0e-9)*(mach_absolute_time() - rmsObject->mOutputStart);
		rmsObject->mOutputRate = rmsObject->mOutputIndex/time;

		static double lastTime = 0.0;
		if (lastTime <= time-1.0)
		{
			lastTime = time;
			NSLog(@"outputrate = %lf", rmsObject->mOutputRate);
		}
	}
	
	return noErr;
}

#endif // RMSInputDeviceReports
////////////////////////////////////////////////////////////////////////////////

static OSStatus inputCallback(
	void *							refCon,
	AudioUnitRenderActionFlags *	actionFlagsPtr,
	const AudioTimeStamp *			timeStampPtr,
	UInt32							busNumber,
	UInt32							frameCount,
	AudioBufferList * __nullable	bufferListPtr)
{
	__unsafe_unretained RMSInput *rmsObject =
	(__bridge __unsafe_unretained RMSInput *)refCon;
	
	// This should raise an exception
	UInt32 maxFrameCount = rmsObject->mMaxFrameCount;
	if (frameCount > maxFrameCount)
	{
		NSLog(@"Input frameCount (%d) > kBufferSize (%d)", frameCount, maxFrameCount);
		return paramErr;
	}
	
#ifdef RMSInputDeviceReports
	RMSInputDeviceUpdateInputRate(rmsObject);
#endif

	double time = RMSCurrentHostTimeInSeconds();

	if (rmsObject->mSampleCount == 0)
	{
		rmsObject->mStartTime = RMSCurrentHostTimeInSeconds();
	}
	else
	{
		rmsObject->mNominalSampleRate =
		rmsObject->mSampleCount / (time - rmsObject->mStartTime);
	}

	rmsObject->mSampleCount += frameCount;

	
	rmsObject->mInputIsBusy = 1;

		// bufferListPtr is nil, use AudioUnitRender to render directly to ring buffer
		RMSAudioBufferList stereoBuffer =
		RMSRingBufferGetWriteBufferList(&rmsObject->mRingBuffer);

		OSStatus result = AudioUnitRender(rmsObject->mAudioUnit, \
		actionFlagsPtr, timeStampPtr, busNumber, frameCount, &stereoBuffer.list);

		RMSRingBufferMoveWriteIndex(&rmsObject->mRingBuffer, frameCount);
	
	rmsObject->mInputIsBusy = 0;


	return result;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus outputCallback(void *rmsSource, const RMSCallbackInfo *infoPtr)
{
	__unsafe_unretained RMSInput *rmsObject =
	(__bridge __unsafe_unretained RMSInput *)rmsSource;
	
	// This should raise an exception
	UInt32 frameCount = infoPtr->frameCount;
	UInt32 maxFrameCount = rmsObject->mMaxFrameCount;
	if (frameCount > maxFrameCount)
	{
		/*
			If the inputscope-samplerate of the audioengine output audiounit
			does not match the device-samplerate, this may happen.
		*/
		NSLog(@"Output frameCount (%d) > kBufferSize (%d)", frameCount, maxFrameCount);
		return paramErr;
	}

#ifdef RMSInputDeviceReports
	RMSInputDeviceUpdateOutputRate(rmsObject);
#endif
	
	RMSRingBufferReadStereoData
	(&rmsObject->mRingBuffer, infoPtr->bufferListPtr, frameCount);

	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

+ (AURenderCallback) inputCallback
{ return inputCallback; }

////////////////////////////////////////////////////////////////////////////////

+ (RMSCallbackProcPtr) callbackPtr
{ return outputCallback; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
/*
	voiceProcessing exists on OSX but doesn't allow our initialization, 
	
	TODO: create and test iOS version
*/
/*
+ (instancetype) voiceProcessingInput
{ return [[self alloc] initWithVoiceProcessingIO]; }

- (instancetype) initWithVoiceProcessingIO
{
	self = [super initWithDescription:(AudioComponentDescription) {
		.componentType = kAudioUnitType_Output,
		.componentSubType = kAudioUnitSubType_VoiceProcessingIO,
		.componentManufacturer = kAudioUnitManufacturer_Apple,
		.componentFlags = 0,
		.componentFlagsMask = 0 }];
	if (self != nil)
	{
		OSStatus result = noErr;
		
		
		
		
		result = [self attachInputCallback];
		if (result != noErr) return nil;
	}
	
	return self;
}
*/
////////////////////////////////////////////////////////////////////////////////

+ (NSArray *) availableCaptureDevices
{
	//AVCaptureDeviceWasConnectedNotification
	return [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
}

////////////////////////////////////////////////////////////////////////////////

+ (AVCaptureDevice *) captureDeviceWithName:(NSString *)name
{
	NSArray *devices = [self availableCaptureDevices];
	for (id device in devices)
	{
		if ([[device localizedName] isEqualToString:name])
		{
			return device;
		}
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////

+ (NSArray *) availableDevices
{
	NSMutableArray *devices = [NSMutableArray array];
	
	NSArray *captureDevices = [self availableCaptureDevices];
	for (id device in captureDevices)
	{ [devices addObject:[device localizedName]]; }
	
	return devices;
}

////////////////////////////////////////////////////////////////////////////////

+ (instancetype) instanceWithDevice:(RMSDevice *)device
{ return [self instanceWithDevice:device error:nil]; }

+ (instancetype) instanceWithDevice:(RMSDevice *)device error:(NSError **)errorPtr
{ return [[self alloc] initWithDevice:device error:errorPtr]; }

////////////////////////////////////////////////////////////////////////////////

+ (instancetype) defaultInput
{
#if TARGET_OS_IPHONE
	return nil;
#else

	AudioDeviceID deviceID = 0;
	OSStatus result = RMSAudioGetDefaultInputDeviceID(&deviceID);
	if (result != noErr) return nil;
	
	
	return [[self alloc] initWithDeviceID:deviceID];

#endif
}

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{ return [self initWithDevice:nil]; }

- (instancetype) initWithDevice:(RMSDevice *)device
{ return [self initWithDevice:device error:nil]; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) initWithDevice:(RMSDevice *)device error:(NSError **)errorPtr
{
	if (errorPtr != nil)
	{ *errorPtr = nil; }
	
	self = [super init];
	if (self != nil)
	{
		self.defaultBusIndex = 1;

		OSStatus result = noErr;
				
		result = [self prepareAudioUnit];
		if (result != noErr) return nil;

		result = [self attachDevice:device];
		if (result != noErr) return nil;

		result = [self initializeSampleRates];
		if (result != noErr) return nil;
		
		result = [self prepareBuffers];
		if (result != noErr) return nil;
		
		[self startRunning];
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) attachDevice:(RMSDevice *)device
{
	OSStatus result = noErr;

#if TARGET_OS_IPHONE

#else
	
	// Attach device on inputside of inputstream
	result = AudioUnitAttachDevice(mAudioUnit, deviceID);
	if (result != noErr) return result;
	
#endif
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	[self stopRunning];
	RMSRingBufferRelease(&mRingBuffer);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (OSStatus) getSourceFormat:(AudioStreamBasicDescription *)streamInfoPtr
{
	OSStatus result = RMSAudioUnitGetInputScopeFormatAtIndex(mAudioUnit, 1, streamInfoPtr);
	if (result != noErr)
	{ NSLog(@"RMSInput: RMSAudioUnitGetInputScopeFormatAtIndex returned %d", result); }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) getSourceFormat:(AudioStreamBasicDescription *)streamInfoPtr atIndex:(UInt32)index
{ return RMSAudioUnitGetInputScopeFormatAtIndex(mAudioUnit, index, streamInfoPtr); }

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) setSourceFormat:(const AudioStreamBasicDescription *)streamInfoPtr
{
	OSStatus result = RMSAudioUnitSetInputScopeFormatAtIndex(mAudioUnit, 1, streamInfoPtr);
	if (result != noErr)
	{ NSLog(@"RMSInput: RMSAudioUnitSetInputScopeFormatAtIndex returned %d", result); }

	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) getResultFormat:(AudioStreamBasicDescription *)streamInfoPtr
{
	OSStatus result = RMSAudioUnitGetOutputScopeFormatAtIndex(mAudioUnit, 1, streamInfoPtr);
	if (result != noErr)
	{ NSLog(@"RMSInput: RMSAudioUnitGetOutputScopeFormatAtIndex returned %d", result); }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) setResultFormat:(const AudioStreamBasicDescription *)streamInfoPtr
{
	OSStatus result = RMSAudioUnitSetOutputScopeFormatAtIndex(mAudioUnit, 1, streamInfoPtr);
	if (result != noErr)
	{ NSLog(@"RMSInput: RMSAudioUnitSetOutputScopeFormatAtIndex returned %d", result); }

	return result;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (OSStatus) prepareAudioUnit
{
	OSStatus result = noErr;

	// Enable input stream
	result = [self enableInput:true];
	if (result != noErr) return result;
	
	// Disable output stream
	result = [self enableOutput:false];
	if (result != noErr) return result;

	// Attach callback for outputside of inputstream
	result = [self attachInputCallback];
	if (result != noErr) return result;
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) attachInputCallback
{
	// Attach callback for outputside of inputstream 
	return AudioUnitSetInputCallback \
	(mAudioUnit, [[self class] inputCallback], (__bridge void *)self);
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) initializeSampleRates
{
	OSStatus result = noErr;
	
#if TARGET_OS_IPHONE

	mSourceSampleRate = [[AVAudioSession sharedInstance] sampleRate];

#else

	AudioStreamBasicDescription sourceFormat;
	result = [self getSourceFormat:&sourceFormat];
	mSourceSampleRate = sourceFormat.mSampleRate;

#endif
	
	if (mSourceSampleRate == 0)
	{ mSourceSampleRate = 44100.0; }

	// Initialize sampleRate
	mSampleRate = mSourceSampleRate;

	// Set resultFormat accordingly
	AudioStreamBasicDescription streamFormat = RMSPreferredAudioFormat;
	streamFormat.mSampleRate = mSampleRate;
	result = [self setResultFormat:&streamFormat];

//	result = [self getResultFormat:&streamFormat];

	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) prepareBuffers
{
	UInt32 frameCount = 512;
	OSStatus result = RMSAudioUnitGetMaximumFramesPerSlice(mAudioUnit, &frameCount);

	if (result != noErr)
	{ NSLog(@"AudioUnitGetMaximumFramesPerSlice error: %d", result); }
		
	UInt32 maxFrameCount = 2;
	while (maxFrameCount < frameCount)
	{ maxFrameCount <<= 1; }
	
	frameCount = maxFrameCount;
	
	
	if (frameCount == 0)
	{ frameCount = 512; }
	
	
	return [self prepareBuffersWithMaxFrameCount:frameCount];
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) prepareBuffersWithMaxFrameCount:(UInt32)frameCount
{
	mMaxFrameCount = frameCount;
	mRingBuffer = RMSRingBufferNew(8*frameCount);

	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

- (void) setSampleRate:(Float64)sampleRate
{
	if (mSampleRate != sampleRate)
	{
		[self stopRunning];
		
		/*
			On OSX the audiounit samplerates for an inputdevice should match
			on both scopes, so we can not use super->setSampleRate, but should
			use RMSSource->setSampleRate instead
		*/
		mSampleRate = sampleRate;
		[mFilter setSampleRate:sampleRate];
		[mMonitor setSampleRate:sampleRate];
		
		[self updateRingBufferSpeed];
		RMSRingBufferClear(&mRingBuffer);
		
		[self startRunning];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateRingBufferSpeed
{
	Float64 sourceRate = mSourceSampleRate;
	Float64 outputRate = [self sampleRate];
	
	double rate = (sourceRate != 0.0)&&(outputRate != 0.0) ?
	sourceRate / outputRate : 1.0;
	
	RMSRingBufferSetReadRate(&mRingBuffer, rate);
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////













