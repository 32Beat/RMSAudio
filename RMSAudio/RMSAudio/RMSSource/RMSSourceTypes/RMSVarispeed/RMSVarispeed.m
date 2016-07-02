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

static OSStatus fetchSample(void *rmsObject, UInt64 index, Float32 *resultPtr)
{
	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;

	if (index >= rmsSource->mSrcListIndex+rmsSource->mSrcListCount)
	{
		RMSCallbackInfo info;
		info.frameIndex = index&(~511);
		info.frameCount = 512;
		info.bufferListPtr = (AudioBufferList *)&rmsSource->mSrcList;
		
		OSStatus result = RunRMSSource((__bridge void *)rmsSource->mSource, &info);
		if (result != noErr)
		{}
		
		rmsSource->mSrcListIndex = info.frameIndex;
		rmsSource->mSrcListCount = info.frameCount;
	}
	
	resultPtr[0] = rmsSource->mSrcSamplesL[index&511];
	resultPtr[1] = rmsSource->mSrcSamplesR[index&511];
	
	return noErr;
}


static OSStatus renderCallback(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	__unsafe_unretained RMSVarispeed *rmsSource = \
	(__bridge __unsafe_unretained RMSVarispeed *)rmsObject;
	
	void *source = (__bridge void *)rmsSource->mSource;
	
	OSStatus result = noErr;
	
	Float32 *dstPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *dstPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		Float32 stereoSample[2] = { 0.0, 0.0 };
		fetchSample(rmsObject, rmsSource->mSrcIndex, stereoSample);
		dstPtrL[n] = stereoSample[0];
		dstPtrR[n] = stereoSample[1];
		
		rmsSource->mSrcIndex += rmsSource->mSrcStep;
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
		mSrcList.buffer[0].mData = mSrcSamplesL;
		mSrcList.buffer[1].mNumberChannels = 1;
		mSrcList.buffer[1].mDataByteSize = 516*sizeof(float);
		mSrcList.buffer[1].mData = mSrcSamplesR;
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

