////////////////////////////////////////////////////////////////////////////////
/*
	RMSResampler
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSResampler.h"
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

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////


typedef struct rmsdecimator_t
{
	double M;
	double S0;
	double S1;
}
rmsdecimator_t;

rmsdecimator_t RMSDecimatorInit(double M)
{ return (rmsdecimator_t){ .M = M, 0.0, 0.0 }; }

void RMSDecimatorUpdate(rmsdecimator_t *decimator, float S)
{
	decimator->S0 += decimator->S1;
	decimator->S1 = S;
}

double RMSDecimatorFetch(rmsdecimator_t *decimator, double t)
{
	double S = t * decimator->S1;
	decimator->S0 += S;
	decimator->S1 -= S;

	double D = decimator->S0;
	decimator->S0 = 0.0;

	return decimator->M * D;
}

/*
	Oddly enough, the running average seems to be slightly quicker than 
	the summing average above, even for 8.5x downsampling...
*/
void RMSDecimatorUpdateRunningAverage(rmsdecimator_t *decimator, float S)
{
	decimator->S0 = decimator->S1;
	decimator->S1 += (S - decimator->S1) * decimator->M;
}

double RMSDecimatorFetchRunningAverage(rmsdecimator_t *decimator, double t)
{ return decimator->S0 + t * (decimator->S1 - decimator->S0); }



typedef struct RMSStereoDecimator
{
	rmsdecimator_t L;
	rmsdecimator_t R;
}
RMSStereoDecimator;

RMSStereoDecimator RMSStereoDecimatorInit(double M)
{
	return (RMSStereoDecimator){
		.L = RMSDecimatorInit(M),
		.R = RMSDecimatorInit(M)};
}

/*
static void _RMSStereoDecimatorUpdate
(RMSStereoDecimator *decimator, float *sampleData)
{
	decimator->L0 = decimator->L1;
	decimator->L1 += (sampleData[0] - decimator->L1) * decimator->M;
	decimator->R0 = decimator->R1;
	decimator->R1 += (sampleData[1] - decimator->R1) * decimator->M;
}

static void _RMSStereoDecimatorFetch
(RMSStereoDecimator *decimator, double t, AudioBufferList *dst, UInt32 index)
{
	Float32 *dstPtrL = dst->mBuffers[0].mData;
	dstPtrL[index] = decimator->L0 + t * (decimator->L1 - decimator->L0);

	Float32 *dstPtrR = dst->mBuffers[1].mData;
	dstPtrR[index] = decimator->R0 + t * (decimator->R1 - decimator->R0);
}
*/

static void RMSStereoDecimatorUpdate
(RMSStereoDecimator *decimator, float *sampleData)
{
	RMSDecimatorUpdate(&decimator->L, sampleData[0]);
	RMSDecimatorUpdate(&decimator->R, sampleData[1]);
}


static void RMSStereoDecimatorFetch
(RMSStereoDecimator *decimator, double t, AudioBufferList *dst, UInt32 index)
{
	((Float32 *)dst->mBuffers[0].mData)[index] = RMSDecimatorFetch(&decimator->L, t);
	((Float32 *)dst->mBuffers[1].mData)[index] = RMSDecimatorFetch(&decimator->R, t);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

typedef struct rmstest_t
{
	double M;
	double Q;
	double V;
	double E;
}
rmstest_t;


static inline float RMSTestApply(rmstest_t *F, float S)
{
	double E = S - F->V;
	F->E += (E - F->E)*F->Q*F->Q;
	F->V += F->E * F->M;
	
	return F->V;
}


void RMSTestRun(rmstest_t *F, float *ptr, uint32_t N)
{
	for (uint32_t n=0; n!=N; n++)
	{ ptr[n] = RMSTestApply(F, ptr[n]); }
}

////////////////////////////////////////////////////////////////////////////////


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
	RMSStereoInterpolator mInterpolator;
	RMSStereoDecimator mDecimator;
	
	rmstest_t mTest[2];
	
	rmsfilter_t mFilterL[4];
	rmsfilter_t mFilterR[4];

	rmssum_t *mSumL[4];
	rmssum_t *mSumR[4];
	
	float *mSrcSamplesL;
	float *mSrcSamplesR;
}
@end



////////////////////////////////////////////////////////////////////////////////
@implementation RMSResampler
////////////////////////////////////////////////////////////////////////////////
/*
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
*/
////////////////////////////////////////////////////////////////////////////////

static OSStatus ApplyFilter_(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)objectPtr;

	rmsSource->mTest[0].Q = rmsSource->_parameter;
	rmsSource->mTest[1].Q = rmsSource->_parameter;

	UInt32 n = 1;//rmsSource->_filterOrder;
	while (n!=0)
	{
		n -= 1;
		
		float *ptrL = infoPtr->bufferListPtr->mBuffers[0].mData;
		//RMSFilterRun(&rmsSource->mFilterL[n], ptrL, infoPtr->frameCount);
		RMSTestRun(&rmsSource->mTest[0], ptrL, infoPtr->frameCount);
		
		float *ptrR = infoPtr->bufferListPtr->mBuffers[1].mData;
//		RMSFilterRun(&rmsSource->mFilterR[n], ptrR, infoPtr->frameCount);
		RMSTestRun(&rmsSource->mTest[1], ptrR, infoPtr->frameCount);
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus ApplyFilter(void *objectPtr, AudioBufferList *bufferListPtr, UInt32 N)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)objectPtr;

	float *ptrL = bufferListPtr->mBuffers[0].mData;
	RMSFilterRun(&rmsSource->mFilterL[0], ptrL, N);
	
	float *ptrR = bufferListPtr->mBuffers[1].mData;
	RMSFilterRun(&rmsSource->mFilterR[0], ptrR, N);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Interpolation
////////////////////////////////////////////////////////////////////////////////
/*
	InterpolateSource
	-----------------
	Upsampling algorithm (Spline interpolation)
*/

static OSStatus InterpolateSource(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)objectPtr;

	UInt64 srcIndex = rmsSource->mSrcIndex;
	Float64 srcFraction = rmsSource->mSrcFraction;
	const Float64 srcStep = rmsSource->mSrcStep;

	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next src sample is required
		while (srcFraction >= 1.0)
		{
			// fetch next sample from cache
			// (this will trigger rendercycle on source if necessary)
			float src[2];
			RMSCacheFetch(objectPtr, srcIndex, src);
			
			// update interpolator with sample
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
	
	// apply post-filtering if desired
	if (rmsSource->_shouldFilter)
	{ ApplyFilter(objectPtr, infoPtr->bufferListPtr, infoPtr->frameCount); }
	
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
			
			RMSDecimatorUpdateRunningAverage(&rmsSource->mDecimator.L, srcPtrL[index&indexMask]);
			RMSDecimatorUpdateRunningAverage(&rmsSource->mDecimator.R, srcPtrR[index&indexMask]);
			
			index += 1;
		}

		dstPtrL[n] = RMSDecimatorFetchRunningAverage(&rmsSource->mDecimator.L, srcT);
		dstPtrR[n] = RMSDecimatorFetchRunningAverage(&rmsSource->mDecimator.R, srcT);
		
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
	
	double filterCutoff, filterRate;
	
	if (srcRate < dstRate)
	{
		// remove high-freq after upsampling
		filterCutoff = 0.5 * srcRate;
		filterRate = dstRate;
	}
	else
	{
		// remove high-freq before downsampling
		filterCutoff = 0.5 * dstRate;
		filterRate = srcRate;
	}
	
	// spline interpolation + second order filter
	self.filterOrder = 2;
	for (UInt32 n=0; n!=4; n++)
	{
		mFilterL[n] = RMSFilterInitWithCutoff(filterCutoff, filterRate);
		mFilterR[n] = RMSFilterInitWithCutoff(filterCutoff, filterRate);
	}
	
	mSrcStep = dstRate ? srcRate / dstRate : 1.0;
	
	if (mSrcStep < 1.0)
	{
		mTest[0].M = mSrcStep;
		mTest[1].M = mSrcStep;
		// interpolators can be primed with 3 samples before first fetch
		mSrcFraction = 3.0;
		mResampleProc = InterpolateSource;
	}
	else
	if (mSrcStep > 1.0)
	{
		mDecimator = RMSStereoDecimatorInit(1.0 / mSrcStep);
		
		// decimator needs to be primed with 1 sample,
		// and first step should be mSrcStep
		mSrcFraction = 1.0 + mSrcStep;
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

