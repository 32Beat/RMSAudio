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

typedef struct RMSStereoInterpolator
{
	double (*fetchProc)(rmsinterpolator_t *ptr, double t);
	rmsinterpolator_t L;
	rmsinterpolator_t R;
}
RMSStereoInterpolator;


static RMSStereoInterpolator RMSStereoInterpolatorInit(void)
{
	return (RMSStereoInterpolator)
	{
		.fetchProc = RMSInterpolatorFetchSpline,
		.L = RMSInterpolatorInit(),
		.R = RMSInterpolatorInit()
	};
}

static void RMSStereoInterpolatorUpdate
(RMSStereoInterpolator *ptr, float *srcPtr)
{
	RMSInterpolatorUpdate(&ptr->L, srcPtr[0]);
	RMSInterpolatorUpdate(&ptr->R, srcPtr[1]);
}

static void RMSStereoInterpolatorUpdateWithParameter
(RMSStereoInterpolator *ptr, float *srcPtr, float P)
{
	RMSInterpolatorUpdateWithParameter(&ptr->L, srcPtr[0], P);
	RMSInterpolatorUpdateWithParameter(&ptr->R, srcPtr[1], P);
}


static void RMSStereoInterpolatorFetch
(RMSStereoInterpolator *ptr, double t, AudioBufferList *dst, UInt32 index)
{
	Float32 *dstPtrL = dst->mBuffers[0].mData;
	dstPtrL[index] = ptr->fetchProc(&ptr->L, t);

	Float32 *dstPtrR = dst->mBuffers[1].mData;
	dstPtrR[index] = ptr->fetchProc(&ptr->R, t);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
/*
	rmsdecimator_t is simply a linear rmsinterpolator with avg built in
*/
typedef struct rmsdecimator_t
{
	double M;
	double S0;
	double S1;
}
rmsdecimator_t;

rmsdecimator_t RMSDecimatorInit(double M)
{ return (rmsdecimator_t){ .M = M, 0.0, 0.0 }; }

/*
	Oddly enough, the running average seems to be slightly quicker than 
	the summing average below, even for 8.5x downsampling...
*/
void RMSDecimatorUpdate(rmsdecimator_t *decimator, float S)
{
	double A = decimator->S1 + (S - decimator->S1) * decimator->M;
	decimator->S0 = decimator->S1;
	decimator->S1 = A;
}

double RMSDecimatorFetch(rmsdecimator_t *decimator, double t)
{ return decimator->S0 + t * (decimator->S1 - decimator->S0); }




void RMSDecimatorUpdateSum(rmsdecimator_t *decimator, float S)
{
	decimator->S0 += decimator->S1;
	decimator->S1 = S;
}

double RMSDecimatorFetchAvg(rmsdecimator_t *decimator, double t)
{
	double S = t * decimator->S1;
	decimator->S0 += S;
	decimator->S1 -= S;

	double D = decimator->S0;
	decimator->S0 = 0.0;

	return decimator->M * D;
}



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
	
	rmsdecimator_t mDecimator[2];
	rmsavg_t mAvg[2];
	rmsfilter_t mFilter[2];

	rmssum_t *mSumL[4];
	rmssum_t *mSumR[4];
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
/*/
////////////////////////////////////////////////////////////////////////////////
/*
static OSStatus ApplyFilter(void *objectPtr, AudioBufferList *bufferListPtr, UInt32 N)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)objectPtr;

	double R = rmsSource->_parameter;
	rmsSource->mTest[0].R = R;
	rmsSource->mTest[1].R = R;

	float *ptrL = bufferListPtr->mBuffers[0].mData;
	RMSTestRun(&rmsSource->mTest[0], ptrL, N);
	
	float *ptrR = bufferListPtr->mBuffers[1].mData;
	RMSTestRun(&rmsSource->mTest[1], ptrR, N);
	
	return result;
}
//*/
////////////////////////////////////////////////////////////////////////////////
//*
static OSStatus ApplyFilter(void *objectPtr, AudioBufferList *bufferListPtr, UInt32 N)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)objectPtr;

	double R = rmsSource->_parameter;
	rmsSource->mFilter[0].R = R;
	rmsSource->mFilter[1].R = R;

	float *ptrL = bufferListPtr->mBuffers[0].mData;
	RMSFilterRun(&rmsSource->mFilter[0], ptrL, N);
	
	float *ptrR = bufferListPtr->mBuffers[1].mData;
	RMSFilterRun(&rmsSource->mFilter[1], ptrR, N);
	
	return result;
}
//*/
////////////////////////////////////////////////////////////////////////////////
/*
static OSStatus ApplyFilter(void *objectPtr, AudioBufferList *bufferListPtr, UInt32 N)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSResampler *rmsSource = \
	(__bridge __unsafe_unretained RMSResampler *)objectPtr;

	float *ptrL = bufferListPtr->mBuffers[0].mData;
	RMSAverageRun(&rmsSource->mAvg[0], ptrL, N);
	
	float *ptrR = bufferListPtr->mBuffers[1].mData;
	RMSAverageRun(&rmsSource->mAvg[1], ptrR, N);
	
	return result;
}
//*/
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
			RMSStereoInterpolatorUpdate \
			(&rmsSource->mInterpolator, src);
//			RMSStereoInterpolatorUpdateWithParameter \
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
			
			RMSDecimatorUpdate(&rmsSource->mDecimator[0], srcPtrL[index&indexMask]);
			RMSDecimatorUpdate(&rmsSource->mDecimator[1], srcPtrR[index&indexMask]);
			
			index += 1;
		}

		// fetch interpolated value
		dstPtrL[n] = RMSDecimatorFetch(&rmsSource->mDecimator[0], srcT);
		dstPtrR[n] = RMSDecimatorFetch(&rmsSource->mDecimator[1], srcT);
		
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
	
	mFilter[0] = RMSFilterInitWithCutoff(filterCutoff, filterRate);
	mFilter[1] = RMSFilterInitWithCutoff(filterCutoff, filterRate);
	
	mSrcStep = dstRate ? srcRate / dstRate : 1.0;
	
	if (mSrcStep < 1.0)
	{
		mFilter[0].M = mSrcStep;
		mFilter[1].M = mSrcStep;
		// interpolators can be primed with 3 samples before first fetch
		mSrcFraction = 3.0;
		mResampleProc = InterpolateSource;
		mInterpolator = RMSStereoInterpolatorInit();
	}
	else
	if (mSrcStep > 1.0)
	{
		mAvg[0] = RMSAverageInitWithSize(mSrcStep);
		mAvg[1] = RMSAverageInitWithSize(mSrcStep);
		mDecimator[0] = RMSDecimatorInit(1.0 / mSrcStep);
		mDecimator[1] = RMSDecimatorInit(1.0 / mSrcStep);
		
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

