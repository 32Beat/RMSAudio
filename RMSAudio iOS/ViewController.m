//
//  ViewController.m
//  RMSAudio iOS
//
//  Created by 32BT on 23/07/16.
//  Copyright © 2016 32BT. All rights reserved.
//

#import "ViewController.h"

#import "RMSAudio.h"
#import "RMSResultView.h"

@interface ViewController () <RMSOutputDelegate, RMSTimerProtocol>
{
	NSTimer *mReportTimer;
	
	BOOL mProcessingLevels;
	RMSStereoLevels mLevels;
}

@property (nonatomic) RMSOutput *audioOutput;

@property (nonatomic) RMSSampleMonitor *outputMonitor;
@property (nonatomic, weak) IBOutlet RMSResultView *resultViewL;
@property (nonatomic, weak) IBOutlet RMSResultView *resultViewR;


@end

////////////////////////////////////////////////////////////////////////////////
@implementation ViewController
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

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	AVAudioSession *session = [AVAudioSession sharedInstance];
	if (session != nil)
	{
		if (session.recordPermission == AVAudioSessionRecordPermissionGranted)
			[self startPlayThru];
		else
		if (session.recordPermission == AVAudioSessionRecordPermissionUndetermined)
			[session requestRecordPermission:^(BOOL granted)
			{
				if (granted == YES)
				{
					[self startPlayThru];
				}
			}];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) startPlayThru
{
	AVAudioSession *session = [AVAudioSession sharedInstance];
	if ([session setCategory:AVAudioSessionCategoryMultiRoute error:nil])
	{
		NSLog(@"%@", @"AVAudioSession category set successfully!");
		
		if ([session setActive:YES error:nil])
		{
			NSInteger inputChannelCount = [session inputNumberOfChannels];
			NSInteger inputChannelCountMax = [session maximumInputNumberOfChannels];
			
			self.audioOutput = [RMSOutput new];
			self.audioOutput.source = [RMSInput new];
			self.audioOutput.monitor = self.outputMonitor;
			[self.audioOutput startRunning];
			
			[self startRenderTimingReports];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) audioOutput:(RMSOutput *)audioOutput didChangeState:(UInt32)state
{
	// TODO: add recursive reset to RMSSource
	if (self.audioOutput == audioOutput)
	{
		[self.audioOutput stopRunning];
		//[self restartEngine];
	}
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
	[self.logView setNeedsDisplay];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////





- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];

}

@end
