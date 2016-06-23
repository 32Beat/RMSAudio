////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUnitFilePlayer
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSAudioUnitFilePlayer.h"
#import "RMSAudio.h"


@interface RMSAudioUnitFilePlayer ()
{
	AudioFileID mFileID;
	AudioStreamBasicDescription mFileFormat;
	
	UInt64 mByteCount;
	UInt64 mPacketCount;
	
	Float64 mEstimatedDuration;
}

@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSAudioUnitFilePlayer
////////////////////////////////////////////////////////////////////////////////

+ (NSArray *) readableTypes
{
	CFArrayRef arrayPtr = nil;
	
	UInt32 size = sizeof(CFArrayRef);
	OSStatus result = AudioFileGetGlobalInfo
	(kAudioFileGlobalInfo_AllExtensions, 0, nil, &size, &arrayPtr);
	if (result != noErr)
	{}
	
	return (__bridge_transfer NSArray *)arrayPtr;
}

////////////////////////////////////////////////////////////////////////////////

+ (AudioComponentDescription) componentDescription
{
	return
	(AudioComponentDescription) {
		.componentType = kAudioUnitType_Generator,
		.componentSubType = kAudioUnitSubType_AudioFilePlayer,
		.componentManufacturer = kAudioUnitManufacturer_Apple,
		.componentFlags = 0,
		.componentFlagsMask = 0 };
}

////////////////////////////////////////////////////////////////////////////////

+ (instancetype) instanceWithURL:(NSURL *)fileURL
{ return [[self alloc] initWithURL:fileURL]; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) initWithURL:(NSURL *)fileURL
{
	self = [super init];
	if (self != nil)
	{
		OSStatus result = [self setAudioFileURL:fileURL];
		if (result != noErr)
		{
			return nil;
		}
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) setAudioFileURL:(NSURL *)fileURL
{
	// Open audio file
	OSStatus result = AudioFileOpenURL((__bridge CFURLRef)fileURL, kAudioFileReadPermission, 0, &mFileID);
	if (result != noErr)
	{ NSLog(@"AudioFileOpenURL returned %d", result); return result; }

	// Add corresponding fileID to file player
	result = AudioUnitSetProperty(mAudioUnit, kAudioUnitProperty_ScheduledFileIDs,
	kAudioUnitScope_Global, 0, &mFileID, sizeof(mFileID));
	if (result != noErr)
	{ NSLog(@"Failed to set file ID: %d", result); return result; }


	UInt32 size = sizeof(mFileFormat);
	result = AudioFileGetProperty(mFileID, kAudioFilePropertyDataFormat, &size, &mFileFormat);
	if (result != noErr)
	{ NSLog(@"AudioFileGetProperty returned %d", result); return result; }
	
	
	[self setResultFormat:&RMSPreferredAudioFormat];
	// self->setSampleRate does nothing, as it is determined by the file
	[super setSampleRate:mFileFormat.mSampleRate];


	result = [self initializeAudioUnit];
	if (result != noErr)
	{ NSLog(@"RMSAudioUnitFilePlayer: initializing audiounit returned %d", result); return result; }


	// Set absolute start time (-1 = asap)
	AudioTimeStamp startTime = { .mSampleTime = -1, .mFlags = kAudioTimeStampSampleTimeValid };
	result = AudioUnitSetProperty(mAudioUnit, kAudioUnitProperty_ScheduleStartTimeStamp,
	kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
	if (result != noErr)
	{ NSLog(@"RMSAudioUnitFilePlayer: setting starttime returned %d", result); return result; }


	// Set play range within file ([0, -1] = entire file)
	ScheduledAudioFileRegion region = {
		.mTimeStamp = { .mFlags = kAudioTimeStampSampleTimeValid },
		.mCompletionProc = nil,
		.mCompletionProcUserData = nil,
		.mAudioFile = mFileID,
		.mLoopCount = (-1),
		.mStartFrame = 0,
		.mFramesToPlay = (-1)
	};

	result = AudioUnitSetProperty(mAudioUnit, kAudioUnitProperty_ScheduledFileRegion,
	kAudioUnitScope_Global, 0, &region, sizeof(region));
	if (result != noErr)
	{ NSLog(@"RMSAudioUnitFilePlayer: scheduling playregion returned %d", result); return result; }


	// Priming requires the audiounit to be initialized
	UInt32 primeFrames = 0; // default 0x10000
	result = AudioUnitSetProperty(mAudioUnit, kAudioUnitProperty_ScheduledFilePrime,
	kAudioUnitScope_Global, 0, &primeFrames, sizeof(primeFrames));
	if (result != noErr)
	{ NSLog(@"RMSAudioUnitFilePlayer: priming audiounit returned %d", result); return result; }

	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	if (mFileID != nil)
	AudioFileClose(mFileID);
}

////////////////////////////////////////////////////////////////////////////////
// self->setSampleRate does nothing, as it is determined by the file

- (void) setSampleRate:(Float64)sampleRate
{
	if (mSampleRate != sampleRate)
	{
		NSLog(@"RMSAudioUnitFilePlayer: attempt to set incompatible sampleRate: %.1f", sampleRate);
	}
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) readSizeInfo
{
	OSStatus result = noErr;
	
	UInt32 size = sizeof(Float64);
	result = AudioFileGetProperty(mFileID, kAudioFilePropertyEstimatedDuration,
	&size, &mEstimatedDuration);

	size = sizeof(UInt64);
	result = AudioFileGetProperty(mFileID, kAudioFilePropertyAudioDataByteCount,
	&size, &mByteCount);

	size = sizeof(UInt64);
	result = AudioFileGetProperty(mFileID, kAudioFilePropertyAudioDataPacketCount,
	&size, &mPacketCount);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) getCurrentPlayTime:(AudioTimeStamp *)timeStamp
{
	UInt32 size = sizeof(AudioTimeStamp);
	return AudioUnitGetProperty(mAudioUnit, kAudioUnitProperty_CurrentPlayTime,
	kAudioUnitScope_Global, 0, timeStamp, &size);
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////




