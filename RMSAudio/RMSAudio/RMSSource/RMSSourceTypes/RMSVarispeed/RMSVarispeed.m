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

static void RMSStereoInterpolatorUpdate
(RMSStereoInterpolator *ptr, RMSAudioBufferList *src, UInt32 index)
{
	Float32 *srcPtrL = src->buffer[0].mData;
	RMSResamplerWrite(&ptr->L, srcPtrL[index]);

	Float32 *srcPtrR = src->buffer[1].mData;
	RMSResamplerWrite(&ptr->R, srcPtrR[index]);
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



@interface RMSVarispeed ()
{
	UInt64 mSrcIndex;
	Float64 mSrcFraction;
	Float64 mSrcStep;
	
	RMSCallbackProcPtr mResampleProc;
	RMSStereoInterpolator mInterpolator;
	
	UInt64 mSrcListIndex;
	UInt64 mSrcListCount;
	RMSAudioBufferList mSrcList;
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

	// TODO: need better var naming
	UInt64 srcIndex = rmsSource->mSrcIndex;
	Float64 srcFraction = rmsSource->mSrcFraction;
	const Float64 srcStep = rmsSource->mSrcStep;

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

		srcIndex += 2;
	}

	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next src sample is required
		if (srcFraction >= 1.0)
		{
			// update src index
			srcIndex += 1;
			
			// test if next buffer is required
			if ((srcIndex & 511) == 0)
			{
				result = RefreshBuffer(rmsObject, srcIndex);
				if (result != noErr) return result;
			}
			
			// add new sample to interpolator
			RMSStereoInterpolatorUpdate
			(&rmsSource->mInterpolator, &rmsSource->mSrcList, srcIndex&511);
			
			// reset fraction
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
			L += (1.0-x) * rmsSource->mSrcSamplesL[index&511];
			R += (1.0-x) * rmsSource->mSrcSamplesR[index&511];
			x -= 1.0;
			
			index += 1;
		}
		
		x += s;
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
	}

	rmsSource->mSrcIndex = index;
	rmsSource->mSrcFraction = x;
	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus DecimateSourceByN(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;


	UInt64 index = rmsSource->mSrcIndex & 511;
	Float32 *srcPtrL = rmsSource->mSrcSamplesL;
	Float32 *srcPtrR = rmsSource->mSrcSamplesR;

	UInt32 N = rmsSource->mSrcStep;
//	float m = 1.0 / N;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		// test if next buffer is required
		if ((index &= 511) == 0)
		{
			result = RefreshBuffer(rmsObject, index);
			if (result != noErr) return result;
		}
/*
		dstPtrL[n] = m*vSsum(N, (vFloat *)&srcPtrL[index]);
		dstPtrR[n] = m*vSsum(N, (vFloat *)&srcPtrR[index]);
/*/
		vDSP_meanv(&srcPtrL[index], 1, &dstPtrL[n], N);
		vDSP_meanv(&srcPtrR[index], 1, &dstPtrR[n], N);
//*/
		index += N;
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
	{ result = RunRMSSource(RMSSourceGetSource(rmsObject), infoPtr); }
	
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
	if (mSrcStep == 1.0)
	mResampleProc = nil;
	else
	if (mSrcStep < 1.0)
	mResampleProc = InterpolateSource;
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////

