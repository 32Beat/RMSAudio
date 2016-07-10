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
	while(n != 0)
	{
		n -= 1;
		dstPtrL[n] = 0.0;
		dstPtrR[n] = 0.0;
	}
}

////////////////////////////////////////////////////////////////////////////////

void RMSRingBufferClear(RMSRingBuffer *buffer)
{
	buffer->readIndex = 0;
	buffer->writeIndex = 0;
	ClearSamples(buffer->dataPtrL, buffer->dataPtrR, buffer->frameCount);
}

////////////////////////////////////////////////////////////////////////////////

RMSStereoBufferList RMSRingBufferGetWriteBufferList(RMSRingBuffer *buffer)
{ return RMSRingBufferGetBufferListAtOffset(buffer, buffer->writeIndex); }

RMSStereoBufferList RMSRingBufferGetBufferListAtOffset(RMSRingBuffer *buffer, UInt64 offset)
{
	UInt32 index = offset & (buffer->frameCount-1);
	
	return (RMSStereoBufferList){
		.bufferCount = 2,
		.buffer[0].mNumberChannels = 1,
		.buffer[0].mDataByteSize = (buffer->frameCount - index) * sizeof(float),
		.buffer[0].mData = &buffer->dataPtrL[index],
		.buffer[1].mNumberChannels = 1,
		.buffer[1].mDataByteSize = (buffer->frameCount - index) * sizeof(float),
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

static void RMSRingBufferReadStereoData0(RMSRingBuffer *buffer, AudioBufferList *dstAudio, UInt32 frameCount);
static void RMSRingBufferReadStereoData1(RMSRingBuffer *buffer, AudioBufferList *dstAudio, UInt32 frameCount);

void RMSRingBufferReadStereoData(RMSRingBuffer *buffer, AudioBufferList *dstAudio, UInt32 frameCount)
{
	UInt32 offset = frameCount<<1;
	if (buffer->writeIndex < offset) return;
	if (buffer->readIndex == 0)
	{ buffer->readIndex = buffer->writeIndex - offset; }

	if (buffer->readIndex + buffer->frameCount < buffer->writeIndex)
	{
		NSLog(@"%@", @"RMSRingBuffer: readIndex too far from writeIndex!");
		return;
	}

	if (buffer->readIndex + frameCount + 1 > buffer->writeIndex)
	{
		NSLog(@"%@", @"RMSRingBuffer: readIndex too close to writeIndex!");
		return;
	}

	RMSRingBufferReport(buffer);
	
	if ((buffer->readFraction == 0.0) && (buffer->readStep == 1.0))
	{ RMSRingBufferReadStereoData0(buffer, dstAudio, frameCount); }
	else
	{ RMSRingBufferReadStereoData1(buffer, dstAudio, frameCount); }
}

////////////////////////////////////////////////////////////////////////////////

static inline void CopySamples(
	const float *srcPtrL, float *dstPtrL,
	const float *srcPtrR, float *dstPtrR, UInt32 n)
{
	while(n != 0)
	{
		n -= 1;
		dstPtrL[n] = srcPtrL[n];
		dstPtrR[n] = srcPtrR[n];
	}
}

////////////////////////////////////////////////////////////////////////////////

void RMSRingBufferReadStereoData0(RMSRingBuffer *buffer, AudioBufferList *dstAudio, UInt32 frameCount)
{
	float *srcPtrL = buffer->dataPtrL;
	float *srcPtrR = buffer->dataPtrR;

	float *dstPtrL = dstAudio->mBuffers[0].mData;
	float *dstPtrR = dstAudio->mBuffers[1].mData;

	UInt32 index = buffer->readIndex & (buffer->frameCount-1);
	
	if (index+frameCount <= buffer->frameCount)
	{
		CopySamples(&srcPtrL[index], dstPtrL, &srcPtrR[index], dstPtrR, frameCount);
	}
	else
	{
		UInt32 n = buffer->frameCount - index;
		CopySamples(&srcPtrL[index], dstPtrL, &srcPtrR[index], dstPtrR, n);
		CopySamples(&srcPtrL[0], &dstPtrL[n], &srcPtrR[0], &dstPtrR[n], frameCount-n);
	}
	
	buffer->readIndex += frameCount;
}

////////////////////////////////////////////////////////////////////////////////

void RMSRingBufferReadStereoData1(RMSRingBuffer *buffer, AudioBufferList *dstAudio, UInt32 frameCount)
{
	float *srcPtrL = buffer->dataPtrL;
	float *srcPtrR = buffer->dataPtrR;

	float *dstPtrL = dstAudio->mBuffers[0].mData;
	float *dstPtrR = dstAudio->mBuffers[1].mData;


	UInt64 index = buffer->readIndex;
	index &= (buffer->frameCount-1);
	float L1 = srcPtrL[index];
	float R1 = srcPtrR[index];
	index += 1;
	index &= (buffer->frameCount-1);
	float L2 = srcPtrL[index];
	float R2 = srcPtrR[index];

	*dstPtrL++ = L1 + buffer->readFraction * (L2 - L1);
	*dstPtrR++ = R1 + buffer->readFraction * (R2 - R1);
	
	
	while (--frameCount != 0)
	{
		buffer->readFraction += buffer->readStep;
		while (buffer->readFraction >= 1.0)
		{
			buffer->readFraction -= 1.0;
			index += 1;
			index &= (buffer->frameCount-1);
			L1 = L2;
			R1 = R2;
			L2 = srcPtrL[index];
			R2 = srcPtrR[index];
			buffer->readIndex++;
		}
		
		*dstPtrL++ = L1 + buffer->readFraction * (L2 - L1);
		*dstPtrR++ = R1 + buffer->readFraction * (R2 - R1);
	}


	buffer->readFraction += buffer->readStep;
	while (buffer->readFraction >= 1.0)
	{
		buffer->readFraction -= 1.0;
		buffer->readIndex++;
	}
}

////////////////////////////////////////////////////////////////////////////////






