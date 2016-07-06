////////////////////////////////////////////////////////////////////////////////
/*
	RMSVarispeed
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSVarispeed.h"
#import "RMSUtilities.h"
#import "RMSBezierInterpolator.h"

////////////////////////////////////////////////////////////////////////////////

typedef struct RMSStereoInterpolator
{
	rmscatmullrom_t L;
	rmscatmullrom_t R;
}
RMSStereoInterpolator;

static void RMSStereoInterpolatorUpdate
(RMSStereoInterpolator *ptr, RMSStereoBufferList *src, UInt32 index)
{
	Float32 *srcPtrL = src->buffer[0].mData;
	RMSCatmullRomUpdate(&ptr->L, srcPtrL[index]);

	Float32 *srcPtrR = src->buffer[1].mData;
	RMSCatmullRomUpdate(&ptr->R, srcPtrR[index]);
}

static void RMSStereoInterpolatorFetch
(RMSStereoInterpolator *ptr, double t, AudioBufferList *dst, UInt32 index)
{
	Float32 *dstPtrL = dst->mBuffers[0].mData;
	dstPtrL[index] = RMSCatmullRomFetch(&ptr->L, t);

	Float32 *dstPtrR = dst->mBuffers[1].mData;
	dstPtrR[index] = RMSCatmullRomFetch(&ptr->R, t);
}

////////////////////////////////////////////////////////////////////////////////



@interface RMSVarispeed ()
{
	UInt64 mIndex;
	Float64 mT;

	Float64 mSrcIndex;
	Float64 mSrcStep;
	
	RMSStereoInterpolator mInterpolator;
	
	UInt64 mSrcListIndex;
	UInt64 mSrcListCount;
	RMSStereoBufferList mSrcList;
	Float32 mSrcSamplesL[512];
	Float32 mSrcSamplesR[512];
}
@end




////////////////////////////////////////////////////////////////////////////////
@implementation RMSVarispeed
////////////////////////////////////////////////////////////////////////////////

static OSStatus RefreshBuffer(void *rmsObject, UInt64 index)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;
	
	// ensure AudioBufferList pointers are valid
	// (may have changed in audio unit calls)
	rmsSource->mSrcList.buffer[0].mData = &rmsSource->mSrcSamplesL[0];
	rmsSource->mSrcList.buffer[1].mData = &rmsSource->mSrcSamplesR[0];
	
	// create RMSCallbackInfo
	RMSCallbackInfo info;
	info.frameIndex = index&(~511);
	info.frameCount = 512;
	info.bufferListPtr = (AudioBufferList *)&rmsSource->mSrcList;

	// fetch source samples
	result = RunRMSSource((__bridge void *)rmsSource->mSource, &info);
	if (result == noErr)
	{
		rmsSource->mSrcListIndex = info.frameIndex;
		rmsSource->mSrcListCount = info.frameCount;
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
/*
	PrepareFetch
	------------
	Test whether a source sample at index is available
*/

static OSStatus PrepareFetch(void *rmsObject, UInt64 index)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;
	
	if (index >= rmsSource->mSrcListIndex+rmsSource->mSrcListCount)
	{
		result = RefreshBuffer(rmsObject, index);
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Interpolation
////////////////////////////////////////////////////////////////////////////////
/*
	InterpolateSource
	-----------------
	Upsampling algorithm (CRB interpolation)
*/

static OSStatus InterpolateSource(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	UInt64 index = rmsSource->mIndex;
	Float64 t = rmsSource->mT;
	Float64 srcStep = rmsSource->mSrcStep;

	// test if buffer is empty 
	if (rmsSource->mSrcListCount == 0)
	{
		// render source buffer
		result = RefreshBuffer(rmsObject, 0);
		if (result != noErr) return result;

		// prime interpolator with first 3 samples
		RMSStereoInterpolatorUpdate
		(&rmsSource->mInterpolator, &rmsSource->mSrcList, 0);
		RMSStereoInterpolatorUpdate
		(&rmsSource->mInterpolator, &rmsSource->mSrcList, 1);
		RMSStereoInterpolatorUpdate
		(&rmsSource->mInterpolator, &rmsSource->mSrcList, 2);

		index += 2;
	}

	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next src sample is required
		if (t >= 1.0)
		{
			// update src index
			index += 1;
			
			// test if next buffer is required
			if ((index & 511) == 0)
			{
				result = RefreshBuffer(rmsObject, index);
				if (result != noErr) return result;
			}
			
			// add new sample to interpolator
			RMSStereoInterpolatorUpdate
			(&rmsSource->mInterpolator, &rmsSource->mSrcList, index&511);
			
			// reset fraction
			t -= 1.0;
		}
		
		// fetch interpolated value
		RMSStereoInterpolatorFetch
		(&rmsSource->mInterpolator, t, infoPtr->bufferListPtr, n);
		
		// increase fraction by 1 src sample
		t += srcStep;
	}
	
	rmsSource->mIndex = index;
	rmsSource->mT = t;
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Decimation
////////////////////////////////////////////////////////////////////////////////
/*
	DecimateSource
	--------------
	Downsampling algorithm (weighted average)
*/
static OSStatus DecimateSource(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;

	Float64 srcIndex = rmsSource->mSrcIndex;
	Float64 srcStep = rmsSource->mSrcStep;
	Float64 m = 1.0/srcStep;

	Float64 x = srcIndex - trunc(srcIndex);
	UInt64 index = srcIndex;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		Float64 L = 0.0;
		Float64 R = 0.0;
		
		// test for remainder from previous cycle
		// can only be true after a buffer refresh and with valid index
		if (x > 0.0)
		{
			L += (1.0-x) * rmsSource->mSrcSamplesL[index&511];
			R += (1.0-x) * rmsSource->mSrcSamplesR[index&511];
			x -= 1.0;
			
			index += 1;
		}
		
		x += srcStep;
		while (x >= 1.0)
		{
			result = PrepareFetch(rmsObject, index);
			if (result != noErr) return result;

			L += rmsSource->mSrcSamplesL[index&511];
			R += rmsSource->mSrcSamplesR[index&511];
			x -= 1.0;

			index += 1;
		}
		
		if (x > 0.0)
		{
			result = PrepareFetch(rmsObject, index);
			if (result != noErr) return result;

			L += x * rmsSource->mSrcSamplesL[index&511];
			R += x * rmsSource->mSrcSamplesR[index&511];
		}

		dstPtrL[n] = m*L;
		dstPtrR[n] = m*R;
		
		srcIndex += srcStep;
	}

	rmsSource->mSrcIndex = srcIndex;// + srcStep * infoPtr->frameCount;
	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

static OSStatus renderCallback(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;
	
	if (rmsSource->mSrcStep <= 1.0)
	{
		result = InterpolateSource(rmsObject, infoPtr);
	}
	else
	{
		result = DecimateSource(rmsObject, infoPtr);
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

+ (instancetype)instanceWithSource:(RMSSource *)source
{ return [[self alloc] initWithSource:source]; }

- (instancetype)initWithSource:(RMSSource *)source;
{
	self = [super init];
	if (self != nil)
	{
		[self setSource:source];
		
		mSrcListIndex = 0;
		mSrcList.bufferCount = 2;
		mSrcList.buffer[0].mNumberChannels = 1;
		mSrcList.buffer[0].mDataByteSize = 512*sizeof(float);
		mSrcList.buffer[0].mData = &mSrcSamplesL[0];
		mSrcList.buffer[1].mNumberChannels = 1;
		mSrcList.buffer[1].mDataByteSize = 512*sizeof(float);
		mSrcList.buffer[1].mData = &mSrcSamplesR[0];
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
	[self updateRatio];
}

////////////////////////////////////////////////////////////////////////////////

- (void) setSampleRate:(Float64)sampleRate
{
	[super setSampleRate:sampleRate];
	[self updateRatio];
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateRatio
{
	double srcRate = [mSource sampleRate];
	double dstRate = [self sampleRate];
	
	mSrcStep = dstRate ? srcRate / dstRate : 1.0;
	if ((mSrcIndex < mSrcStep) && (mSrcStep < 1.0))
	{
		mSrcIndex = 0.5 * mSrcStep;
	}
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////

