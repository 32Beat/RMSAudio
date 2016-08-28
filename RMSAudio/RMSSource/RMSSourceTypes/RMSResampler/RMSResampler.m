////////////////////////////////////////////////////////////////////////////////
/*
	RMSResampler
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSResampler.h"
#import "RMSUtilities.h"
#import "RMSInterpolator.h"
#import "rmsavg.h"
#import "rmssum.h"
#import "rmsfilter.h"

////////////////////////////////////////////////////////////////////////////////
/*
static void RMSInterpolatorUpdateStereo
(rmsinterpolator_t *ptr, AudioBufferList *src, UInt32 index)
{
	Float32 *srcPtrL = src->mBuffers[0].mData;
	RMSInterpolatorUpdate(&ptr[0], srcPtrL[index]);
	Float32 *srcPtrR = src->mBuffers[1].mData;
	RMSInterpolatorUpdate(&ptr[1], srcPtrR[index]);
}

static void RMSInterpolatorFetchStereo
(rmsinterpolator_t *ptr, double t, AudioBufferList *dst, UInt32 index)
{
	Float32 *dstPtrL = dst->mBuffers[0].mData;
	dstPtrL[index] = RMSInterpolatorFetch(&ptr[0], t);

	Float32 *dstPtrR = dst->mBuffers[1].mData;
	dstPtrR[index] = RMSInterpolatorFetch(&ptr[1], t);
}
*/
////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////


@interface RMSResampler ()
{
	UInt64 mSrcIndex;
	UInt64 mSrcIndexMask;
	Float64 mSrcFraction;
	Float64 mSrcStep;
	
	RMSCallbackProcPtr mResampleProc;
	rmsinterpolator_t mInterpolator[2];
	
	double mA[2][4];
}
@end



////////////////////////////////////////////////////////////////////////////////
@implementation RMSResampler
////////////////////////////////////////////////////////////////////////////////

static OSStatus InterpolateSource(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)objectPtr;

	Float64 srcT = rmsSource->mSrcFraction;
	UInt64 index = rmsSource->mSrcIndex;
	UInt64 indexMask = rmsSource->mSrcIndexMask;

	Float32 *srcPtrL = rmsSource->mCacheBuffer.buffer[0].mData;
	Float32 *srcPtrR = rmsSource->mCacheBuffer.buffer[1].mData;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;

	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next src sample is required
		while (srcT >= 1.0)
		{
			srcT -= 1.0;
			
			UInt64 maskedIndex = index & indexMask;
			
			// test if next buffer is required
			if (maskedIndex == 0)
			{
				result = RMSCacheRefreshBuffer(objectPtr, index);
				if (result != noErr) return result;
			}
			
			RMSInterpolatorUpdate(&rmsSource->mInterpolator[0], srcPtrL[maskedIndex]);
			RMSInterpolatorUpdate(&rmsSource->mInterpolator[1], srcPtrR[maskedIndex]);
			
			// update src index
			index += 1;
		}
		
		// fetch interpolated value
		dstPtrL[n] = RMSInterpolatorFetch(&rmsSource->mInterpolator[0], srcT);
		dstPtrR[n] = RMSInterpolatorFetch(&rmsSource->mInterpolator[1], srcT);
		
		// increase fraction by 1 dst sample
		srcT += rmsSource->mSrcStep;
	}
	
	rmsSource->mSrcIndex = index;
	rmsSource->mSrcFraction = srcT;

	return result;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Decimation
////////////////////////////////////////////////////////////////////////////////

static OSStatus DecimateSource(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)objectPtr;

	Float32 *srcPtrL = rmsSource->mCacheBuffer.buffer[0].mData;
	Float32 *srcPtrR = rmsSource->mCacheBuffer.buffer[1].mData;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;


	Float64 srcT = rmsSource->mSrcFraction;
	UInt64 index = rmsSource->mSrcIndex;
	UInt64 indexMask = rmsSource->mSrcIndexMask;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		while (srcT >= 1.0)
		{
			srcT -= 1.0;

			// test if next buffer is required
			if ((index & indexMask) == 0)
			{
				result = RMSCacheRefreshBuffer(objectPtr, index);
				if (result != noErr) return result;
			}
			
			RMSInterpolatorUpdate(&rmsSource->mInterpolator[0], srcPtrL[index&indexMask]);
			RMSInterpolatorUpdate(&rmsSource->mInterpolator[1], srcPtrR[index&indexMask]);
			
			index += 1;
		}

		// fetch interpolated value
		dstPtrL[n] = RMSInterpolatorFetch(&rmsSource->mInterpolator[0], srcT);
		dstPtrR[n] = RMSInterpolatorFetch(&rmsSource->mInterpolator[1], srcT);
		
		srcT += rmsSource->mSrcStep;
	}
	
	rmsSource->mSrcFraction = srcT;
	rmsSource->mSrcIndex = index;

	return noErr;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

static inline float RMSSum(const float *srcPtr, UInt32 N)
{
	if (N == 2)
		return(srcPtr[0]+srcPtr[1]);

	if (N == 4)
		return
		(srcPtr[0] + srcPtr[1])+
		(srcPtr[2] + srcPtr[3]);
	
	if (N == 8)
		return
		(srcPtr[0] + srcPtr[1])+
		(srcPtr[2] + srcPtr[3])+
		(srcPtr[4] + srcPtr[5])+
		(srcPtr[6] + srcPtr[7]);

	float S = srcPtr[(N-=1)];
	do { S += srcPtr[(N-=1)]; } while(N != 0);
	return S;
}

static OSStatus DecimateSourceByN(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)rmsObject;

	Float32 *srcPtrL = rmsSource->mCacheBuffer.buffer[0].mData;
	Float32 *srcPtrR = rmsSource->mCacheBuffer.buffer[1].mData;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;

	UInt32 N = rmsSource->mSrcStep;
	float M = 1.0 / N;
	
	UInt64 index = rmsSource->mSrcIndex;
	UInt64 indexMask = rmsSource->mSrcIndexMask;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next buffer is required
		if ((index & indexMask) == 0)
		{
			result = RMSCacheRefreshBuffer(rmsObject, index);
			if (result != noErr) return result;
		}
//*
		dstPtrL[n] = M * RMSSum(&srcPtrL[index&indexMask], N);
		dstPtrR[n] = M * RMSSum(&srcPtrR[index&indexMask], N);
/*/
		vDSP_meanv(&srcPtrL[index&indexMask], 1, &dstPtrL[n], N);
		vDSP_meanv(&srcPtrR[index&indexMask], 1, &dstPtrR[n], N);
//*/
		index += N;
	}

	rmsSource->mSrcIndex = index;

	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus DecimateSourceBy2(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)rmsObject;

	Float32 *srcPtrL = rmsSource->mCacheBuffer.buffer[0].mData;
	Float32 *srcPtrR = rmsSource->mCacheBuffer.buffer[1].mData;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;

	UInt64 index = rmsSource->mSrcIndex;
	UInt64 indexMask = rmsSource->mSrcIndexMask;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		UInt64 maskedIndex = index & indexMask;
		
		// test if next buffer is required
		if (maskedIndex == 0)
		{
			result = RMSCacheRefreshBuffer(rmsObject, index);
			if (result != noErr) return result;
		}
		
		dstPtrL[n] = RMSDecimatorUpdate2(rmsSource->mA[0], &srcPtrL[maskedIndex]);
		dstPtrR[n] = RMSDecimatorUpdate2(rmsSource->mA[1], &srcPtrR[maskedIndex]);
		
		index += 2;
	}
	
	rmsSource->mSrcIndex = index;

	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus DecimateSourceBy4(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)rmsObject;

	Float32 *srcPtrL = rmsSource->mCacheBuffer.buffer[0].mData;
	Float32 *srcPtrR = rmsSource->mCacheBuffer.buffer[1].mData;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;

	UInt64 index = rmsSource->mSrcIndex;
	UInt64 indexMask = rmsSource->mSrcIndexMask;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		UInt64 maskedIndex = index & indexMask;
		
		// test if next buffer is required
		if (maskedIndex == 0)
		{
			result = RMSCacheRefreshBuffer(rmsObject, index);
			if (result != noErr) return result;
		}
		
		dstPtrL[n] = RMSDecimatorUpdate4(rmsSource->mA[0], &srcPtrL[maskedIndex]);
		dstPtrR[n] = RMSDecimatorUpdate4(rmsSource->mA[1], &srcPtrR[maskedIndex]);
		
		index += 4;
	}
	
	rmsSource->mSrcIndex = index;

	return noErr;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

static OSStatus renderCallback(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)rmsObject;
	
	if (rmsSource->mResampleProc != nil)
	{ result = rmsSource->mResampleProc(rmsObject, infoPtr); }
	else
	{ result = RunRMSSourceChain(rmsObject, infoPtr); }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackProcPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (instancetype)initWithSource:(RMSSource *)source length:(UInt32)length
{
	self = [super initWithSource:source length:length];
	if (self != nil)
	{
		mSrcIndexMask = mCacheSize-1;
	}
	
	return self;
}

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
	double srcRate = [[self sourceAtIndex:0] sampleRate];
	double dstRate = [self sampleRate];
	
	mSrcStep = dstRate ? srcRate / dstRate : 1.0;
	
	if (mSrcStep != 1.0)
	{
		/*
			spline interpolator should be primed with 3 samples,
			center of destination sample = half of srcStep,
			center of source sample = 0.5
			
			this will start decimation by 2 at t = 0.5
		*/
		mSrcFraction = 3.0 + 0.5 * mSrcStep - 0.5;
		mResampleProc = InterpolateSource;
		mInterpolator[0] = RMSSplineInterpolator();
		mInterpolator[1] = RMSSplineInterpolator();
	}
	else
	{
		// this will simply invoke source for 1:1 samples
		mResampleProc = nil;
	}
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////

