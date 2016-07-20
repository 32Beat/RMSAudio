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

AudioBufferList *AudioBufferListCreate32f
(UInt32 bufferCount, UInt32 frameCount, UInt32 channelCount)
{
	UInt32 size = sizeof(UInt32) + sizeof(AudioBuffer) * bufferCount;
	AudioBufferList *bufferListPtr = malloc(size);
	
	if (bufferListPtr != nil)
	{
		bufferListPtr->mNumberBuffers = bufferCount;
		for (UInt32 n=0; n!=bufferCount; n++)
		{
			RMSAudioBufferPrepareWithChannels
			(&bufferListPtr->mBuffers[n], frameCount, channelCount);
		}
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

OSStatus RMSAudioBufferPrepare
(AudioBuffer *bufferPtr, UInt32 frameCount)
{ return RMSAudioBufferPrepareWithChannels(bufferPtr, frameCount, 1); }

////////////////////////////////////////////////////////////////////////////////

OSStatus RMSAudioBufferPrepareWithChannels
(AudioBuffer *bufferPtr, UInt32 frameCount, UInt32 channelCount)
{
	if (bufferPtr == nil) return paramErr;
	if (frameCount == 0) return paramErr;
	if (channelCount == 0) return paramErr;
	
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

OSStatus RMSAudioBufferListPrepare
(AudioBufferList *bufferList, UInt32 bufferCount, UInt32 frameCount)
{
	if (bufferList == nil) return paramErr;
	if (bufferCount == 0) return paramErr;
	if (frameCount == 0) return paramErr;

	bufferList->mNumberBuffers = 0;
	for (UInt32 n=0; n!=bufferCount; n++)
	{
		OSStatus result = RMSAudioBufferPrepare(&bufferList->mBuffers[n], frameCount);
		if (result != noErr) return result;
	
		bufferList->mNumberBuffers++;
	}
	
	return noErr;
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

UInt32 RMSAudioBufferList_GetTotalChannelCount(AudioBufferList *bufferList)
{
	UInt32 channelCount = 0;
	
	UInt32 n = bufferList->mNumberBuffers;
	while (n != 0)
	{
		n -= 1;
		channelCount += bufferList->mBuffers[n].mNumberChannels;
	}
	
	return channelCount;
}

////////////////////////////////////////////////////////////////////////////////

