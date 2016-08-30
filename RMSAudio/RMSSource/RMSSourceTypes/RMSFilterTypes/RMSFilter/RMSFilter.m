////////////////////////////////////////////////////////////////////////////////
/*
	RMSFilter
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSFilter.h"
#import "rmsfilter_t.h"


////////////////////////////////////////////////////////////////////////////////

@interface RMSFilter ()
{
	rmsfilter_t mFilter[2];
}
@end

////////////////////////////////////////////////////////////////////////////////
@implementation RMSFilter
////////////////////////////////////////////////////////////////////////////////

static OSStatus RunFilter(void *objectPtr, AudioBufferList *bufferListPtr, UInt32 N)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSFilter *rmsSource = \
	(__bridge __unsafe_unretained RMSFilter *)objectPtr;

	double M = rmsSource->_cutOff;
	double R = rmsSource->_resonance;
	
	if (rmsSource->_active == YES)
	{
		float *ptrL = bufferListPtr->mBuffers[0].mData;
		//RMSFilterRun(&rmsSource->mFilter[0], ptrL, N);
		RMSFilterRunWithAdjustment(&rmsSource->mFilter[0], M, R, ptrL, N);
		
		float *ptrR = bufferListPtr->mBuffers[1].mData;
		//RMSFilterRun(&rmsSource->mFilter[1], ptrR, N);
		RMSFilterRunWithAdjustment(&rmsSource->mFilter[1], M, R, ptrR, N);
	}
	
	rmsSource->mFilter[0].M = M;
	rmsSource->mFilter[1].M = M;
	rmsSource->mFilter[0].R = R;
	rmsSource->mFilter[1].R = R;
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus renderCallback(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = RunRMSSourceChain(objectPtr, infoPtr);

	if (result == noErr)
	{ RunFilter(objectPtr, infoPtr->bufferListPtr, infoPtr->frameCount); }
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackProcPtr
{ return renderCallback; }

////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////

+ (instancetype) instanceWithSource:(RMSSource *)source
{ return [[self alloc] initWithSource:source]; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{ return [self initWithSource:nil]; }

- (instancetype) initWithSource:(RMSSource *)source
{
	self = [super init];
	if (self != nil)
	{
		if (source != nil)
		{
			self.sampleRate = source.sampleRate;
			[self setSource:source];
		}

		self.active = YES;
		mFilter[0] = RMSFilterInitWithMultiplier(1.0);
		mFilter[1] = RMSFilterInitWithMultiplier(1.0);
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////
