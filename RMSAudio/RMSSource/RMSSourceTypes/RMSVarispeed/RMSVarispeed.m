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
	rmscrb_t L;
	rmscrb_t R;
}
RMSStereoInterpolator;
/*
static void RMSStereoInterpolatorUpdate
(RMSStereoInterpolator *ptr, RMSAudioBufferList *src, UInt32 index)
{
	Float32 *srcPtrL = src->buffer[0].mData;
	RMSResamplerWrite(&ptr->L, srcPtrL[index]);

	Float32 *srcPtrR = src->buffer[1].mData;
	RMSResamplerWrite(&ptr->R, srcPtrR[index]);
}
*/

static void RMSStereoInterpolatorUpdate
(RMSStereoInterpolator *ptr, float *srcPtr)
{
	RMSResamplerWrite(&ptr->L, srcPtr[0]);
	RMSResamplerWrite(&ptr->R, srcPtr[1]);
}


static void RMSStereoInterpolatorFetch
(RMSStereoInterpolator *ptr, double t, AudioBufferList *dst, UInt32 index)
{
	Float32 *dstPtrL = dst->mBuffers[0].mData;
	dstPtrL[index] = RMSResamplerFetch(&ptr->L, t);

	Float32 *dstPtrR = dst->mBuffers[1].mData;
	dstPtrR[index] = RMSResamplerFetch(&ptr->R, t);
}

////////////////////////////////////////////////////////////////////////////////
// TEMP
typedef struct rmsfilter_t
{
	double M;
	double S0;
	double S1;
	double S2;
}
rmsfilter_t;

rmsfilter_t RMSFilterInit(double Fc, double Fs)
{ return (rmsfilter_t){ .M = 1.0-exp(-2.0*M_PI * Fc / Fs), 0.0, 0.0, 0.0 }; }

float RMSFilterApply(rmsfilter_t *filterInfo, float S)
{
	S = (filterInfo->S0 += (S - filterInfo->S0) * filterInfo->M);
	S = (filterInfo->S1 += (S - filterInfo->S1) * filterInfo->M);
	S = (filterInfo->S2 += (S - filterInfo->S2) * filterInfo->M);
	return S;
}

void RMSFilterRun(rmsfilter_t *filterInfo, float *ptr, UInt32 N)
{
	for (UInt32 n=0; n!=N; n++)
	{ ptr[n] = RMSFilterApply(filterInfo, ptr[n]); }
}

////////////////////////////////////////////////////////////////////////////////

#define kRMSCacheSize 32
#define kRMSCacheMask (kRMSCacheSize-1)

@interface RMSVarispeed ()
{
	UInt64 mSrcIndex;
	Float64 mSrcFraction;
	Float64 mSrcStep;
	
	RMSCallbackProcPtr mResampleProc;
	RMSStereoInterpolator mInterpolator;
	
	rmsfilter_t mFilterL;
	rmsfilter_t mFilterR;
	
	float *mSrcSamplesL;
	float *mSrcSamplesR;
}
@end



////////////////////////////////////////////////////////////////////////////////
@implementation RMSVarispeed
////////////////////////////////////////////////////////////////////////////////

static OSStatus PostFilter(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)objectPtr;

	float *ptrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	RMSFilterRun(&rmsSource->mFilterL, ptrL, infoPtr->frameCount);
	
	float *ptrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	RMSFilterRun(&rmsSource->mFilterR, ptrR, infoPtr->frameCount);
	
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

static OSStatus InterpolateSource(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)objectPtr;

	// TODO: need better var naming
	UInt64 srcIndex = rmsSource->mSrcIndex;
	Float64 srcFraction = rmsSource->mSrcFraction;
	const Float64 srcStep = rmsSource->mSrcStep;

	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next src sample is required
		while (srcFraction >= 1.0)
		{
			float src[2];
			RMSCacheFetch(objectPtr, srcIndex, src);
			RMSStereoInterpolatorUpdate(&rmsSource->mInterpolator, src);
			
			// update src index
			srcIndex += 1;
			
			// update fraction
			srcFraction -= 1.0;
		}
		
		// fetch interpolated value
		RMSStereoInterpolatorFetch
		(&rmsSource->mInterpolator, srcFraction, infoPtr->bufferListPtr, n);
		
		// increase fraction by 1 dst sample
		srcFraction += srcStep;
	}
	
	rmsSource->mSrcIndex = srcIndex;
	rmsSource->mSrcFraction = srcFraction;
	
	PostFilter(objectPtr, infoPtr);
	
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
/*
	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;

	UInt64 index = rmsSource->mSrcIndex;
	Float64 x = rmsSource->mSrcFraction;
	const Float64 s = rmsSource->mSrcStep;
	const Float64 m = 1.0/s;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		Float64 L = 0.0;
		Float64 R = 0.0;
		
		// test for remainder from previous cycle
		// will only be true after a buffer refresh and with valid index
		if (x > 0.0)
		{
			L += (1.0-x) * rmsSource->mSrcSamplesL[index&kRMSCacheMask];
			R += (1.0-x) * rmsSource->mSrcSamplesR[index&kRMSCacheMask];
			x -= 1.0;
			
			index += 1;
		}
		
		x += s;
		while (x >= 1.0)
		{
			result = PrepareFetch(rmsObject, index);
			if (result != noErr) return result;

			L += rmsSource->mSrcSamplesL[index&kRMSCacheMask];
			R += rmsSource->mSrcSamplesR[index&kRMSCacheMask];
			x -= 1.0;

			index += 1;
		}
		
		if (x > 0.0)
		{
			result = PrepareFetch(rmsObject, index);
			if (result != noErr) return result;

			L += x * rmsSource->mSrcSamplesL[index&kRMSCacheMask];
			R += x * rmsSource->mSrcSamplesR[index&kRMSCacheMask];
		}

		dstPtrL[n] = m*L;
		dstPtrR[n] = m*R;
	}

	rmsSource->mSrcIndex = index;
	rmsSource->mSrcFraction = x;
*/
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus DecimateSourceByN(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;
/*
	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;


	UInt64 index = rmsSource->mSrcIndex & kRMSCacheMask;
	Float32 *srcPtrL = rmsSource->mSrcSamplesL;
	Float32 *srcPtrR = rmsSource->mSrcSamplesR;

	UInt32 N = rmsSource->mSrcStep;
//	float m = 1.0 / N;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next buffer is required
		if ((index &= kRMSCacheMask) == 0)
		{
			result = RefreshBuffer(rmsObject, index);
			if (result != noErr) return result;
		}
/*
		dstPtrL[n] = m*vSsum(N, (vFloat *)&srcPtrL[index]);
		dstPtrR[n] = m*vSsum(N, (vFloat *)&srcPtrR[index]);
/*
		vDSP_meanv(&srcPtrL[index], 1, &dstPtrL[n], N);
		vDSP_meanv(&srcPtrR[index], 1, &dstPtrR[n], N);
//*
		index += N;
	}

	rmsSource->mSrcIndex += infoPtr->frameCount * N;
*/
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
	
	if (rmsSource->mResampleProc != nil)
	{ result = rmsSource->mResampleProc(rmsObject, infoPtr); }
	else
	{ result = RunRMSSource(RMSSourceGetSource(rmsObject), infoPtr); }
	
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
	
	if (srcRate < dstRate)
	{
		// remove high-freq after upsampling
		mFilterL = RMSFilterInit(0.5 * srcRate, dstRate);
		mFilterR = RMSFilterInit(0.5 * srcRate, dstRate);
	}
	else
	{
		// remove high-freq before downsampling
		mFilterL = RMSFilterInit(0.5 * dstRate, srcRate);
		mFilterR = RMSFilterInit(0.5 * dstRate, srcRate);
	}
	
	mSrcStep = dstRate ? srcRate / dstRate : 1.0;
	
	if (mSrcStep < 1.0)
	{
		// interpolators can be primed with 3 samples before first fetch
		mSrcFraction = 3.0;
		mResampleProc = InterpolateSource;
	}
	else
	if (mSrcStep > 1.0)
	{
		mResampleProc = DecimateSource;
		
		double N = log2(mSrcStep);
		if ((N-floor(N))==0.0)
		{
			mResampleProc = DecimateSourceByN;
		}
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

