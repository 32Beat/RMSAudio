////////////////////////////////////////////////////////////////////////////////
/*
	RMSRingBuffer
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#ifndef RMSRingBuffer_h
#define RMSRingBuffer_h

#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>
#import "RMSUtilities.h"

typedef struct RMSRingBuffer
{
	UInt64 readIndex;
	double readFraction;
	double readStep;
	
	UInt64 writeIndex;

	UInt32 frameCount;
	float *dataPtrL;
	float *dataPtrR;
}
RMSRingBuffer;

RMSRingBuffer RMSRingBufferNew(UInt32 frameCount);
void RMSRingBufferRelease(RMSRingBuffer *buffer);

void RMSRingBufferClear(RMSRingBuffer *buffer);
bool RMSRingBufferTestSamples(RMSRingBuffer *buffer);

RMSAudioBufferList RMSRingBufferGetWriteBufferList(RMSRingBuffer *buffer);
RMSAudioBufferList RMSRingBufferGetBufferListAtOffset(RMSRingBuffer *buffer, UInt64 offset);
UInt64 RMSRingBufferMoveWriteIndex(RMSRingBuffer *buffer, UInt64 frameCount);

void RMSRingBufferSetReadRate(RMSRingBuffer *buffer, double rate);

void RMSRingBufferWriteStereoData(RMSRingBuffer *buffer, AudioBufferList *srcAudio, UInt32 frameCount);
void RMSRingBufferReadStereoData(RMSRingBuffer *buffer, AudioBufferList *dstAudio, UInt32 frameCount);


#endif /* RMSRingBuffer_h */





