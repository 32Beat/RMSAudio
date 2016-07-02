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

static OSStatus fetchSampleNN(void *rmsObject, UInt64 index, Float32 *ptrL, Float32 *ptrR)
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
		
		result = RunRMSSource((__bridge void *)rmsSource->mSource, &info);
		if (result != noErr)
		{}
		
		rmsSource->mSrcListIndex = info.frameIndex;
		rmsSource->mSrcListCount = info.frameCount;
	}
	
	index &= 511;
	index += 2;
	
	ptrL[0] = rmsSource->mSrcSamplesL[index];
	ptrR[0] = rmsSource->mSrcSamplesR[index];
	
	return result;
}


static OSStatus renderCallback(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;
	
	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		fetchSampleNN(rmsObject, round(rmsSource->mSrcIndex), dstPtrL, dstPtrR);
		rmsSource->mSrcIndex += rmsSource->mSrcStep;
		dstPtrL += 1;
		dstPtrR += 1;
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
		mSrcList.buffer[0].mDataByteSize = 516*sizeof(float);
		mSrcList.buffer[0].mData = mSrcSamplesL+4; // 2+2 padding
		mSrcList.buffer[1].mNumberChannels = 1;
		mSrcList.buffer[1].mDataByteSize = 516*sizeof(float);
		mSrcList.buffer[1].mData = mSrcSamplesR+4; // 2+2 padding
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
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////

