//
//  ViewController.m
//  RMSAudio iOS
//
//  Created by 32BT on 23/07/16.
//  Copyright © 2016 32BT. All rights reserved.
//

#import "ViewController.h"

#import "RMSAudio.h"

@interface ViewController ()

@property (nonatomic) RMSOutput *audioOutput;

@property (nonatomic) NSTimer *reportTimer;


@end

@implementation ViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	
	AVAudioSession *session = [AVAudioSession sharedInstance];

	if (session != nil)
	{
		NSArray *devices = [session availableInputs];
		NSLog(@"%@", devices.description);
	}
	
	self.audioOutput = [RMSOutput new];
	[self.audioOutput startRunning];
	
	[self startRenderTimingReports];
	
	
}



- (void) startRenderTimingReports
{
	if (self.reportTimer == nil)
	{
		// set timer for 2 second updates
		self.reportTimer = [NSTimer timerWithTimeInterval:2.0
		target:self selector:@selector(reportRenderTime:) userInfo:nil repeats:YES];
		
		// add tolerance to reduce system strain
		[self.reportTimer setTolerance:.2];
		
		// add to runloop
		[[NSRunLoop currentRunLoop] addTimer:self.reportTimer
        forMode:NSRunLoopCommonModes];
	}
	
}

////////////////////////////////////////////////////////////////////////////////

- (void) stopRenderTimingReports
{
	[self.reportTimer invalidate];
	self.reportTimer = nil;
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
