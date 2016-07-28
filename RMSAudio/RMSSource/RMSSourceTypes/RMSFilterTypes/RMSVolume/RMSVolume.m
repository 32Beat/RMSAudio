////////////////////////////////////////////////////////////////////////////////
/*
	RMSVolume
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSVolume.h"
#import <Accelerate/Accelerate.h>


@interface RMSVolume ()
{
	float mGain;
	float mNextVolume;
	float mNextBalance;
	float mLastVolumeL;
	float mLastVolumeR;
}

@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSVolume
////////////////////////////////////////////////////////////////////////////////

static void PCM_ApplyVolume(float V1, float V2, float *dstPtr, UInt32 n)
{
	if (V1 != V2)
	{
		V2 -= V1;
		V2 /= n;
		
		vDSP_vrampmul(dstPtr, 1, &V1, &V2, dstPtr, 1, n);
	}
	else
	if (V1 != 1.0)
	{
		vDSP_vsmul(dstPtr, 1, &V1, dstPtr, 1, n);
	}
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus renderCallback(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	__unsafe_unretained RMSVolume *rmsVolume = \
	(__bridge __unsafe_unretained RMSVolume *)objectPtr;

	/*
		Note: nextBalance & nextVolume need to be local, since
		they may change by the main thread while being used here.
	*/
	float nextVolume = rmsVolume->mNextVolume * pow(10, 0.05*rmsVolume->mGain);
	float nextBalance = rmsVolume->mNextBalance;

	
	float L1 = rmsVolume->mLastVolumeL;
	float L2 = nextVolume;
	if (nextBalance > 0.0)
		L2 *= 1.0 - nextBalance;
	
	PCM_ApplyVolume(L1, L2,
		infoPtr->bufferListPtr->mBuffers[0].mData,
		infoPtr->frameCount);

	rmsVolume->mLastVolumeL = L2;

	
	float R1 = rmsVolume->mLastVolumeR;
	float R2 = nextVolume;
	if (nextBalance < 0.0)
		R2 *= 1.0 + nextBalance;
	
	PCM_ApplyVolume(R1, R2,
		infoPtr->bufferListPtr->mBuffers[1].mData,
		infoPtr->frameCount);
	
	rmsVolume->mLastVolumeR = R2;

	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackProcPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{
	self = [super init];
	if (self != nil)
	{
		mNextVolume = 1.0;
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (float) gain
{ return mGain; }

- (void) setGain:(float)gain
{ mGain = gain; }

////////////////////////////////////////////////////////////////////////////////

- (float) volume
{ return mNextVolume; }

- (void) setVolume:(float)volume
{ mNextVolume = volume; }

////////////////////////////////////////////////////////////////////////////////

- (float) balance
{ return mNextBalance; }

- (void) setBalance:(float)balance
{ mNextBalance = balance; }

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////
