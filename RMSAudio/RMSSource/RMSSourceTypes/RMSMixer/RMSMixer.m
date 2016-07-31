////////////////////////////////////////////////////////////////////////////////
/*
	RMSMixer
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSMixer.h"
#import "RMSUtilities.h"
#import "RMSAudio.h"


@interface RMSMixer ()
{
	RMSStereoBufferList mStereoBuffer;
	float *mSampleDataL;
	float *mSampleDataR;
}

@property NSMutableArray *sourceObjects;

@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSMixer
////////////////////////////////////////////////////////////////////////////////

static OSStatus renderCallback(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSMixer *rmsMixer = \
	(__bridge __unsafe_unretained RMSMixer *)rmsObject;


	void *link = RMSLinkGetLink(rmsObject);
	
	while (link != nil)
	{
		// get local copy of callbackInfo
		RMSCallbackInfo localInfo = *infoPtr;

		// get local copy of stereoBufferList
		RMSStereoBufferList stereoBuffers = rmsMixer->mStereoBuffer;
		
		// reset bufferListPtr
		localInfo.bufferListPtr = &stereoBuffers.list;
		
		result = RunRMSSource(link, &localInfo);
		if (result == noErr)
		{
			// add localInfo->bufferListPtr to infoPtr->bufferListPtr
			RMSAudioBufferList_AddFrames
			(localInfo.bufferListPtr, infoPtr->bufferListPtr, infoPtr->frameCount);
		}
		
		link = RMSLinkGetLink(link);
	}

	return result;
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackProcPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////

- (void) addSource:(RMSSource *)source
{
	RMSLink *mixerSource = [RMSLink new];
	mixerSource.source = source;
	mixerSource.filter = [RMSVolume new];
	mixerSource.monitor = [RMSSampleMonitor new];

	[mixerSource setShouldUpdateSource:YES];
	[mixerSource setSampleRate:self.sampleRate];
	
	// for the audio thread
	[self addLink:mixerSource];

	// for the management thread
	[self.sourceObjects addObject:mixerSource];

/*
	Note that if the attached sampleMonitor is updated from
	a separate thread, we can't rely on the audio trash 
	to offer the correct protection. We can however rely on 
	normal ARC behavior and locks by using an extra array.
*/
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeSource:(RMSSource *)source
{
	
}

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{
	self = [super init];
	if (self != nil)
	{
		self.sourceObjects = [NSMutableArray new];
		
		mSampleDataL = calloc(512, sizeof(float));
		mSampleDataR = calloc(512, sizeof(float));
		
		mStereoBuffer.bufferCount = 2;
		mStereoBuffer.buffer[0].mNumberChannels = 1;
		mStereoBuffer.buffer[0].mDataByteSize = 512*sizeof(float);
		mStereoBuffer.buffer[0].mData = mSampleDataL;
		mStereoBuffer.buffer[1].mNumberChannels = 1;
		mStereoBuffer.buffer[1].mDataByteSize = 512*sizeof(float);
		mStereoBuffer.buffer[1].mData = mSampleDataR;
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	self.sourceObjects = nil;
	
	if (mSampleDataL != nil)
	{
		free(mSampleDataL);
		mSampleDataL = nil;
	}

	if (mSampleDataR != nil)
	{
		free(mSampleDataR);
		mSampleDataR = nil;
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateLevels
{
/*
	RMSLink *link = self.link;
	
	while (link != nil)
	{
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
		^{
			RMSSampleMonitor *monitor = (RMSSampleMonitor *)[link monitor];
			[monitor updateLevels];
		});

		link = link.link;
	}
*/
/*
	[self.sourceObjects enumerateObjectsWithOptions:NSEnumerationConcurrent
	usingBlock:^(id mixerSource, NSUInteger index, BOOL *stop)
	{
		RMSSampleMonitor *monitor = (RMSSampleMonitor *)[mixerSource monitor];
		[monitor updateLevels];
	}];
*/
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





