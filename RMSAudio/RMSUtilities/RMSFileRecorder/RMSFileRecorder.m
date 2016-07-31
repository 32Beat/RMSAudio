////////////////////////////////////////////////////////////////////////////////
/*
	RMSFileRecorder
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSFileRecorder.h"
#import "RMSAudio.h"
#import <AudioToolbox/AudioToolbox.h>

@interface RMSFileRecorder ()
{
	ExtAudioFileRef mFileRef;
	
	UInt64 mSliceIndex;
}

@end



static const AudioStreamBasicDescription RMSDefaultOutputFileFormat =
{
	.mSampleRate 		= 44100.0,
	.mFormatID 			= kAudioFormatLinearPCM,
	.mFormatFlags 		=
		kAudioFormatFlagIsFloat | \
		kAudioFormatFlagIsNativeEndian | \
		kAudioFormatFlagIsPacked,
	.mBytesPerPacket 	= 2 * sizeof(float),
	.mFramesPerPacket 	= 1,
	.mBytesPerFrame 	= 2 * sizeof(float),
	.mChannelsPerFrame 	= 2,
	.mBitsPerChannel 	= 8 * sizeof(float),
	.mReserved 			= 0
};



////////////////////////////////////////////////////////////////////////////////
@implementation RMSFileRecorder
////////////////////////////////////////////////////////////////////////////////

+ (instancetype) instanceWithURL:(NSURL *)url
{ return [self instanceWithURL:url fileType:kAudioFileCAFType]; }

+ (instancetype) instanceWithURL:(NSURL *)url fileType:(AudioFileTypeID)typeID
{ return [[self alloc] initWithURL:url fileType:typeID]; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) initWithURL:(NSURL *)url fileType:(AudioFileTypeID)typeID
{
	self = [super init];
	if (self != nil)
	{
		_url = url;
		
		AudioStreamBasicDescription fileFormat = RMSDefaultOutputFileFormat;
		
		OSStatus error = ExtAudioFileCreateWithURL(
			(__bridge CFURLRef)url,
			typeID,
			&fileFormat,
			nil,
			kAudioFileFlags_EraseFile,
			&mFileRef);
		
		if (error != noErr)
		{ return nil; }

		error = ExtAudioFileSetProperty(mFileRef,
					kExtAudioFileProperty_ClientDataFormat,
					sizeof(RMSPreferredAudioFormat),
					&RMSPreferredAudioFormat);
		
		if (error != noErr)
		{ return nil; }
		
		ExtAudioFileWriteAsync(mFileRef, 0, nil);
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	if (mFileRef != nil)
	{
		ExtAudioFileDispose(mFileRef);
		mFileRef = nil;
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (OSStatus) updateWithMonitor:(RMSSampleMonitor *)sampleMonitor
{
	OSStatus error = noErr;
	
	rmsrange_t R = sampleMonitor.availableRange;
	UInt64 sampleCount = R.index + R.count;
	UInt64 sliceCount = sampleCount / 512;
	UInt64 sliceIndex = mSliceIndex;
	
	if (sliceIndex < R.index/512)
	{ sliceIndex = R.index/512; }

	while (sliceIndex < sliceCount)
	{
		// write slice from monitor to file
		RMSAudioBufferList stereoBuffer =
		[sampleMonitor bufferListWithOffset:sliceIndex * 512];
		
		error = ExtAudioFileWriteAsync(mFileRef, 512, &stereoBuffer.list);
		if (error != noErr)
		{ return error; }
		
		sliceIndex += 1;
	}
	
	mSliceIndex = sliceIndex;
	
	return error;
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////



