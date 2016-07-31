////////////////////////////////////////////////////////////////////////////////
/*
	RMSClip
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSClip.h"


@interface RMSClip ()
{
	float *mL;
	float *mR;
	
	size_t mIndex;
	size_t mCount;
}

@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSClip
////////////////////////////////////////////////////////////////////////////////

static OSStatus renderCallback(void *rmsSource, const RMSCallbackInfo *infoPtr)
{
	__unsafe_unretained RMSClip *rmsObject = \
	(__bridge __unsafe_unretained RMSClip *)rmsSource;
	
	float *srcPtrL = rmsObject->mL;
	float *srcPtrR = rmsObject->mR;

	float *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	float *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	
	
	size_t srcIndex = rmsObject->mIndex;
	size_t srcCount = rmsObject->mCount;
	size_t dstCount = infoPtr->frameCount;
	
	for (UInt32 n=0; n!=dstCount; n++)
	{
		dstPtrL[n] = srcPtrL[srcIndex];
		dstPtrR[n] = srcPtrR[srcIndex];
		srcIndex += 1;
		
		if (srcIndex == srcCount)
		{ srcIndex = 0; }
	}
	
	rmsObject->mIndex = srcIndex;

	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackProcPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{
	self = [super init];
	if (self != nil)
	{
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

+ (instancetype) sineWaveWithLength:(UInt64)N
{
	RMSClip *sineWave = [[self alloc] initWithLength:N];
	
	for (UInt32 n=0; n!=N; n++)
	{
		double x = (1.0*n+0.5)/N;
		double y = sin(x*2.0*M_PI);
		sineWave->mL[n] = y;
		sineWave->mR[n] = y;
	}
	
	return sineWave;
}

////////////////////////////////////////////////////////////////////////////////

+ (instancetype) blockWaveWithLength:(UInt64)N
{
	RMSClip *clip = [[self alloc] initWithLength:N];
	
	for (UInt64 n=0; n!=N/2; n++)
	{
		clip->mL[n] = +1.0;
		clip->mR[n] = +1.0;
	}

	for (UInt64 n=N/2; n!=N; n++)
	{
		clip->mL[n] = -1.0;
		clip->mR[n] = -1.0;
	}
	
	return clip;
}

////////////////////////////////////////////////////////////////////////////////

- (instancetype) initWithLength:(UInt64)size
{
	self = [super init];
	if (self != nil)
	{
		mCount = size;
		mL = calloc(size, sizeof(float));
		mR = calloc(size, sizeof(float));
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	if (mL != nil)
	{
		free(mL);
		mL = nil;
	}
	
	if (mR != nil)
	{
		free(mR);
		mR = nil;
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (size_t) sampleCount
{ return mCount; }

- (float *) mutablePtrL
{ return mL; }

- (float *) mutablePtrR
{ return mR; }

////////////////////////////////////////////////////////////////////////////////

- (void) normalize
{
	[self normalizeL];
	[self normalizeR];
}

////////////////////////////////////////////////////////////////////////////////

- (void) normalizeL
{
	float min = FLT_MAX;
	float avg = 0.0;
	float max = FLT_MIN;
	
	for (UInt32 x=0; x!=mCount; x++)
	{
		if (max < mL[x]) max = mL[x];
		if (min > mL[x]) min = mL[x];
		avg += mL[x];
	}
	
	avg /= mCount;
	max -= avg;
	min -= avg;
	float R = (fabsf(max) > fabsf(min)) ? fabsf(max) : fabsf(min);
	
	for (UInt32 x=0; x!=mCount; x++)
	{
		mL[x] = (mL[x] - avg) / R;
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) normalizeR
{
	float min = FLT_MAX;
	float avg = 0.0;
	float max = FLT_MIN;
	
	for (UInt32 x=0; x!=mCount; x++)
	{
		if (max < mR[x]) max = mR[x];
		if (min > mR[x]) min = mR[x];
		avg += mR[x];
	}
	
	avg /= mCount;
	max -= avg;
	min -= avg;
	float R = (fabsf(max) > fabsf(min)) ? fabsf(max) : fabsf(min);
	
	for (UInt32 x=0; x!=mCount; x++)
	{
		mR[x] = (mR[x] - avg) / R;
	}
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////



