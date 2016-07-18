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

@property (nonatomic) RMSVolume *volumeFilter;
@property (nonatomic, weak) IBOutlet NSSlider *gainControl;
@property (nonatomic, weak) IBOutlet NSSlider *volumeControl;
@property (nonatomic, weak) IBOutlet NSSlider *balanceControl;

@property (nonatomic) RMSAutoPan *autoPanFilter;
@property (nonatomic, weak) IBOutlet NSButton *autoPanControl;



@property (nonatomic, weak) IBOutlet NSPopUpButton *sourceMenu;


@property (nonatomic) RMSAudioUnitFilePlayer *filePlayer;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *fileProgressIndicator;

@property (nonatomic) RMSOutput *audioOutput;
@property (nonatomic) RMSSampleMonitor *outputMonitor;
@property (nonatomic, weak) IBOutlet RMSResultView *resultViewL;
@property (nonatomic, weak) IBOutlet RMSResultView *resultViewR;

@end

#pragma mark

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
	[self.sourceMenu addItemsWithTitles:devices];
	
	[[NSNotificationCenter defaultCenter]
	addObserver:self selector:@selector(buttonWillPopUp:)
	name:NSPopUpButtonWillPopUpNotification object:self.sourceMenu];
}

////////////////////////////////////////////////////////////////////////////////

- (void) buttonWillPopUp:(NSNotification *)note
{
	if (self.sourceMenu == note.object)
	{
		[self.sourceMenu itemAtIndex:2].title = @"None";
	}
}

////////////////////////////////////////////////////////////////////////////////

- (IBAction) selectSource:(id)sender
{
	if ([sender indexOfSelectedItem] == 0)
	{
		[self selectFile:nil];
	}
	else
	if ([sender indexOfSelectedItem] > 2)
	{
		NSString *name = [sender titleOfSelectedItem];
		[self selectSourceWithName:name];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) selectSourceWithName:(NSString *)name
{
	
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

- (RMSVolume *)volumeFilter
{
	if (_volumeFilter == nil)
	{ _volumeFilter = [RMSVolume new]; }
	
	return _volumeFilter;
}

////////////////////////////////////////////////////////////////////////////////

- (RMSSampleMonitor *) outputMonitor
{
	if (_outputMonitor == nil)
	{
		// create RMSSampleMonitor to monitor any RMSOutput
		_outputMonitor = [RMSSampleMonitor instanceWithCount:16*1024];
		
		// add self to RMSTimer for periodic updating of GUI levels
		[RMSTimer addRMSTimerObserver:self];
	}
	
	return _outputMonitor;
}

////////////////////////////////////////////////////////////////////////////////

- (RMSOutput *) audioOutput
{
	if (_audioOutput == nil)
	{
		_audioOutput = [RMSOutput defaultOutput];
		_audioOutput.delegate = self;
	
		// prepare volumecontrol, autopan, and outputmetering
		[_audioOutput addFilter:self.volumeFilter];
		[_audioOutput addMonitor:self.outputMonitor];
		
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
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[RMSTimer removeRMSTimerObserver:self];

	[self stopRenderTimingReports];

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
		[mReportTimer setTolerance:.2];
		
		// add to runloop
		[[NSRunLoop currentRunLoop] addTimer:mReportTimer
        forMode:NSRunLoopCommonModes];
	}
	
}

////////////////////////////////////////////////////////////////////////////////

- (void) stopRenderTimingReports
{
	[mReportTimer invalidate];
	mReportTimer = nil;
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
	
	if (self.autoPanFilter != nil)
	{ self.balanceControl.floatValue = self.autoPanFilter.correctionBalance; }
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
////////////////////////////////////////////////////////////////////////////////

- (IBAction) didAdjustVolumeControl:(NSSlider *)sender
{
	if (sender == self.gainControl)
	{
		self.volumeFilter.gain = sender.floatValue;
	}
	else
	if (sender == self.volumeControl)
	{
		self.volumeFilter.volume = sender.floatValue;
	}
	else
	if (sender == self.balanceControl)
	{
		self.volumeFilter.balance = sender.floatValue;
	}
}

////////////////////////////////////////////////////////////////////////////////

- (IBAction) didSelectAutoPanButton:(NSButton *)button
{
	if (button.intValue != 0)
	{
		[self.balanceControl setEnabled:NO];
		self.autoPanFilter = [RMSAutoPan new];
		[self.audioOutput addFilter:self.autoPanFilter];
	}
	else
	{
		[self.audioOutput removeFilter:self.autoPanFilter];
		self.autoPanFilter = nil;
		[self.balanceControl setEnabled:YES];
		[self.balanceControl setFloatValue:self.volumeFilter.balance];
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Select Audio File
////////////////////////////////////////////////////////////////////////////////
/*
	Select an audio file and play it.
*/

- (IBAction) didSelectAudioFileButton:(NSButton *)button
{ [self selectFile:nil]; }

- (IBAction) selectFile:(id)sender
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
			
			[self.sourceMenu selectItemAtIndex:2];
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





