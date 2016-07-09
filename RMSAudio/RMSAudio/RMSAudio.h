////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudio
	
	Created by 32BT on 23/06/16.
	Copyright © 2016 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import <Cocoa/Cocoa.h>

#import "RMSCallback.h"
#import "RMSSource.h"

#import "RMSAudioUnit.h"
#import "RMSAudioUnitUtilities.h"
#import "RMSAudioUnitFilePlayer.h"
#import "RMSAudioUnitVarispeed.h"
#import "RMSAudioUnitPlatformIO.h"
//#import "RMSInput.h"
#import "RMSOutput.h"

#import "RMSVarispeed.h"

#import "RMSSampleMonitor.h"



#import "RMSUtilities.h"
#import "RMSTimer.h"

#import "rmsbuffer.h"
#import "rmslevels.h"



CF_ENUM(AudioFormatFlags)
{
	kAudioFormatFlagIsNativeEndian = kAudioFormatFlagsNativeEndian
};

static const AudioStreamBasicDescription RMSPreferredAudioFormat =
{
	.mSampleRate 		= 0.0,
	.mFormatID 			= kAudioFormatLinearPCM,
	.mFormatFlags 		=
		kAudioFormatFlagIsFloat | \
		kAudioFormatFlagIsNativeEndian | \
		kAudioFormatFlagIsPacked | \
		kAudioFormatFlagIsNonInterleaved,
	.mBytesPerPacket 	= sizeof(float),
	.mFramesPerPacket 	= 1,
	.mBytesPerFrame 	= sizeof(float),
	.mChannelsPerFrame 	= 2,
	.mBitsPerChannel 	= sizeof(float) * 8,
	.mReserved 			= 0
};


