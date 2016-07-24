////////////////////////////////////////////////////////////////////////////////
/*
	RMSAutoPan
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAutoPan.h"

@interface RMSAutoPan ()
{
	// Set by main thread
	//Float64 mSampleRate; <--- in RMSSource
	Float64 mResponseTime;
	
	// Set by audio thread
	Float64 mEngineRate;
	Float64 mEngineTime;
	Float64 mAvgM;
	Float64 mAvgL;
	Float64 mAvgR;
	Float64 mAvgB;
}



@end

@implementation RMSAutoPan

static OSStatus renderCallback(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	__unsafe_unretained RMSAutoPan *rmsObject = \
	(__bridge __unsafe_unretained RMSAutoPan *)objectPtr;
	
	// Test for parameter changes
	Float64 sampleRate = rmsObject->mSampleRate;
	Float64 responseTime = rmsObject->mResponseTime;
	if ((rmsObject->mEngineRate != sampleRate)||
		(rmsObject->mEngineTime != responseTime))
	{
		rmsObject->mEngineRate = sampleRate;
		rmsObject->mEngineTime = responseTime;
		
		rmsObject->mAvgM = 1.0 / (1.0 + responseTime * sampleRate);
	}
	
	
	Float64 avgM = rmsObject->mAvgM;
	Float64 avgL = rmsObject->mAvgL;
	Float64 avgR = rmsObject->mAvgR;
	Float64 avgB = rmsObject->mAvgB;
	
	Float32 *srcPtrL = infoPtr->bufferListPtr->mBuffers[0].mData;
	Float32 *srcPtrR = infoPtr->bufferListPtr->mBuffers[1].mData;
	
	for (UInt32 n=0; n!=infoPtr->frameCount; n++)
	{
		Float64 L = srcPtrL[n];
		Float64 R = srcPtrR[n];

		if (avgB < 0.0)
		srcPtrL[n] = (L *= 1.0+avgB);
		else
		if (avgB > 0.0)
		srcPtrR[n] = (R *= 1.0-avgB);

//*
		L = fabs(L);
		R = fabs(R);
		avgL += avgM * (L - avgL);
		avgR += avgM * (R - avgR);
		avgB += avgM * (avgR - avgL);
		if (avgB > +1.0) avgB = +1.0;
		if (avgB < -1.0) avgB = -1.0;
		rmsObject->mAvgB = avgB;
//*/
	}
	
	rmsObject->mAvgL = avgL;
	rmsObject->mAvgR = avgR;
	rmsObject->mAvgB = avgB;
	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{
	self = [super init];
	if (self != nil)
	{
		[self setSampleRate:44100.0];
		[self setResponseTime:.25];
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void) setResponseTime:(NSTimeInterval)responseTime
{ mResponseTime = responseTime; }

////////////////////////////////////////////////////////////////////////////////

- (float) correctionBalance
{ return -mAvgB; }

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////




