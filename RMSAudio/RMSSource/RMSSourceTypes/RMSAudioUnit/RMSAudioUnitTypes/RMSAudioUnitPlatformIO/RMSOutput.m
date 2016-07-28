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
	
	double maxTime;
	double avgTime;
	double avgCount;

	bool reset;
}
RMSTimingInfo;


@interface RMSOutput ()
{
	RMSTimingInfo mTimingInfo;
	
	BOOL mStateChangePending;
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
		
		double renderTime = infoPtr->finishTime - infoPtr->startTime;
		
		if (infoPtr->reset)
		{
			infoPtr->maxTime = renderTime;
			infoPtr->avgTime = renderTime;
			infoPtr->avgCount = 1.0;
			infoPtr->reset = 0;
		}
		
		// Compute maximum time since last report
		if (infoPtr->maxTime < renderTime)
		{ infoPtr->maxTime = renderTime; }

		// Compute average time
		infoPtr->avgCount += 1;
		infoPtr->avgTime += (renderTime - infoPtr->avgTime) / infoPtr->avgCount;
	}
	
	return noErr;
}

#endif

- (NSTimeInterval) averageRenderTime
{ return RMSHostTimeToSeconds(mTimingInfo.avgTime); }

- (NSTimeInterval) maximumRenderTime;
{ return RMSHostTimeToSeconds(mTimingInfo.maxTime); }

- (void) resetTimingInfo
{
	if (mTimingInfo.reset == NO)
	{ mTimingInfo.reset = YES; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) didChangeState:(UInt32)state
{
	if (mStateChangePending == NO)
	{
		mStateChangePending = YES;
		dispatch_async(dispatch_get_main_queue(),
		^{
			[self.delegate audioOutput:self didChangeState:0];
			mStateChangePending = NO;
		});
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
/*
	outputCallback
	--------------
	Render callback for the AudioUnit 
	
	This merely translates the parameterlist of an AURenderCallback 
	to the internal CallbackInfo struct which is used by the RMS code. 
	It then calls RunRMSSource on self, which runs the renderCallback below
	and possible attachments like filters and monitors.
	
	The actual renderCallback for this RMSSource overwrites the default 
	callback for an RMSAudioUnit which would call AudioUnitRender again, 
	creating an infinite loop.
*/
static OSStatus outputCallback(
	void *							refCon,
	AudioUnitRenderActionFlags *	actionFlagsPtr,
	const AudioTimeStamp *			timeStampPtr,
	UInt32							busNumber,
	UInt32							frameCount,
	AudioBufferList * __nullable	bufferListPtr)
{
	RMSCallbackInfo info;
	info.frameIndex = timeStampPtr->mSampleTime;
	info.frameCount = frameCount;
	info.bufferListPtr = bufferListPtr;
	
	OSStatus result = RunRMSSource(refCon, &info);
	
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
	RMSAudioBufferList_ClearFrames(infoPtr->bufferListPtr, infoPtr->frameCount);

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
			
			The change can be communicated using GCD & obj-C, since we
			are already producing a violent interruption and abrupt silence.
		*/
		[rmsOutput didChangeState:0];
		return paramErr;
	}
	
	if (rmsOutput->mSource != nil)
	{
		result = RunRMSSource((__bridge void *)rmsOutput->mSource, infoPtr);
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

+ (RMSCallbackProcPtr) callbackProcPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

+ (instancetype) defaultOutput
{ return [[self alloc] init]; }

- (instancetype) init
{ return [self initWithDevice:nil]; }

////////////////////////////////////////////////////////////////////////////////

+ (instancetype) instanceWithDevice:(RMSDevice *)device
{ return [[self alloc] initWithDevice:device]; }

- (instancetype) initWithDevice:(RMSDevice *)device
{
	self = [super init];
	if (self != nil)
	{
		OSStatus result = noErr;
		
		result = [self prepareCallbacks];
		if (result != noErr) return nil;

		result = [self attachDevice:device];
		if (result != noErr) return nil;

		result = [self initializeSampleRates];
		if (result != noErr) return nil;
		
		result = [self prepareBuffers];
		if (result != noErr) return nil;
		
		// don't start automagically, controller should trigger this
		//[self startRunning];
	}
	
	return self;
}

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
	NSLog(@"Format Changed: scope: %u, bus %u", (UInt32)inScope, (UInt32)inElement);
}

- (void) prepareMessaging
{
	AudioUnitAddPropertyListener(self->mAudioUnit,
	kAudioUnitProperty_StreamFormat, FormatChanged, (__bridge void *)self);
//	kAudioUnitProperty_SampleRate, SampleRateChanged, (__bridge void *)self);
}




- (OSStatus) prepareCallbacks
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

- (OSStatus) attachDevice:(RMSDevice *)device
{
	OSStatus result = noErr;

#if TARGET_OS_IPHONE

#else
	if (device != nil)
	{
		result = AudioUnitAttachDevice(mAudioUnit, device.deviceID);
		if (result != noErr) return result;
	}
#endif

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
	OSStatus result = noErr;
//	result = RMSAudioUnitSetMaximumFramesPerSlice(mAudioUnit, 512);
	return result;
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
	[self setInputSampleRate:sampleRate];
}

////////////////////////////////////////////////////////////////////////////////

- (void) setInputSampleRate:(Float64)sampleRate
{
	Float64 srcRate = [self inputScopeSampleRate];
	if (srcRate != sampleRate)
	{
		[mSource setSampleRate:sampleRate];
		[super setInputSampleRate:sampleRate];
	}
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





