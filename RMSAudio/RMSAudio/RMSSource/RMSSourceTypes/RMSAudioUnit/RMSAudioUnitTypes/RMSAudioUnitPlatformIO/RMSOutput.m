////////////////////////////////////////////////////////////////////////////////
/*
	RMSOutput
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSOutput.h"
#import "RMSAudio.h"

#import <AVFoundation/AVFoundation.h>
#import <mach/mach_time.h>



/* 
	Following is used in Debugmode only
	(which generally means non-optimized code btw)
*/
typedef struct RMSTimingInfo
{
	UInt64 startTime;
	UInt64 finishTime;
	
	double avgTime;
	double maxTime;

	bool reset;
}
RMSTimingInfo;


@interface RMSOutput ()
{
	RMSTimingInfo mTimingInfo;
	RMSCallbackInfo mCallbackInfo;
}
@end

////////////////////////////////////////////////////////////////////////////////
@implementation RMSOutput
////////////////////////////////////////////////////////////////////////////////

#define RMS_REPORT_TIME 2

#if RMS_REPORT_TIME

static OSStatus notifyCallback(
	void *							inRefCon,
	AudioUnitRenderActionFlags *	ioActionFlags,
	const AudioTimeStamp *			inTimeStamp,
	UInt32							inBusNumber,
	UInt32							inNumberFrames,
	AudioBufferList * __nullable	ioData)
{
	RMSTimingInfo *infoPtr = (RMSTimingInfo *)inRefCon;
	
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender)
	{
		infoPtr->startTime = mach_absolute_time();
	}
	else
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender)
	{
		infoPtr->finishTime = mach_absolute_time();
		
		double renderTime =
		RMSHostTimeToSeconds(infoPtr->finishTime - infoPtr->startTime);
		
		if (infoPtr->reset)
		{
			infoPtr->avgTime = renderTime;
			infoPtr->maxTime = renderTime;
			infoPtr->reset = 0;
		}
		
		// Compute short term average time
		infoPtr->avgTime += 0.1 * (renderTime - infoPtr->avgTime);
		
		// Compute maximum time since last report
		if (infoPtr->maxTime < renderTime)
		{ infoPtr->maxTime = renderTime; }
	}
	
	return noErr;
}

#endif

- (NSTimeInterval) averageRenderTime
{ return mTimingInfo.avgTime; }

- (NSTimeInterval) maximumRenderTime;
{ return mTimingInfo.maxTime; }

- (void) resetTimingInfo
{
	if (mTimingInfo.reset == NO)
	{ mTimingInfo.reset = YES; }
}

////////////////////////////////////////////////////////////////////////////////
/*
	outputCallback
	--------------
	Render callback for the AudioUnit 
	
	This merely translates the parameterlist of an AURenderCallback 
	to the internal CallbackInfo struct which is used by the RMS code. 
	It then calls RunRMSSource on self, which runs the renderCallback below
	and possible attachments like filters and monitors.
*/
static OSStatus outputCallback(
	void *							refCon,
	AudioUnitRenderActionFlags *	actionFlagsPtr,
	const AudioTimeStamp *			timeStampPtr,
	UInt32							busNumber,
	UInt32							frameCount,
	AudioBufferList * __nullable	bufferListPtr)
{
	// get the RMSSource object
	__unsafe_unretained RMSOutput *rmsObject =
	(__bridge __unsafe_unretained RMSOutput *)refCon;

	RMSCallbackInfo *infoPtr = &rmsObject->mCallbackInfo;
	
	infoPtr->frameCount = frameCount;
	infoPtr->bufferListPtr = bufferListPtr;
	
	OSStatus result = RunRMSSource(refCon, infoPtr);
	
	infoPtr->sliceIndex += 1;
	infoPtr->frameIndex += frameCount;
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
/*
	renderCallback
	--------------
	Render callback for this RMS object
	
	The outputCallback has translated the parameterlist to RMSCallbackInfo, 
	and the renderCallback is now being called from RunRMSSource right before
	the filters and monitors will be called. 
	
	Generally, RMSOutput is the root of a rendertree attached to mSource. 
	We therefore need to call RunRMSSource on mSource which should render 
	something into the bufferList
*/

static OSStatus renderCallback(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	// initialize return value
	OSStatus result = noErr;

	// silence outputbuffers
	AudioBufferList_ClearFrames(infoPtr->bufferListPtr, infoPtr->frameCount);

	// get the RMSSource object
	__unsafe_unretained RMSOutput *rmsOutput =
	(__bridge __unsafe_unretained RMSOutput *)rmsObject;

	// test RMSOutput samplerate against AudioUnit samplerate
	Float64 sampleRate = 0.0;
	result = RMSAudioUnitGetOutputScopeSampleRateAtIndex(rmsOutput->mAudioUnit, 0, &sampleRate);
	if ((sampleRate != 0.0) && (sampleRate != rmsOutput->mSampleRate))
	{
		/*
			A device samplerate change is typically destructive, 
			produce silence + error until the management thread 
			has had a chance to incorporate the change.
		*/
		return paramErr;
	}
	
	if (rmsOutput->mSource != nil)
	{
		result = RunRMSSource((__bridge void *)rmsOutput->mSource, infoPtr);
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

+ (RMSCallbackProcPtr) callbackPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////

#if !TARGET_OS_IPHONE

+ (instancetype) defaultOutput
{
	return [[self alloc] initWithDeviceID:0];
}

////////////////////////////////////////////////////////////////////////////////

- (instancetype) initWithDeviceID:(AudioDeviceID)deviceID
{
	self = [super init];
	if (self != nil)
	{
		OSStatus result = noErr;
		
		result = [self prepareAudioUnit];
		if (result != noErr) return nil;

		result = [self attachDevice:deviceID];
		if (result != noErr) return nil;

		result = [self initializeSampleRates];
		if (result != noErr) return nil;
		
		result = [self prepareBuffers];
		if (result != noErr) return nil;
		
		[self startRunning];
	}
	
	return self;
}


- (OSStatus) attachDevice:(AudioDeviceID)deviceID
{
	OSStatus result = noErr;
	
	if (deviceID != 0)
	{
		result = AudioUnitAttachDevice(mAudioUnit, deviceID);
		if (result != noErr) return result;
	}
	
	return result;
}

#endif

////////////////////////////////////////////////////////////////////////////////

#if TARGET_OS_IPHONE

+ (instancetype) defaultOutput
{
	return [[self alloc] init];
}

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{
	self = [super init];
	if (self != nil)
	{
		OSStatus result = noErr;
		
		result = [self prepareAudioUnit];
		if (result != noErr) return nil;

		result = [self initializeSampleRates];
		if (result != noErr) return nil;
		
		result = [self prepareBuffers];
		if (result != noErr) return nil;
		
		[self startRunning];
	}
	
	return self;
}

#endif

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	[self stopRunning];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////


static void FormatChanged(
void *inRefCon,
AudioUnit inUnit,
AudioUnitPropertyID	inID,
AudioUnitScope		inScope,
AudioUnitElement	inElement)
{
	NSLog(@"Format Changed: scope: %d, bus %d", inScope, inElement);
}

- (void) prepareMessaging
{
	AudioUnitAddPropertyListener(self->mAudioUnit,
	kAudioUnitProperty_StreamFormat, FormatChanged, (__bridge void *)self);
//	kAudioUnitProperty_SampleRate, SampleRateChanged, (__bridge void *)self);
}




- (OSStatus) prepareAudioUnit
{
#if RMS_REPORT_TIME
	AudioUnitAddRenderNotify(mAudioUnit, notifyCallback, &mTimingInfo);
#endif

//	[self prepareMessaging];

	OSStatus result = noErr;

	result = AudioUnitSetRenderCallback(mAudioUnit, outputCallback, (__bridge void *)self);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) initializeSampleRates
{
	OSStatus result = noErr;

	// Get outputScope format
	AudioStreamBasicDescription resultFormat;
	[self getResultFormat:&resultFormat];

	mSampleRate = resultFormat.mSampleRate;
	
	// Set inputScope to our preferred format with the outputScope sampleRate
	AudioStreamBasicDescription streamFormat = RMSPreferredAudioFormat;
	streamFormat.mSampleRate = resultFormat.mSampleRate;
	[self setSourceFormat:&streamFormat];
	
#if TARGET_OS_IPHONE

	// On iOS the audiounit sampleRate will be 0 on both scopes,
	// need to copy it from the AVAudioSession
	mSampleRate = [[AVAudioSession sharedInstance] sampleRate];

#endif
	
	// Set most reasonable guestimate, if necessary
	if (mSampleRate == 0)
	{ mSampleRate = 44100.0; }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) prepareBuffers
{
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) prepareBuffersWithMaxFrameCount:(UInt32)frameCount
{
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////
/*
	Samplerate is only propagated to filters and monitors, as these operate on 
	output samples, while a source might specifically need to produce samples 
	at a different rate, like in the Varispeed case.
	For correct reproduction however, the output unit needs to receive correctly 
	rated samples directly from its source.
*/

- (void) setSource:(RMSSource *)source
{
	[source setSampleRate:self.sampleRate];
	[super setSource:source];
}

////////////////////////////////////////////////////////////////////////////////

- (void) setSampleRate:(Float64)sampleRate
{
	[mSource setSampleRate:sampleRate];
	[super setSampleRate:sampleRate];
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





