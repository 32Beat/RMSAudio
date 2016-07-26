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
	size_t mCount;
	rmsbuffer_t mBufferL;
	rmsbuffer_t mBufferR;

	
	NSMutableArray *mObservers;
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
	RMSBufferWriteSamples(&rmsSource->mBufferL, srcPtrL, infoPtr->frameCount);

	float *srcPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	RMSBufferWriteSamples(&rmsSource->mBufferR, srcPtrR, infoPtr->frameCount);
	
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
		
		mCount = sampleCount;
		mBufferL = RMSBufferBegin(sampleCount);
		mBufferR = RMSBufferBegin(sampleCount);
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	RMSBufferEnd(&mBufferL);
	RMSBufferEnd(&mBufferR);
}

////////////////////////////////////////////////////////////////////////////////

- (size_t) length
{
	return mCount;
}

////////////////////////////////////////////////////////////////////////////////

- (uint64_t) maxIndex
{
	uint64_t indexL = mBufferL.index;
	uint64_t indexR = mBufferR.index;
	uint64_t index = indexL < indexR ? indexL : indexR;
	
	// index points to next open slot
	return index - (index!=0);
}

////////////////////////////////////////////////////////////////////////////////

- (rmsrange_t) availableRange
{
	uint64_t maxIndex = self.maxIndex;
	uint64_t maxCount = self.length >> 1;
	
	return (rmsrange_t){ maxIndex+1-maxCount, maxCount };
}

////////////////////////////////////////////////////////////////////////////////

- (rmsrange_t) availableRangeWithIndex:(uint64_t)index
{
	uint64_t maxIndex = self.maxIndex;
	
	if (index == 0 || index > maxIndex)
	{ index = maxIndex; }
	
	uint64_t count = maxIndex + 1 - index;
	uint64_t maxCount = self.length >> 1;

	if (count > maxCount)
	{
		index += count;
		index -= maxCount;
		count = maxCount;
	}
	
	return (rmsrange_t){ index, count };
}

////////////////////////////////////////////////////////////////////////////////

- (BOOL) getSamples:(float **)dstPtr count:(size_t)count
{
	uint64_t index = self.maxIndex;

	if (count > mCount)
	{ count = mCount; }
	
	rmsrange_t R = { index - count, count };
	return [self getSamples:dstPtr withRange:R];
}

////////////////////////////////////////////////////////////////////////////////

- (BOOL) getSamples:(float **)dstPtr withRange:(rmsrange_t)R
{
	uint64_t maxIndex = self.maxIndex;
	uint64_t minIndex = maxIndex > mCount ? maxIndex - mCount : 0;
	
	if ((minIndex <= R.index)&&((R.index+R.count) <= maxIndex))
	{
		uint64_t index = R.index;
		uint64_t count = R.count;

		RMSBufferReadSamplesFromIndex(&mBufferL, index, dstPtr[0], count);
		RMSBufferReadSamplesFromIndex(&mBufferR, index, dstPtr[1], count);

		return YES;
	}
	
	return NO;
}

////////////////////////////////////////////////////////////////////////////////

- (void) getSamplesL:(float *)dstPtr withRange:(rmsrange_t)R
{
	uint64_t index = R.index;
	uint64_t count = R.count;
	RMSBufferReadSamplesFromIndex(&mBufferL, index, dstPtr, count);
}

////////////////////////////////////////////////////////////////////////////////

- (void) getSamplesR:(float *)dstPtr withRange:(rmsrange_t)R
{
	uint64_t index = R.index;
	uint64_t count = R.count;
	RMSBufferReadSamplesFromIndex(&mBufferR, index, dstPtr, count);
}

////////////////////////////////////////////////////////////////////////////////

- (rmsbuffer_t *) bufferAtIndex:(int)n
{
	return n ? &mBufferR : &mBufferL;
}

////////////////////////////////////////////////////////////////////////////////

- (void) reset
{
	RMSBufferReset(&mBufferL);
	RMSBufferReset(&mBufferR);
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

	uint64_t maxCount = self.length >> 1;
	uint64_t maxIndex = self.maxIndex;
	if (maxIndex == 0) return;

	
	// reset index if necessary
	if (levels->index > maxIndex)
	{ levels->index = 0; }
	
	// compute range since last update
	rmsrange_t range = { levels->index, maxIndex+1-levels->index };
	if (range.count > maxCount)
	{
		range.index = maxIndex+1 - maxCount;
		range.count = maxCount;
	}

	rmsbuffer_t *L = [self bufferAtIndex:0];
	RMSLevelsScanBuffer(&levels->L, L, &range);

	rmsbuffer_t *R = [self bufferAtIndex:1];
	RMSLevelsScanBuffer(&levels->R, R, &range);
	
	levels->index = maxIndex;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (BOOL) validateObserver:(id<RMSSampleMonitorObserverProtocol>)observer
{
	return observer != nil &&
	[observer respondsToSelector:@selector(updateWithSampleMonitor:)];
}

////////////////////////////////////////////////////////////////////////////////

- (void) addObserver:(id<RMSSampleMonitorObserverProtocol>)observer
{
	if (mObservers == nil)
	{ mObservers = [NSMutableArray new]; }
	
	if ([self validateObserver:observer] &&
	[mObservers indexOfObjectIdenticalTo:observer] == NSNotFound)
	{
		[mObservers addObject:observer];
		
		if (mObservers.count == 1)
		{ [RMSTimer addRMSTimerObserver:self]; }
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeObserver:(id)observer
{
	[mObservers removeObjectIdenticalTo:observer];
	if (mObservers.count == 0)
	{ [RMSTimer removeRMSTimerObserver:self]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) globalRMSTimerDidFire
{ [self updateObservers]; }

- (void) updateObservers
{
/*
	for(id observer in mObservers)
	{
		[observer updateWithSampleMonitor:self];
		if ([self.delegate respondsToSelector:
			@selector(sampleMonitor:didUpdateObserver:)])
		{ [self.delegate sampleMonitor:self didUpdateObserver:observer]; }
	}
/*/
	[mObservers enumerateObjectsWithOptions:NSEnumerationConcurrent
	usingBlock:^(id observer, NSUInteger index, BOOL *stop)
	{
		[observer updateWithSampleMonitor:self];
		if ([self.delegate respondsToSelector:
			@selector(sampleMonitor:didUpdateObserver:)])
		{
			dispatch_async(dispatch_get_main_queue(),
			^{ [self.delegate sampleMonitor:self didUpdateObserver:observer]; });
		}
	}];
//*/
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////



