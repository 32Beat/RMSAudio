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

static OSStatus ApplyFilter(void *objectPtr, AudioBufferList *bufferListPtr, UInt32 N)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSFilter *rmsSource = \
	(__bridge __unsafe_unretained RMSFilter *)objectPtr;

	double M = rmsSource->_cutOff;
	rmsSource->mFilter[0].M = M;
	rmsSource->mFilter[1].M = M;
	double R = rmsSource->_resonance;
	rmsSource->mFilter[0].R = R;
	rmsSource->mFilter[1].R = R;
	
	float *ptrL = bufferListPtr->mBuffers[0].mData;
	RMSFilterRun(&rmsSource->mFilter[0], ptrL, N);
	
	float *ptrR = bufferListPtr->mBuffers[1].mData;
	RMSFilterRun(&rmsSource->mFilter[1], ptrR, N);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

static OSStatus renderCallback(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;

	__unsafe_unretained RMSFilter *rmsSource = \
	(__bridge __unsafe_unretained RMSFilter *)objectPtr;
	
	void *source = RMSSourceGetSource(objectPtr);
	if (source != nil)
	{ result = RunRMSSourceChain(objectPtr, infoPtr); }

	if (rmsSource->_active)
	{ ApplyFilter(objectPtr, infoPtr->bufferListPtr, infoPtr->frameCount); }
	
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
		{ [self setSource:source]; }

		self.shouldUpdateSource = YES;

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
