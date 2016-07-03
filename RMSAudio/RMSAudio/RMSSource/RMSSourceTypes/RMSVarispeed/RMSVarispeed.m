////////////////////////////////////////////////////////////////////////////////
/*
	RMSVarispeed
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSVarispeed.h"
#import "RMSUtilities.h"



@interface RMSVarispeed ()
{
	Float64 mSrcIndex;
	Float64 mSrcStep;
	
	UInt64 mSrcListIndex;
	UInt64 mSrcListCount;
	RMSStereoBufferList mSrcList;
	Float32 mSrcSamplesL[516];
	Float32 mSrcSamplesR[516];
}
@end




////////////////////////////////////////////////////////////////////////////////
@implementation RMSVarispeed
////////////////////////////////////////////////////////////////////////////////

static OSStatus PrepareFetch(void *rmsObject, UInt64 index)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;
	
	if (index >= rmsSource->mSrcListIndex+rmsSource->mSrcListCount)
	{
		rmsSource->mSrcSamplesL[0] = rmsSource->mSrcSamplesL[512];
		rmsSource->mSrcSamplesL[1] = rmsSource->mSrcSamplesL[513];
		rmsSource->mSrcSamplesL[2] = rmsSource->mSrcSamplesL[514];
		rmsSource->mSrcSamplesL[3] = rmsSource->mSrcSamplesL[515];

		rmsSource->mSrcSamplesR[0] = rmsSource->mSrcSamplesR[512];
		rmsSource->mSrcSamplesR[1] = rmsSource->mSrcSamplesR[513];
		rmsSource->mSrcSamplesR[2] = rmsSource->mSrcSamplesR[514];
		rmsSource->mSrcSamplesR[3] = rmsSource->mSrcSamplesR[515];
		
		RMSCallbackInfo info;
		info.frameIndex = index&(~511);
		info.frameCount = 512;
		info.bufferListPtr = (AudioBufferList *)&rmsSource->mSrcList;

		rmsSource->mSrcList.buffer[0].mData = &rmsSource->mSrcSamplesL[4]; // 2+2 padding
		rmsSource->mSrcList.buffer[1].mData = &rmsSource->mSrcSamplesR[4]; // 2+2 padding
		
		result = RunRMSSource((__bridge void *)rmsSource->mSource, &info);
		if (result != noErr)
		{}
		
		rmsSource->mSrcListIndex = info.frameIndex;
		rmsSource->mSrcListCount = info.frameCount;
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus DecimateSource(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;

	Float64 srcIndex = rmsSource->mSrcIndex;
	Float64 srcStep = rmsSource->mSrcStep;

	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		Float64 L = 0.0;
		Float64 R = 0.0;
		Float64 s = 0.0;
		
		UInt64 index = srcIndex;

		Float64 x = srcIndex - trunc(srcIndex);
		if (x > 0.0)
		{
			result = PrepareFetch(rmsObject, index);
			if (result != noErr) return result;

			L += (1.0-x) * rmsSource->mSrcSamplesL[index&511];
			R += (1.0-x) * rmsSource->mSrcSamplesR[index&511];
			s += (1.0-x);
			x -= 1.0;
		}

		x += srcStep;
		while (x >= 1.0)
		{
			index += 1;
			
			result = PrepareFetch(rmsObject, index);
			if (result != noErr) return result;

			L += rmsSource->mSrcSamplesL[index&511];
			R += rmsSource->mSrcSamplesR[index&511];
			s += 1.0;
			x -= 1.0;
		}

		if (x > 0.0)
		{
			index += 1;
			
			result = PrepareFetch(rmsObject, index);
			if (result != noErr) return result;

			L += x * rmsSource->mSrcSamplesL[index&511];
			R += x * rmsSource->mSrcSamplesR[index&511];
			s += x;
		}

		dstPtrL[n] = L/s;
		dstPtrR[n] = R/s;
		
		srcIndex += srcStep;
	}

	rmsSource->mSrcIndex = srcIndex;
	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////


static inline double Bezier(Float32 *srcPtr, Float64 t)
{
	double P0 = srcPtr[0];
	double P1 = srcPtr[1];
	double P2 = srcPtr[2];
	double P3 = srcPtr[3];
	double C1 = P1+0.25*(P2-P0);
	double C2 = P2-0.25*(P3-P1);
	
	P1 += t * (C1-P1);
	C1 += t * (C2-C1);
	C2 += t * (P2-C2);

	P1 += t * (C1-P1);
	C1 += t * (C2-C1);

	P1 += t * (C1-P1);
	
	return P1;
}

////////////////////////////////////////////////////////////////////////////////

static void interpolate(
AudioBufferList *srcList, double srcIndex,
AudioBufferList *dstList, UInt64 dstIndex, UInt32 bufferCount)
{
	SInt64 index = srcIndex;
	index &= 511;
	index -= 2; // offset for srcList
	index -= 1; // offset for Bezier

	double t = srcIndex - trunc(srcIndex);
	
	for (UInt32 n=0; n!=bufferCount; n++)
	{
		Float32 *srcPtr = srcList->mBuffers[n].mData;
		Float32 *dstPtr = dstList->mBuffers[n].mData;
		
		dstPtr[dstIndex] = Bezier(&srcPtr[index], t);
	}
}

static OSStatus InterpolateSource(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	Float64 srcIndex = rmsSource->mSrcIndex;
	Float64 srcStep = rmsSource->mSrcStep;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		UInt64 index = srcIndex;
		
		result = PrepareFetch(rmsObject, index);
		if (result != noErr) return result;
		
		interpolate((AudioBufferList *)&rmsSource->mSrcList, srcIndex, infoPtr->bufferListPtr, n, 2);
		
		srcIndex += srcStep;
	}
	
	rmsSource->mSrcIndex = srcIndex;
	
	return result;
}


static OSStatus renderCallback(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;
	
	if (rmsSource->mSrcStep < 1.0)
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
		mSrcList.buffer[0].mData = &mSrcSamplesL[4]; // 2+2 padding
		mSrcList.buffer[1].mNumberChannels = 1;
		mSrcList.buffer[1].mDataByteSize = 512*sizeof(float);
		mSrcList.buffer[1].mData = &mSrcSamplesR[4]; // 2+2 padding
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
	if ((mSrcIndex == 0.0) && (mSrcStep < 1.0))
	{
		mSrcIndex += 0.5 * mSrcStep;
	}
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////

