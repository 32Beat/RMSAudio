////////////////////////////////////////////////////////////////////////////////
/*
	RMSSampleMonitor
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSSampleMonitor.h"
#import "RMSTimer.h"
#import "rmsbuffer.h"
#import <Accelerate/Accelerate.h>


@interface RMSSampleMonitor () <RMSTimerProtocol>
{
	size_t mSampleCount;
	rmsbuffer_t mBuffer[2];
}

@property (nonatomic, assign) BOOL pendingUpdate;

@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSSampleMonitor
////////////////////////////////////////////////////////////////////////////////

static OSStatus renderCallback(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	__unsafe_unretained RMSSampleMonitor *rmsSource = \
	(__bridge __unsafe_unretained RMSSampleMonitor *)rmsObject;
	
	float *srcPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	RMSBufferWriteSamples(&rmsSource->mBuffer[0], srcPtrL, infoPtr->frameCount);

	float *srcPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	RMSBufferWriteSamples(&rmsSource->mBuffer[1], srcPtrR, infoPtr->frameCount);
	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////

+ (instancetype) instanceWithCount:(size_t)size
{ return [[self alloc] initWithCount:size]; }

- (instancetype) init
{ return [self initWithCount:1024]; }

- (instancetype) initWithCount:(size_t)sampleCount
{
	self = [super init];
	if (self != nil)
	{
		sampleCount = 1<<(int)ceil(log2(sampleCount));
		
		mSampleCount = sampleCount;
		mBuffer[0] = RMSBufferBegin(sampleCount);
		mBuffer[1] = RMSBufferBegin(sampleCount);
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	RMSBufferEnd(&mBuffer[0]);
	RMSBufferEnd(&mBuffer[1]);
}

////////////////////////////////////////////////////////////////////////////////

- (size_t) length
{
	return mSampleCount;
}

////////////////////////////////////////////////////////////////////////////////

- (uint64_t) minIndex
{
	uint64_t indexL = mBuffer[0].index;
	uint64_t indexR = mBuffer[1].index;
	uint64_t index = indexL < indexR ? indexL : indexR;

	return index;
}

////////////////////////////////////////////////////////////////////////////////

- (rmsrange_t) availableRange
{
	uint64_t minIndex = self.minIndex;
	uint64_t maxCount = self.length >> 1;
	
	if (maxCount > minIndex)
	{ maxCount = minIndex; }
	
	return (rmsrange_t){ minIndex-maxCount, maxCount };
}

////////////////////////////////////////////////////////////////////////////////

- (rmsrange_t) availableRangeWithIndex:(uint64_t)index
{
	rmsrange_t R = self.availableRange;
	
	if (index <= R.index)
	{ return R; }
	
	R.count += R.index;
	R.count -= index <= R.count ? index : R.count;
	R.index = index;
	
	return R;
}

////////////////////////////////////////////////////////////////////////////////

- (rmsbuffer_t *) bufferAtIndex:(NSUInteger)n
{ return n < 2 ? &mBuffer[n] : nil; }

////////////////////////////////////////////////////////////////////////////////

- (void) reset
{
	RMSBufferReset(&mBuffer[0]);
	RMSBufferReset(&mBuffer[1]);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
// TODO: move to more proper location
static void RMSLevelsScanBuffer
(rmslevels_t *levels, const rmsbuffer_t *buffer, const rmsrange_t *R)
{
	float *srcPtr = buffer->sampleData;
	
	uint64_t indexMask = buffer->indexMask;
	size_t index = R->index & indexMask;
	size_t count = R->count;
	
	size_t N = indexMask + 1 - index;
	
	if (count <= N)
	{
		RMSLevelsScanSamples(levels, &srcPtr[index], count);
	}
	else
	{
		RMSLevelsScanSamples(levels, &srcPtr[index], N);
		RMSLevelsScanSamples(levels, &srcPtr[0], count-N);
	}
/*
	for (uint64_t N=R->count; N!=0; N--)
	{
		Float32 S = srcPtr[index&indexMask];
		RMSLevelsScanSample(levels, S);
		
		index++;
	}
*/
}


- (void) updateLevels:(RMSStereoLevels *)levels
{
	// (re)initialize levels if samplerate changed
	Float64 sampleRate = self.sampleRate;
	if (levels->sampleRate != sampleRate)
	{
		levels->L = RMSLevelsInit(sampleRate);
		levels->R = RMSLevelsInit(sampleRate);
		levels->sampleRate = sampleRate;
	}

	// get available range
	rmsrange_t R = [self availableRange];

	// make sure the ringbuffer has valid data available
	if (R.count == 0) return;

	/*
		levels->index represents the number of samples processed since the 
		last update call, availableRange represents the current slice
		in the ringbuffers available for reading.
		
		So we want to process from levels->index to the end of range.
		Typically the available slice will be larger than the required slice 
		which simply means we want to adjust the tail of range accordingly.
		
		If however levels->index falls outside the available range, 
		we most likely need to reset our destination and process the entire
		available range.
	*/
	
	// adjust range to exclude previous run
	if ((R.index <= levels->index)&&(levels->index < R.index+R.count))
	{
		R.count += R.index;
		R.index = levels->index;
		R.count -= R.index;
	}

	/* 
		note that if levels->index falls outside range,
		then the entire range will be processed and
		levels->index will be reset
		
		TODO: possibly reset entire levels struct?
	*/

	rmsbuffer_t *bufferL = [self bufferAtIndex:0];
	RMSLevelsScanBuffer(&levels->L, bufferL, &R);

	rmsbuffer_t *bufferR = [self bufferAtIndex:1];
	RMSLevelsScanBuffer(&levels->R, bufferR, &R);
	
	levels->index = R.index + R.count;
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////



