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
#import "rmssum.h"
#import "rmsfilter.h"

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

static void RMSStereoInterpolatorUpdateWithParameter
(RMSStereoInterpolator *ptr, float *srcPtr, float P)
{
	RMSResamplerWriteWithParameter(&ptr->L, srcPtr[0], P);
	RMSResamplerWriteWithParameter(&ptr->R, srcPtr[1], P);
}


static void RMSStereoInterpolatorFetch
(RMSStereoInterpolator *ptr, double t, AudioBufferList *dst, UInt32 index)
{
	Float32 *dstPtrL = dst->mBuffers[0].mData;
	dstPtrL[index] = RMSResamplerFetch(&ptr->L, t);

	Float32 *dstPtrR = dst->mBuffers[1].mData;
	dstPtrR[index] = RMSResamplerFetch(&ptr->R, t);
}

static void RMSStereoInterpolatorFetchJittered
(RMSStereoInterpolator *ptr, double t, AudioBufferList *dst, UInt32 index)
{
	Float32 *dstPtrL = dst->mBuffers[0].mData;
	dstPtrL[index] = RMSResamplerJitteredFetch(&ptr->L, t);

	Float32 *dstPtrR = dst->mBuffers[1].mData;
	dstPtrR[index] = RMSResamplerJitteredFetch(&ptr->R, t);
}

static void RMSStereoInterpolatorFetchLinear
(RMSStereoInterpolator *ptr, double t, AudioBufferList *dst, UInt32 index)
{
	Float32 *dstPtrL = dst->mBuffers[0].mData;
	dstPtrL[index] = RMSResamplerLinearFetch(&ptr->L, t);

	Float32 *dstPtrR = dst->mBuffers[1].mData;
	dstPtrR[index] = RMSResamplerLinearFetch(&ptr->R, t);
}

////////////////////////////////////////////////////////////////////////////////
// TEMP
typedef struct rmsfltr_t
{
	float M;
	UInt32 index;
	UInt32 count;
	float A[2][32];
}
rmsfltr_t;

rmsfltr_t RMSFltrInit(int N)
{
	rmsfltr_t F;
	memset(&F, 0, sizeof(F));
	
	F.count = N;
	F.M = 1.0/pow(2.0, F.count);
	
	return F;
}

rmsfltr_t RMSFltrInitWithCutoff(double Fc, double Fs)
{
	// wavelength = sampleRate / freq
	double wl = Fs / Fc;
	// samplewidth = wavelength / 2.0
	double sw = wl / 2.0;
	
	return RMSFltrInit(ceil(sw));
}




float RMSFltrApply(rmsfltr_t *F, float S)
{
	float *A0 = F->A[F->index];
	float *A1 = F->A[F->index^1];

	UInt32 n=F->count;
	while (n != 0)
	{
		n -= 1;
		A0[n] = S;
		S += A1[n];
	}
	
	F->index ^= 1;
	
	return F->M * S;
}




void RMSFltrRun(rmsfltr_t *filterInfo, float *ptr, UInt32 N)
{
	for (UInt32 n=0; n!=N; n++)
	{ ptr[n] = RMSFltrApply(filterInfo, ptr[n]); }
}

////////////////////////////////////////////////////////////////////////////////

@interface RMSVarispeed ()
{
	UInt64 mSrcIndex;
	UInt64 mSrcIndexMask;
	Float64 mSrcFraction;
	Float64 mSrcStep;
	
	float M;
	float A[2];
	
	RMSCallbackProcPtr mResampleProc;
	RMSStereoInterpolator mInterpolator;
	
	rmsfilter_t mFilterL;
	rmsfilter_t mFilterR;

	rmsfltr_t mFltrL;
	rmsfltr_t mFltrR;

	rmssum_t *mSumL[4];
	rmssum_t *mSumR[4];
	
	float *mSrcSamplesL;
	float *mSrcSamplesR;
}
@end



////////////////////////////////////////////////////////////////////////////////
@implementation RMSVarispeed
////////////////////////////////////////////////////////////////////////////////

static OSStatus ApplyFilter(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)objectPtr;

	float *ptrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	RMSSumRunAverage(rmsSource->mSumL[0], ptrL, infoPtr->frameCount);
	
	float *ptrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	RMSSumRunAverage(rmsSource->mSumR[0], ptrR, infoPtr->frameCount);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus ApplyFilter1(void *objectPtr, const RMSCallbackInfo *infoPtr)
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

static OSStatus ApplyFilter2(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)objectPtr;

	float *ptrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	RMSFltrRun(&rmsSource->mFltrL, ptrL, infoPtr->frameCount);
	
	float *ptrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	//RMSFltrRun(&rmsSource->mFltrR, ptrR, infoPtr->frameCount);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Interpolation
////////////////////////////////////////////////////////////////////////////////
/*
	InterpolateSource0
	------------------
	Upsampling algorithm Nearest Neighbor
*/

static OSStatus InterpolateSource0(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)objectPtr;

	// TODO: need better var naming
	UInt64 srcIndex = rmsSource->mSrcIndex;
	Float64 srcFraction = rmsSource->mSrcFraction;
	const Float64 srcStep = rmsSource->mSrcStep;

	float src[2];

	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next src sample is required
		while (srcFraction >= 1.0)
		{
			RMSCacheFetch(objectPtr, srcIndex, src);
			
			// update src index
			srcIndex += 1;
			
			// update fraction
			srcFraction -= 1.0;
		}
		
		((float *)(infoPtr->bufferListPtr->mBuffers[0].mData))[n] = src[0];
		((float *)(infoPtr->bufferListPtr->mBuffers[1].mData))[n] = src[1];
		
		// increase fraction by 1 dst sample
		srcFraction += srcStep;
	}
	
	rmsSource->mSrcIndex = srcIndex;
	rmsSource->mSrcFraction = srcFraction;
	
	if (rmsSource->_shouldFilter)
	{ ApplyFilter(objectPtr, infoPtr); }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus InterpolateSourceJ(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)objectPtr;

	// TODO: need better var naming
	UInt64 srcIndex = rmsSource->mSrcIndex;
	Float64 srcFraction = rmsSource->mSrcFraction;
	const Float64 srcStep = rmsSource->mSrcStep;

	float src[2];

	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next src sample is required
		while (srcFraction >= 1.0)
		{
			RMSCacheFetch(objectPtr, srcIndex, src);

			RMSStereoInterpolatorUpdateWithParameter \
			(&rmsSource->mInterpolator, src, rmsSource->_parameter);
			
			// update src index
			srcIndex += 1;
			
			// update fraction
			srcFraction -= 1.0;
		}
		
		// fetch interpolated value
		RMSStereoInterpolatorFetchJittered
		(&rmsSource->mInterpolator, srcFraction, infoPtr->bufferListPtr, n);
		
		// increase fraction by 1 dst sample
		srcFraction += srcStep;
	}
	
	rmsSource->mSrcIndex = srcIndex;
	rmsSource->mSrcFraction = srcFraction;
	
	if (rmsSource->_shouldFilter)
	{ ApplyFilter(objectPtr, infoPtr); }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
static OSStatus InterpolateSource1(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)objectPtr;

	// TODO: need better var naming
	UInt64 srcIndex = rmsSource->mSrcIndex;
	Float64 srcFraction = rmsSource->mSrcFraction;
	const Float64 srcStep = rmsSource->mSrcStep;

	float src[2];

	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next src sample is required
		while (srcFraction >= 1.0)
		{
			RMSCacheFetch(objectPtr, srcIndex, src);

			RMSStereoInterpolatorUpdateWithParameter \
			(&rmsSource->mInterpolator, src, rmsSource->_parameter);
			
			// update src index
			srcIndex += 1;
			
			// update fraction
			srcFraction -= 1.0;
		}
		
		// fetch interpolated value
		RMSStereoInterpolatorFetchLinear
		(&rmsSource->mInterpolator, srcFraction, infoPtr->bufferListPtr, n);
		
		// increase fraction by 1 dst sample
		srcFraction += srcStep;
	}
	
	rmsSource->mSrcIndex = srcIndex;
	rmsSource->mSrcFraction = srcFraction;
	
	if (rmsSource->_shouldFilter)
	{ ApplyFilter(objectPtr, infoPtr); }
	
	return result;
}

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
			//RMSStereoInterpolatorUpdate(&rmsSource->mInterpolator, src);
			RMSStereoInterpolatorUpdateWithParameter \
			(&rmsSource->mInterpolator, src, rmsSource->_parameter);
			
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
	
	if (rmsSource->_shouldFilter)
	{ ApplyFilter(objectPtr, infoPtr); }
	
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
static OSStatus DecimateSource_(void *rmsObject, const RMSCallbackInfo *infoPtr)
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

static void RunAverage(float M, float A[], AudioBufferList *listPtr, UInt32 N)
{
	float *ptrL = listPtr->mBuffers[0].mData;
	float *ptrR = listPtr->mBuffers[1].mData;
	
	for (UInt32 n=0; n!=N; n++)
	{
		ptrL[n] = (A[0] += (ptrL[n] - A[0])*M);
		ptrR[n] = (A[1] += (ptrL[n] - A[1])*M);
	}
}

static void RMSDecimatorRunAverage(void *objectPtr)
{
	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)objectPtr;
	
	float M = rmsSource->M;
	float *A = rmsSource->A;
	RunAverage(M, A, &rmsSource->mCacheBuffer.list, rmsSource->mCacheSize);
}

OSStatus RMSDecimatorPrepareFetch(void *objectPtr, UInt64 index)
{
	OSStatus result = noErr;
	
	if (RMSCacheShouldRefreshBuffer(objectPtr, index))
	{
		result = RMSCacheRefreshBuffer(objectPtr, index);
		if (result != noErr) return result;
		
		RMSDecimatorRunAverage(objectPtr);
	}
	
	return result;
}

static inline float _RMSDecimate(float A, float M, float *srcPtr, UInt32 N)
{
	do
	{
		A += (srcPtr[0] - A) * M;
		A += (srcPtr[1] - A) * M;
		srcPtr += 2;
	}
	while ((N-=2) != 0);
	
	return A;
}

static inline float RMSAverage(const float *srcPtr, UInt32 N)
{
	if (N == 2)
		return 0.5 * (
		(srcPtr[0]+srcPtr[1]));

	if (N == 4)
		return 0.25 * (
		(srcPtr[0] + srcPtr[1])+
		(srcPtr[2] + srcPtr[3]));
	
	if (N == 8)
		return 0.125 * (
		(srcPtr[0] + srcPtr[1])+
		(srcPtr[2] + srcPtr[3])+
		(srcPtr[4] + srcPtr[5])+
		(srcPtr[6] + srcPtr[7]));

	float M = (1.0/N);
	float S = srcPtr[(N-=1)];
	do { S += srcPtr[(N-=1)]; } while(N != 0);
	return M*S;
}

static OSStatus DecimateSourceByN(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	Float32 *srcPtrL = rmsSource->mCacheBuffer.buffer[0].mData;
	Float32 *srcPtrR = rmsSource->mCacheBuffer.buffer[1].mData;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;

	float M = rmsSource->M;
	float *A = rmsSource->A;


	UInt32 N = rmsSource->mSrcStep;
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
		dstPtrL[n] = RMSAverage(&srcPtrL[index&indexMask], N);
		dstPtrR[n] = RMSAverage(&srcPtrR[index&indexMask], N);
/*/
		vDSP_meanv(&srcPtrL[index&indexMask], 1, &dstPtrL[n], N);
		vDSP_meanv(&srcPtrR[index&indexMask], 1, &dstPtrR[n], N);
//*/
		index += N;
	}

	rmsSource->A[0] = A[0];
	rmsSource->A[1] = A[1];
	rmsSource->mSrcIndex += infoPtr->frameCount * N;

	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus DecimateSource(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	Float32 *srcPtrL = rmsSource->mCacheBuffer.buffer[0].mData;
	Float32 *srcPtrR = rmsSource->mCacheBuffer.buffer[1].mData;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;

	UInt32 N = rmsSource->mSrcStep;
	UInt64 index = rmsSource->mSrcIndex;
	UInt64 indexMask = rmsSource->mSrcIndexMask;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		
	}

	rmsSource->mSrcIndex += infoPtr->frameCount * N;

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
		mSrcIndexMask = length-1;
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
		mFilterL = RMSFilterInitWithCutoff(0.5 * srcRate, dstRate, 4);
		mFilterR = RMSFilterInitWithCutoff(0.5 * srcRate, dstRate, 4);

		// remove high-freq after upsampling
		mFltrL = RMSFltrInitWithCutoff(0.5 * srcRate, dstRate);
		mFltrR = RMSFltrInitWithCutoff(0.5 * srcRate, dstRate);
		
		for (UInt32 n=0; n!=4; n++)
		{
			RMSSumRelease(mSumL[n]);
			RMSSumRelease(mSumR[n]);
			mSumL[n] = RMSSumNew(ceil(dstRate/srcRate));
			mSumR[n] = RMSSumNew(ceil(dstRate/srcRate));
		}
	}
	else
	{
		// remove high-freq before downsampling
		mFilterL = RMSFilterInitWithCutoff(0.5 * dstRate, srcRate, 4);
		mFilterR = RMSFilterInitWithCutoff(0.5 * dstRate, srcRate, 4);
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
			M = (1.0/mSrcStep);
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

