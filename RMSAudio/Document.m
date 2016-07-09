//
//  Document.m
//  RMSAudio
//
//  Created by 32BT on 23/06/16.
//  Copyright © 2016 32BT. All rights reserved.
//

#import "Document.h"

#import "RMSAudio.h"
#import "RMSResultView.h"


@interface Document () <RMSTimerProtocol>
{
	NSTimer *mReportTimer;
	
	RMSStereoLevels mLevels;
}

@property (nonatomic) RMSOutput *audioOutput;
@property (nonatomic) RMSSampleMonitor *outputMonitor;
@property (nonatomic, weak) IBOutlet RMSResultView *resultViewL;
@property (nonatomic, weak) IBOutlet RMSResultView *resultViewR;

@end

////////////////////////////////////////////////////////////////////////////////
@implementation Document
////////////////////////////////////////////////////////////////////////////////

- (NSString *)windowNibName
{ return @"Document"; }

////////////////////////////////////////////////////////////////////////////////

- (RMSOutput *) audioOutput
{
	if (_audioOutput == nil)
	{
		_audioOutput = [RMSOutput defaultOutput];
		
		_outputMonitor = [RMSSampleMonitor instanceWithCount:16*1024];
		[_audioOutput addMonitor:_outputMonitor];
		
		mLevels.L = RMSLevelsInit(_audioOutput.sampleRate);
		mLevels.R = RMSLevelsInit(_audioOutput.sampleRate);
		[RMSTimer addRMSTimerObserver:self];
		
		[self startRenderTimingReports];
	}
	
	return _audioOutput;
}

////////////////////////////////////////////////////////////////////////////////

- (void) dealloc
{
	[_audioOutput stopRunning];
	_audioOutput = nil;
}

////////////////////////////////////////////////////////////////////////////////

- (void) close
{
	// break circular reference
	[mReportTimer invalidate];
	mReportTimer = nil;

	[RMSTimer removeRMSTimerObserver:self];

	// stop audiounit
	[_audioOutput stopRunning];
	_audioOutput = nil;
	
	[super close];
}

////////////////////////////////////////////////////////////////////////////////

- (void) startRenderTimingReports
{
	if (mReportTimer == nil)
	{
		// set timer for 2 second updates
		mReportTimer = [NSTimer timerWithTimeInterval:2.0
		target:self selector:@selector(reportRenderTime:) userInfo:nil repeats:YES];
		
		// add tolerance to reduce system strain
		[mReportTimer setTolerance:.1];
		
		// add to runloop
		[[NSRunLoop currentRunLoop] addTimer:mReportTimer
        forMode:NSRunLoopCommonModes];
	}
	
}

////////////////////////////////////////////////////////////////////////////////

- (void) reportRenderTime:(id)sender
{
	double avgTime = [_audioOutput averageRenderTime];
	double maxTime = [_audioOutput maximumRenderTime];
	[_audioOutput resetTimingInfo];
	
	[self logText:[NSString stringWithFormat:@"avg rendertime = %lfs", avgTime]];
	[self logText:[NSString stringWithFormat:@"max rendertime = %lfs", maxTime]];
}

////////////////////////////////////////////////////////////////////////////////

- (void) logText:(NSString *)text
{
	[self.logView.textStorage.mutableString insertString:@"\r" atIndex:0];
	[self.logView.textStorage.mutableString insertString:text atIndex:0];
	[self.logView setNeedsDisplay:YES];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (void) globalRMSTimerDidFire
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
	^{
		[self.outputMonitor updateLevels:&mLevels];
		
		self.resultViewL.levels = RMSLevelsFetchResult(&mLevels.L);
		self.resultViewR.levels = RMSLevelsFetchResult(&mLevels.R);
	});
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Select Audio File
////////////////////////////////////////////////////////////////////////////////
/*
	Select an audio file and play it.
*/

- (IBAction) didSelectAudioFileButton:(NSButton *)button
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	// Since RMSAudioUnitFilePlayer will be used for playing the audiofile
	// it should also provide the filetypes it can read
	panel.allowedFileTypes = [RMSAudioUnitFilePlayer readableTypes];
	
	// start selection sheet ...
	[panel beginSheetModalForWindow:self.windowForSheet

		// ... with result block
		completionHandler:^(NSInteger result)
		{
			if (result == NSFileHandlingPanelOKButton)
			{
				if ([panel URLs].count != 0)
				{
					NSURL *url = [panel URLs][0];
					[self startFileWithURL:url];
				}
			}
		}];
}

////////////////////////////////////////////////////////////////////////////////

- (void) startFileWithURL:(NSURL *)url
{
	[self logText:[NSString stringWithFormat:@"Start file: %@", url.lastPathComponent]];
	
	RMSSource *source = [RMSAudioUnitFilePlayer instanceWithURL:url];
	if (source != nil)
	{
		if (source.sampleRate != self.audioOutput.sampleRate)
		{
			source = [RMSVarispeed instanceWithSource:source];
			//source = [RMSAudioUnitVarispeed instanceWithSource:source];
		}
	}
		
	// Attaching automatically sets the output sampleRate for source
	[self.audioOutput setSource:source];
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





