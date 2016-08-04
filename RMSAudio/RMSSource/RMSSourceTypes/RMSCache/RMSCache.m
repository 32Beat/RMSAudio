////////////////////////////////////////////////////////////////////////////////
/*
	RMSCache
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSCache.h"
#import "RMSUtilities.h"


@interface RMSCache ()
{
	UInt64 mCacheIndex;
	UInt32 mCacheCount;
	UInt32 mCacheSize;
	RMSStereoBufferList mStereoBuffer;
	float *mSampleData[2];
}
@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSCache
////////////////////////////////////////////////////////////////////////////////

static OSStatus RefreshBuffer(void *objectPtr, UInt64 index)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSCache *rmsCache = \
	(__bridge __unsafe_unretained RMSCache *)objectPtr;
	
	UInt32 cacheCount = rmsCache->mCacheSize;
	
	// create RMSCallbackInfo
	RMSCallbackInfo info;
	info.frameIndex = index&(~(cacheCount-1));
	info.frameCount = cacheCount;
	info.bufferListPtr = &rmsCache->mStereoBuffer.list;

	// fetch source samples
	result = RunRMSSourceChain(objectPtr, &info);
	if (result == noErr)
	{
		rmsCache->mCacheIndex = info.frameIndex;
		rmsCache->mCacheCount = info.frameCount;
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSCacheFetch(void *cachePtr, UInt64 index, float *dstPtr)
{
	__unsafe_unretained RMSCache *rmsCache = \
	(__bridge __unsafe_unretained RMSCache *)cachePtr;
	
	UInt64 cacheIndex = rmsCache->mCacheIndex;
	UInt64 cacheCount = rmsCache->mCacheCount;
	
	if (index >= cacheIndex+cacheCount)
	{
		OSStatus error = RefreshBuffer(cachePtr, index);
		if (error != noErr) return error;
		
		cacheIndex = rmsCache->mCacheIndex;
	}
		
	float *srcPtrL = rmsCache->mSampleData[0];
	float *srcPtrR = rmsCache->mSampleData[1];
	dstPtr[0] = srcPtrL[index-cacheIndex];
	dstPtr[1] = srcPtrR[index-cacheIndex];
	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus renderCallback(void *rmsSource, const RMSCallbackInfo *infoPtr)
{
	OSStatus error = noErr;
	
	float *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	float *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	
	UInt64 index = infoPtr->frameIndex;
	UInt32 count = infoPtr->frameCount;
	
	for (UInt32 n=0; n!=count; n++)
	{
		float srcSamples[2];
		
		error = RMSCacheFetch(rmsSource, index, srcSamples);
		if (error != noErr) return error;
		
		dstPtrL[n] = srcSamples[0];
		dstPtrR[n] = srcSamples[1];
		index += 1;
	}

	return error;
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackProcPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////

+ (instancetype)instanceWithSource:(RMSSource *)source
{ return [[self alloc] initWithSource:source]; }

+ (instancetype)instanceWithSource:(RMSSource *)source length:(UInt32)length
{ return [[self alloc] initWithSource:source length:length]; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype)init
{ return [self initWithSource:nil]; }

- (instancetype)initWithSource:(RMSSource *)source
{ return [self initWithSource:source length:32]; }

- (instancetype)initWithSource:(RMSSource *)source length:(UInt32)length
{
	self = [super init];
	if (self != nil)
	{
		UInt32 count = 4;
		while (count < length)
		{ count <<= 1; }
		
		mCacheSize = count;
		
		mSampleData[0] = calloc(count, sizeof(float));
		mSampleData[1] = calloc(count, sizeof(float));
		
		mStereoBuffer.bufferCount = 2;
		mStereoBuffer.buffer[0].mNumberChannels = 1;
		mStereoBuffer.buffer[0].mDataByteSize = count*sizeof(float);
		mStereoBuffer.buffer[0].mData = mSampleData[0];
		mStereoBuffer.buffer[1].mNumberChannels = 1;
		mStereoBuffer.buffer[1].mDataByteSize = count*sizeof(float);
		mStereoBuffer.buffer[1].mData = mSampleData[1];
		
		self.source = source;
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	for (size_t n=0; n!=2; n++)
	{
		if (mSampleData[n] != nil)
		{
			free(mSampleData[n]);
			mSampleData[n] = nil;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





