////////////////////////////////////////////////////////////////////////////////
/*
	RMSRingBuffer
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSRingBuffer.h"


////////////////////////////////////////////////////////////////////////////////

RMSRingBuffer RMSRingBufferNew(UInt32 frameCount)
{
	RMSRingBuffer buffer = {
		.readFraction = 0.0,
		.readStep = 1.0,
		.frameCount = frameCount,
		.dataPtrL = calloc(frameCount, sizeof(float)),
		.dataPtrR = calloc(frameCount, sizeof(float)) };
	
	return buffer;
}

////////////////////////////////////////////////////////////////////////////////

void RMSRingBufferRelease(RMSRingBuffer *buffer)
{
	if (buffer->dataPtrL != nil)
	{ free(buffer->dataPtrL); }
	if (buffer->dataPtrR != nil)
	{ free(buffer->dataPtrR); }
	
	buffer->dataPtrL = nil;
	buffer->dataPtrR = nil;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

static inline void ClearSamples(
	float *dstPtrL,
	float *dstPtrR, UInt32 n)
{
	vDSP_vclr(dstPtrL, 1, n);
	vDSP_vclr(dstPtrR, 1, n);
}

////////////////////////////////////////////////////////////////////////////////

void RMSRingBufferClear(RMSRingBuffer *buffer)
{
	buffer->readIndex = 0;
	buffer->writeIndex = 0;
	ClearSamples(buffer->dataPtrL, buffer->dataPtrR, buffer->frameCount);
}

////////////////////////////////////////////////////////////////////////////////

static inline bool TestSamples(
	float *srcPtrL,
	float *srcPtrR, UInt32 n)
{
	while (n != 0)
	{
		n -= 1;
		if (srcPtrL[n] != srcPtrR[n])
		{ return false; }
	}
	
	return true;
}

////////////////////////////////////////////////////////////////////////////////

bool RMSRingBufferTestSamples(RMSRingBuffer *buffer)
{
	float *srcPtrL = buffer->dataPtrL;
	float *srcPtrR = buffer->dataPtrR;
	
	for (UInt32 n=0; n!=buffer->frameCount; n++)
	{
		if (srcPtrL[n] != srcPtrR[n])
		{
			return false;
		}
	}
	
	return true;
}

////////////////////////////////////////////////////////////////////////////////

RMSAudioBufferList RMSRingBufferGetWriteBufferList(RMSRingBuffer *buffer)
{ return RMSRingBufferGetBufferListAtOffset(buffer, buffer->writeIndex); }

RMSAudioBufferList RMSRingBufferGetBufferListAtOffset(RMSRingBuffer *buffer, UInt64 offset)
{
	UInt32 index = offset & (buffer->frameCount-1);
	UInt32 size = (buffer->frameCount - index) * sizeof(float);
	
	return (RMSAudioBufferList){
		.bufferCount = 2,
		.buffer[0].mNumberChannels = 1,
		.buffer[0].mDataByteSize = size,
		.buffer[0].mData = &buffer->dataPtrL[index],
		.buffer[1].mNumberChannels = 1,
		.buffer[1].mDataByteSize = size,
		.buffer[1].mData = &buffer->dataPtrR[index] };
}

////////////////////////////////////////////////////////////////////////////////

UInt64 RMSRingBufferGetWriteIndex(RMSRingBuffer *buffer)
{ return buffer->writeIndex; }

UInt64 RMSRingBufferMoveWriteIndex(RMSRingBuffer *buffer, UInt64 frameCount)
{ return (buffer->writeIndex += frameCount); }

////////////////////////////////////////////////////////////////////////////////

void RMSRingBufferWriteStereoData(RMSRingBuffer *buffer, AudioBufferList *srcAudio, UInt32 frameCount)
{
	float *srcPtrL = srcAudio->mBuffers[0].mData;
	float *srcPtrR = srcAudio->mBuffers[1].mData;
	
	UInt64 index = buffer->writeIndex & (buffer->frameCount-1);
	float *dstPtrL = &buffer->dataPtrL[index];
	float *dstPtrR = &buffer->dataPtrR[index];
	
	for (UInt32 n=0; n!=frameCount; n++)
	{
		dstPtrL[n] = srcPtrL[n];
		dstPtrR[n] = srcPtrR[n];
		buffer->writeIndex++;
	}
}

////////////////////////////////////////////////////////////////////////////////

void RMSRingBufferSetReadRate(RMSRingBuffer *buffer, double rate)
{
	buffer->readStep = rate;
}

void RMSRingBufferReport(RMSRingBuffer *buffer)
{
	static UInt64 maxDelta = 0;
	UInt64 currentDelta = buffer->writeIndex - buffer->readIndex;
	if (maxDelta < currentDelta)
	{
		maxDelta = currentDelta;
		NSLog(@"Maximum delta: %llu", maxDelta);
	}
	
/*
	static UInt64 avgDelta = 0;
	static UInt64 sumDelta = 0;
	static UInt64 sumCount = 0;
	
	sumDelta += currentDelta;
	sumCount += 1;
	UInt64 A = sumDelta / sumCount;
	if (avgDelta != A)
	{
		avgDelta = A;
		NSLog(@"Average delta: %llu", avgDelta);
	}
*/
}

////////////////////////////////////////////////////////////////////////////////

static void RMSRingBufferReadStereoData0
(RMSRingBuffer *buffer, AudioBufferList *dstAudio, UInt32 frameCount);

void RMSRingBufferReadStereoData
(RMSRingBuffer *buffer, AudioBufferList *dstAudio, UInt32 frameCount)
{
	if (buffer->writeIndex < frameCount) return;
	
	if (buffer->readIndex == 0)
	{ buffer->readIndex = buffer->writeIndex - frameCount; }

	if (buffer->readIndex + frameCount > buffer->writeIndex)
	{
		NSLog(@"%@", @"RMSRingBuffer: readIndex too close to writeIndex!");
		buffer->readIndex = buffer->writeIndex - 2*frameCount;
	}

	if (buffer->readIndex + buffer->frameCount < buffer->writeIndex)
	{
		NSLog(@"%@", @"RMSRingBuffer: readIndex too far from writeIndex!");
		buffer->readIndex = buffer->writeIndex - frameCount;
	}

	RMSRingBufferReport(buffer);
	RMSRingBufferReadStereoData0(buffer, dstAudio, frameCount);
	
	// RMSRingBufferReadStereoData1 is deprecated,
	// use RMSVarispeed for resampling requirements
}

////////////////////////////////////////////////////////////////////////////////

void RMSRingBufferReadStereoData0
(RMSRingBuffer *buffer, AudioBufferList *dstAudio, UInt32 frameCount)
{
	float *srcPtrL = buffer->dataPtrL;
	float *srcPtrR = buffer->dataPtrR;

	float *dstPtrL = dstAudio->mBuffers[0].mData;
	float *dstPtrR = dstAudio->mBuffers[1].mData;

	UInt32 index = buffer->readIndex & (buffer->frameCount-1);
	UInt32 count = buffer->frameCount - index;
	
	if (frameCount <= count)
	{
		RMSCopyFloat32(&srcPtrL[index], dstPtrL, frameCount);
		RMSCopyFloat32(&srcPtrR[index], dstPtrR, frameCount);
		buffer->readIndex += frameCount;
	}
	else
	{
		RMSCopyFloat32(&srcPtrL[index], dstPtrL, count);
		RMSCopyFloat32(&srcPtrR[index], dstPtrR, count);
		buffer->readIndex += count;
		
		frameCount -= count;
		
		RMSCopyFloat32(&srcPtrL[0], &dstPtrL[count], frameCount);
		RMSCopyFloat32(&srcPtrR[0], &dstPtrR[count], frameCount);
		buffer->readIndex += frameCount;
	}
}

////////////////////////////////////////////////////////////////////////////////





