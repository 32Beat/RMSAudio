////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUtilities
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <Accelerate/Accelerate.h>

#ifndef RMSAudioUtilities_h
#define RMSAudioUtilities_h

#ifndef __MACERRORS__
static const OSStatus paramErr = -50;
static const OSStatus memFullErr = -108;
#endif


double RMSCurrentHostTimeInSeconds(void);
double RMSHostTimeToSeconds(double hostTime);



////////////////////////////////////////////////////////////////////////////////
// We only do non-interleaved 32bit float buffers

AudioBufferList *AudioBufferListCreate32f
(UInt32 bufferCount, UInt32 frameCount, UInt32 channelCount);
void AudioBufferListRelease(AudioBufferList *bufferListPtr);

OSStatus RMSAudioBufferPrepare
(AudioBuffer *bufferPtr, UInt32 frameCount);
OSStatus RMSAudioBufferPrepareWithChannels
(AudioBuffer *bufferPtr, UInt32 frameCount, UInt32 channelCount);
void RMSAudioBufferReleaseMemory(AudioBuffer *bufferPtr);

////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioBufferList
	------------------
	Convenience structure to allow stackbased AudioBufferList
	
	Using union for easy/readable access to AudioBufferList, for example:

		&srcBuffers->list
		&srcList->buffers
		&src->bufferList
	
*/
typedef union RMSAudioBufferList
{
	AudioBufferList list;
	AudioBufferList buffers;
	AudioBufferList bufferList;
	struct
	{
		UInt32      bufferCount;
		AudioBuffer buffer[2];
	};
}
RMSAudioBufferList;

////////////////////////////////////////////////////////////////////////////////

void RMSAudioBufferList_ClearBuffers(AudioBufferList *bufferList);

/*
	Following call is important: 
	it sets frameCount frames to 0.0, and sets mDataByteSize accordingly
	Some AudioUnits may adjust the AudioBuffer info, particularly the 
	mDataByteSize field, which obviously doesn't go well with global 
	bufferList pointers.
*/
void RMSAudioBufferList_ClearFrames(AudioBufferList *bufferList, UInt32 frameCount);

////////////////////////////////////////////////////////////////////////////////

UInt32 RMSAudioBufferList_GetTotalChannelCount(AudioBufferList *bufferList);


static inline void PCM_CopyStereo(
	float *srcPtrL, float *srcPtrR,
	float *dstPtrL, float *dstPtrR, UInt32 n)
{
	while (n != 0)
	{
		n -= 1;
		dstPtrL[n] = srcPtrL[n];
		dstPtrR[n] = srcPtrR[n];
	}
}

static inline void AudioBufferList_CopyBuffers
(const AudioBufferList *srcListPtr, AudioBufferList *dstListPtr, UInt32 frameCount)
{
	PCM_CopyStereo(
		srcListPtr->mBuffers[0].mData, srcListPtr->mBuffers[1].mData,
		dstListPtr->mBuffers[0].mData, dstListPtr->mBuffers[1].mData, frameCount);
}


static inline OSStatus RunAURenderCallback(
	const AURenderCallbackStruct 	*callbackInfo,
	AudioUnitRenderActionFlags 		*ioActionFlags,
	const AudioTimeStamp 			*inTimeStamp,
	UInt32							inBusNumber,
	UInt32							inNumberFrames,
	AudioBufferList 				*ioData)
{
	if (callbackInfo == nil) return paramErr;
	if (callbackInfo->inputProc == nil) return paramErr;
	
	return callbackInfo->inputProc(callbackInfo->inputProcRefCon,
	ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
}

#endif /* RMSAudioUtilities_h */




