//
//  Document.m
//  RMSAudio
//
//  Created by 32BT on 23/06/16.
//  Copyright © 2016 32BT. All rights reserved.
//

#import "Document.h"

#import "FSItem.h"
#import "RMSMusicLibrary.h"
#import "RMSAudio.h"
#import "RMSResultView.h"


@interface Document () <RMSOutputDelegate, RMSTimerProtocol>
{
	NSTimer *mReportTimer;
	
	BOOL mProcessingLevels;
	RMSStereoLevels mLevels;
}

@property (nonatomic) RMSOutput *audioOutput;

@property (nonatomic) RMSMixer *mixer;

@property (nonatomic) RMSVolume *volumeFilter;
@property (nonatomic, weak) IBOutlet NSSlider *gainControl;
@property (nonatomic, weak) IBOutlet NSSlider *volumeControl;
@property (nonatomic, weak) IBOutlet NSSlider *balanceControl;

@property (nonatomic) RMSAutoPan *autoPanFilter;
@property (nonatomic, weak) IBOutlet NSButton *autoPanControl;

@property (nonatomic) RMSSampleMonitor *outputMonitor;
@property (nonatomic, weak) IBOutlet RMSResultView *resultViewL;
@property (nonatomic, weak) IBOutlet RMSResultView *resultViewR;

@property (nonatomic) RMSFileRecorder *outputFile;
@property (nonatomic, weak) IBOutlet NSButton *recordButton;

@property (nonatomic) NSArray *inputDevices;
@property (nonatomic, weak) IBOutlet NSPopUpButton *sourceMenu;
@property (nonatomic) NSArray *outputDevices;
@property (nonatomic, weak) IBOutlet NSPopUpButton *outputMenu;

@property (nonatomic) RMSSource *inputSource;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressIndicator;

@property (nonatomic) RMSResampler *resampler;
@property (nonatomic, weak) IBOutlet NSSlider *parameterSlider;
@property (nonatomic, weak) IBOutlet NSButton *filterButton;

@property (nonatomic) RMSFilter *filter;



@end

#pragma mark

////////////////////////////////////////////////////////////////////////////////
@implementation Document
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

- (NSString *)windowNibName
{ return @"Document"; }

////////////////////////////////////////////////////////////////////////////////

- (void) awakeFromNib
{
	[[NSNotificationCenter defaultCenter]
	addObserver:self selector:@selector(sourceMenuWillPopUp:)
	name:NSPopUpButtonWillPopUpNotification object:self.sourceMenu];

	[[NSNotificationCenter defaultCenter]
	addObserver:self selector:@selector(outputMenuWillPopUp:)
	name:NSPopUpButtonWillPopUpNotification object:self.outputMenu];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Source Management
////////////////////////////////////////////////////////////////////////////////

- (void) sourceMenuWillPopUp:(NSNotification *)note
{
	[self.sourceMenu itemAtIndex:0].title = @"Select File...";
	
	NSArray *devices = [RMSDeviceManager availableInputDevices];
	if (self.inputDevices != devices)
	{
		self.inputDevices = devices;
		[self rebuildSourceMenu];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) rebuildSourceMenu
{
	while (self.sourceMenu.numberOfItems > 3)
	{ [self.sourceMenu removeItemAtIndex:3]; }
		
	for (RMSDevice *device in self.inputDevices)
	{
		[self.sourceMenu addItemWithTitle:device.name];
		self.sourceMenu.lastItem.representedObject = device;
	}
}

////////////////////////////////////////////////////////////////////////////////

- (IBAction) selectSource:(id)sender
{
	NSInteger index = [sender indexOfSelectedItem];
	
	if (index == 0)
	{
		[self selectFile:nil];
	}
	else
	if (index == 2)
	{
		[self setSource:nil];
	}
	else
	if (index > 2)
	{
		NSMenuItem *item = [sender selectedItem];
		RMSDevice *device = item.representedObject;
		RMSInput *input = [RMSInput instanceWithDevice:device];
		
		[self setSource:input];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) setSource:(RMSSource *)source
{
	if ([source isKindOfClass:[RMSAudioUnitFilePlayer class]])
	{ [self.sourceMenu itemAtIndex:0].title = @"File"; }

	if (self.inputSource != source)
	{
		self.inputSource = source;

		[self restartEngine];
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Output Management
////////////////////////////////////////////////////////////////////////////////

- (void) outputMenuWillPopUp:(NSNotification *)note
{
	NSArray *devices = [RMSDeviceManager availableOutputDevices];
	if (self.outputDevices != devices)
	{
		self.outputDevices = devices;
		[self rebuildOutputMenu];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) rebuildOutputMenu
{
	[self.outputMenu removeAllItems];

	[self.outputMenu addItemWithTitle:@"None"];

	for (RMSDevice *device in self.outputDevices)
	{
		[self.outputMenu addItemWithTitle:device.name];
		self.outputMenu.lastItem.representedObject = device;
	}
}

////////////////////////////////////////////////////////////////////////////////

- (IBAction) selectOutput:(NSPopUpButton *)menuButton
{
	RMSOutput *output = nil;
	
	NSMenuItem *item = [menuButton selectedItem];
	RMSDevice *device = item.representedObject;
	if (device != nil)
	{
		output = [RMSOutput instanceWithDevice:device];
	}

	[self setOutput:output];
}

////////////////////////////////////////////////////////////////////////////////

- (void) setOutput:(RMSOutput *)output
{
	if (self.audioOutput != output)
	{
		[self.audioOutput stopRunning];
		
		// prepare volumecontrol, and outputmetering
		[output addFilter:self.volumeFilter];
		[output addMonitor:self.outputMonitor];
		[output setDelegate:self];
		
		self.audioOutput = output;
		
		[self restartEngine];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) audioOutput:(RMSOutput *)audioOutput didChangeState:(UInt32)state
{
	// TODO: add recursive reset to RMSSource
	if (self.audioOutput == audioOutput)
	{
		[self.audioOutput stopRunning];
		[self restartEngine];
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
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

- (void) restartEngine
{
	RMSOutput *output = self.audioOutput;
	if (output != nil)
	{
		[output setSource:nil];
		
		RMSSource *source = self.inputSource;
//		source = [RMSClip sineWaveWithLength:10];
//		source.sampleRate = 8000;
		if (source != nil)
		{
/*
			// check for sampleRate conversion
			if (source.sampleRate != output.sampleRate) \
			{
				// change source to resampler with original source
				source = [RMSVarispeed instanceWithSource:source];
				
				// set output rate to oversampling
				source.sampleRate = 8.0 * self.audioOutput.sampleRate;
				
				// change source to downsampler with resampler
				source = [RMSVarispeed instanceWithSource:source];
			}
//*/

/*
// RMSAudioUnitConverter test
			// check for sampleRate conversion
			if (source.sampleRate != output.sampleRate) \
			{
				// change source to resampler with original source
				source = [RMSAudioUnitConverter instanceWithSource:source];
			}
//*/

//*
// RMSResampler test
			self.resampler = nil;
			
			// check for sampleRate conversion
			if (source.sampleRate > output.sampleRate)
			{
				source = [RMSResampler instanceWithSource:source];
			}
			else
			if (source.sampleRate < output.sampleRate)
			{
				double M = source.sampleRate / output.sampleRate;
				
				// change source to resampler with original source
				source = [RMSResampler instanceWithSource:source];
				
				self.resampler = (RMSResampler *)source;
				
				if (self.filter == nil)
				{
					self.filter = [RMSFilter new];
					self.filterButton.intValue = 1;
					self.parameterSlider.floatValue = 0.5;
				}
				self.filter.active = self.filterButton.intValue;
				self.filter.cutOff = M;
				self.filter.resonance = self.parameterSlider.floatValue;
				
				[self.resampler addFilter:self.filter];
			}
//*/

/* 
//mixer test
			if (self.mixer == nil)
			{ self.mixer = [RMSMixer new]; }
			
			[self.mixer addSource:source];
			source = self.mixer;
//*/

			[output setSource:source];
			mLevels.sampleRate = 0.0;
			
			if (!output.isRunning)
			{ [output startRunning]; }
			
			// prepare render timing reports
			[self startRenderTimingReports];
		}
	}
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
	if ([_audioOutput isRunning] == NO) return;

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
	
	if (self.outputFile != nil)
	{ [self.outputFile updateWithMonitor:self.outputMonitor]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) triggerLevelsUpdate
{
	if (mProcessingLevels == NO)
	{
		mProcessingLevels = YES;
		
		RMSSampleMonitor *monitor = self.outputMonitor;
		
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
		^{
			[self updateOutputLevelsWithMonitor:monitor];
			
			mProcessingLevels = NO;
		});
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateOutputLevelsWithMonitor:(RMSSampleMonitor *)monitor
{
	[monitor updateLevels];
	rmsresult_t L = [monitor levelsAtIndex:0];
	rmsresult_t R = [monitor levelsAtIndex:1];
	dispatch_async(dispatch_get_main_queue(),
	^{
		self.resultViewL.levels = L;
		self.resultViewR.levels = R;
	});
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateProgress
{
	RMSSource *source = self.inputSource;
	if ([source isKindOfClass:[RMSAudioUnitFilePlayer class]])
	{
		RMSAudioUnitFilePlayer *filePlayer = (RMSAudioUnitFilePlayer *)source;
		Float32 R = [filePlayer getRelativePlayTime];
		[self.progressIndicator setDoubleValue:R];
	}
	else
	{
		[self.progressIndicator setDoubleValue:0.0];
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (IBAction) didAdjustVolumeControl:(NSSlider *)sender
{
	if (sender == self.gainControl)
	{
		self.volumeFilter.gain = 10*sender.floatValue;
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

- (IBAction) didAdjustParameter:(NSSlider *)slider
{
//	[self.resampler setParameter:slider.floatValue];
	self.filter.resonance = slider.floatValue;
}

- (IBAction) didSelectFilterButton:(NSButton *)button
{
	self.filter.active = (button.intValue != 0);
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
		}];
}

////////////////////////////////////////////////////////////////////////////////

- (void) startFileWithURL:(NSURL *)url
{
	[self logText:[NSString stringWithFormat:@"Start file: %@", url.lastPathComponent]];
	
	id source = [RMSAudioUnitFilePlayer instanceWithURL:url];
	[self setSource:source];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Select Output File
////////////////////////////////////////////////////////////////////////////////

- (IBAction) didSelectOutputFileButton:(NSButton *)button
{
	if (self.outputFile != nil)
	{
		self.outputFile = nil;
		[self.recordButton setTitle:@"Record"];
	}
	else
	{
		[self selectOutputFile:nil];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (IBAction) selectOutputFile:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	panel.allowedFileTypes = [RMSFileRecorder writeableTypes];
	
	// start selection sheet ...
	[panel beginSheetModalForWindow:self.windowForSheet

		// ... with result block
		completionHandler:^(NSInteger result)
		{
			if (result == NSFileHandlingPanelOKButton)
			{
				if ([panel URL] != nil)
				{
					NSURL *url = [panel URL];
					[self startRecordingWithURL:url];
				}
			}
		}];
}

////////////////////////////////////////////////////////////////////////////////

- (void) startRecordingWithURL:(NSURL *)url
{
	self.outputFile = [RMSFileRecorder instanceWithURL:url];
	if (self.outputFile != nil)
	{
		[self.recordButton setTitle:@"Stop"];
	}
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





