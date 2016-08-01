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

////////////////////////////////////////////////////////////////////////////////
@implementation RMSFileRecorder
////////////////////////////////////////////////////////////////////////////////

+ (instancetype) instanceWithURL:(NSURL *)url
{ return [self instanceWithURL:url fileType:kAudioFileM4AType]; }

+ (instancetype) instanceWithURL:(NSURL *)url fileType:(AudioFileTypeID)typeID
{ return [[self alloc] initWithURL:url fileType:typeID]; }

////////////////////////////////////////////////////////////////////////////////

- (instancetype) initWithURL:(NSURL *)url fileType:(AudioFileTypeID)typeID
{
	self = [super init];
	if (self != nil)
	{
		_url = url;
		_fileType = typeID;
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

+ (NSArray *) writeableTypes
{ return @[@"m4a", @"aif"]; }

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) startFileWithSampleRate:(Float64)sampleRate
{
	OSStatus error = noErr;
	
	AudioStreamBasicDescription fileFormat =
	{
		.mSampleRate 		= sampleRate,
		.mFormatID 			= kAudioFormatAppleLossless,
		.mChannelsPerFrame 	= 2,
	};
	
	error = ExtAudioFileCreateWithURL(
		(__bridge CFURLRef)self.url,
		self.fileType,
		&fileFormat,
		nil,
		kAudioFileFlags_EraseFile,
		&mFileRef);
	
	if (error != noErr) return error;

	error = ExtAudioFileSetProperty(mFileRef,
				kExtAudioFileProperty_ClientDataFormat,
				sizeof(RMSPreferredAudioFormat),
				&RMSPreferredAudioFormat);

	if (error != noErr) return error;
	
	error = ExtAudioFileWriteAsync(mFileRef, 0, nil);
	
	return error;
}

////////////////////////////////////////////////////////////////////////////////

- (OSStatus) updateWithMonitor:(RMSSampleMonitor *)sampleMonitor
{
	OSStatus error = noErr;
	
	if (mFileRef == nil)
	{
		error = [self startFileWithSampleRate:sampleMonitor.sampleRate];
		if (error != noErr) return error;
	}
	
	rmsrange_t R = sampleMonitor.availableRange;
	UInt64 sampleCount = R.index + R.count;
	UInt64 sliceCount = sampleCount / 512;
	UInt64 sliceIndex = mSliceIndex;
	
	if (sliceIndex < R.index/512)
	{ sliceIndex = R.index/512; }

	while (sliceIndex < sliceCount)
	{
		// write slice from monitor...
		RMSAudioBufferList stereoBuffer =
		[sampleMonitor bufferListWithOffset:sliceIndex * 512];
		
		// ... to file
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



