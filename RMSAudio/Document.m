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


@interface Document () <RMSOutputDelegate, RMSTimerProtocol>
{
	NSTimer *mReportTimer;
	
	BOOL mProcessingLevels;
	RMSStereoLevels mLevels;
}

@property (nonatomic, weak) IBOutlet NSPopUpButton *deviceMenu;


@property (nonatomic) RMSAudioUnitFilePlayer *filePlayer;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *fileProgressIndicator;

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

- (void) awakeFromNib
{
	// fetch names of available input devices
	NSArray *devices = [RMSInput availableDevices];
	
	// add to popup menu
	if (devices && devices.count)
	[self.deviceMenu addItemsWithTitles:devices];
}

////////////////////////////////////////////////////////////////////////////////

- (IBAction) selectSource:(id)sender
{
	NSString *name = [sender titleOfSelectedItem];
	
	AudioDeviceID deviceID = [RMSInput deviceWithName:name];
	if (deviceID != 0)
	{
		RMSInput *input = [RMSInput instanceWithDeviceID:deviceID];
		if (input != nil)
		{
			[self startSource:input];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) startSource:(RMSSource *)source
{
	[_audioOutput stopRunning];
	_audioOutput = nil;
	
	// update filePlayer connection for progress indicator
	if (self.filePlayer != source)
	{
		self.filePlayer = nil;
		if ([source isKindOfClass:[RMSAudioUnitFilePlayer class]])
		{ self.filePlayer = (RMSAudioUnitFilePlayer *)source; }
	}
	
	// check for sampleRate conversion
	if (source.sampleRate != self.audioOutput.sampleRate) \
	{
		source = [RMSVarispeed instanceWithSource:source];
		source.sampleRate = 4.0 * self.audioOutput.sampleRate;
		source = [RMSVarispeed instanceWithSource:source];
	}
	
	// attach to audioOutput
	self.audioOutput.source = source;
	
	mLevels.sampleRate = 0.0;
	
	[_audioOutput startRunning];
}

////////////////////////////////////////////////////////////////////////////////

- (RMSOutput *) audioOutput
{
	if (_audioOutput == nil)
	{
		_audioOutput = [RMSOutput defaultOutput];
		_audioOutput.delegate = self;
		
		// prepare level metering
		if (_outputMonitor == nil)
		{
			// create RMSSampleMonitor to monitor any RMSOutput
			_outputMonitor = [RMSSampleMonitor instanceWithCount:16*1024];
			
			// add self to RMSTimer for periodic updating of GUI levels
			[RMSTimer addRMSTimerObserver:self];
		}
		
		[_audioOutput addMonitor:_outputMonitor];
		
		// prepare render timing reports
		[self startRenderTimingReports];
	}
	
	return _audioOutput;
}

////////////////////////////////////////////////////////////////////////////////

- (void) audioOutput:(RMSOutput *)audioOutput didChangeState:(UInt32)state
{
	// TODO: add recursive reset to RMSSource
	if (_audioOutput == audioOutput)
	{
		id source = _audioOutput.source;
		
		if ([source isKindOfClass:[RMSVarispeed class]])
		{ source = [source source]; }
		
		[_audioOutput stopRunning];
		_audioOutput = nil;

		[self startSource:source];
	}
}

////////////////////////////////////////////////////////////////////////////////

// break any self-inflicted strong references
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

- (void) dealloc
{
	[_audioOutput stopRunning];
	_audioOutput = nil;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
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
	[self updateProgress];
	[self triggerLevelsUpdate];
}

////////////////////////////////////////////////////////////////////////////////

- (void) triggerLevelsUpdate
{
	if (mProcessingLevels == NO)
	{
		mProcessingLevels = YES;
		
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
		^{
			[self updateOutputLevels];
			
			mProcessingLevels = NO;
		});
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateOutputLevels
{
	[self.outputMonitor updateLevels:&mLevels];
	rmsresult_t L = RMSLevelsFetchResult(&mLevels.L);
	rmsresult_t R = RMSLevelsFetchResult(&mLevels.R);
	dispatch_async(dispatch_get_main_queue(),
	^{
		self.resultViewL.levels = L;
		self.resultViewR.levels = R;
	});
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateProgress
{
	Float32 R = [self.filePlayer getRelativePlayTime];
	[self.fileProgressIndicator setDoubleValue:R];
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
	
	id source = [RMSAudioUnitFilePlayer instanceWithURL:url];
	[self startSource:source];
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





