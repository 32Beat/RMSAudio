////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUtilities
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSUtilities.h"
#import <mach/mach_time.h>

////////////////////////////////////////////////////////////////////////////////

static double g_rmsHostToSeconds = 1.0e-9;
static double g_rmsSecondsToHost = 1.0e+9;

////////////////////////////////////////////////////////////////////////////////

static void RMSHostTimeInit(void)
{
	static bool isInitialized = false;
	if (!isInitialized)
	{
		mach_timebase_info_data_t timeInfo;
		mach_timebase_info(&timeInfo);
		if (timeInfo.numer && timeInfo.denom)
		{
			g_rmsHostToSeconds = 1.0e-9 * timeInfo.numer / timeInfo.denom;
			g_rmsSecondsToHost = 1.0e+9 * timeInfo.denom / timeInfo.numer;
		}
		
		isInitialized = true;
	}
}

////////////////////////////////////////////////////////////////////////////////

double RMSCurrentHostTimeInSeconds(void)
{ return RMSHostTimeToSeconds(mach_absolute_time()); }

double RMSHostTimeToSeconds(double hostTime)
{
	RMSHostTimeInit();
	return hostTime * g_rmsHostToSeconds;
}

////////////////////////////////////////////////////////////////////////////////

float RMSRandomFloat(void)
{ return (float)rand()/RAND_MAX; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

AudioBufferList *AudioBufferListCreate32f(bool interleaved, UInt32 channelCount, UInt32 frameCount)
{
	AudioBufferList *bufferListPtr = nil;
	
	if (interleaved)
	{
		UInt32 size = sizeof(UInt32) + sizeof(AudioBuffer);
		AudioBufferList *bufferListPtr = malloc(size);
		
		bufferListPtr->mNumberBuffers = 1;
		RMSAudioBufferPrepare(&bufferListPtr->mBuffers[0], channelCount, frameCount);
	}
	else
	{
		UInt32 size = sizeof(UInt32) + sizeof(AudioBuffer)*channelCount;
		AudioBufferList *bufferListPtr = malloc(size);
		
		bufferListPtr->mNumberBuffers = channelCount;
		for (UInt32 n=0; n!=channelCount; n++)
		{ RMSAudioBufferPrepare(&bufferListPtr->mBuffers[n], 1, frameCount); }
	}
	
	return bufferListPtr;
}

////////////////////////////////////////////////////////////////////////////////

void AudioBufferListRelease(AudioBufferList *bufferListPtr)
{
	if (bufferListPtr != nil)
	{
		for (UInt32 n=0; n!=bufferListPtr->mNumberBuffers; n++)
		{ RMSAudioBufferReleaseMemory(&bufferListPtr->mBuffers[n]); }
		
		free(bufferListPtr);
	}
}

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioBufferPrepare(AudioBuffer *bufferPtr, UInt32 channelCount, UInt32 frameCount)
{
	if (bufferPtr == nil) return paramErr;
	if (channelCount == 0) return paramErr;
	if (frameCount == 0) return paramErr;
	
	bufferPtr->mNumberChannels = channelCount;
	bufferPtr->mDataByteSize = channelCount * frameCount * sizeof(Float32);
	bufferPtr->mData = malloc(bufferPtr->mDataByteSize);
	if (bufferPtr->mData == nil) return memFullErr;
	
	return noErr;
}

////////////////////////////////////////////////////////////////////////////////

void RMSAudioBufferReleaseMemory(AudioBuffer *bufferPtr)
{
	if (bufferPtr != nil)
	{
		if (bufferPtr->mData != nil)
		{
			free(bufferPtr->mData);
			bufferPtr->mData = nil;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

OSStatus RMSStereoBufferListPrepare(RMSStereoBufferList32f *stereoBuffer, UInt32 frameCount)
{
	OSStatus result = noErr;
	
	stereoBuffer->bufferCount = 0;
	
	result = RMSAudioBufferPrepare(&stereoBuffer->buffer[0], 1, frameCount);
	if (result != noErr) return result;
	
	stereoBuffer->bufferCount = 1;
	
	result = RMSAudioBufferPrepare(&stereoBuffer->buffer[1], 1, frameCount);
	if (result != noErr) return result;

	stereoBuffer->bufferCount = 2;
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

void RMSAudioBufferList_ClearBuffers(AudioBufferList *bufferList)
{
	UInt32 n = bufferList->mNumberBuffers;
	while (n != 0)
	{
		n -= 1;
		UInt32 frameCount = bufferList->mBuffers[n].mDataByteSize>>2;
		vDSP_vclr(bufferList->mBuffers[n].mData, 1, frameCount);
	}
}

////////////////////////////////////////////////////////////////////////////////

void RMSAudioBufferList_ClearFrames(AudioBufferList *bufferList, UInt32 frameCount)
{
	UInt32 n = bufferList->mNumberBuffers;
	while (n != 0)
	{
		n -= 1;
		bufferList->mBuffers[n].mDataByteSize = frameCount<<2;
		vDSP_vclr(bufferList->mBuffers[n].mData, 1, frameCount);
	}
}

////////////////////////////////////////////////////////////////////////////////

