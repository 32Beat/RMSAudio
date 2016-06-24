//
//  Document.m
//  RMSAudio
//
//  Created by 32BT on 23/06/16.
//  Copyright © 2016 32BT. All rights reserved.
//

#import "Document.h"

#import "RMSAudio.h"


@interface Document ()
{
}

@property (nonatomic) RMSOutput *audioOutput;

@end

////////////////////////////////////////////////////////////////////////////////
@implementation Document
////////////////////////////////////////////////////////////////////////////////

- (RMSOutput *) audioOutput
{
	if (_audioOutput == nil)
	{
		_audioOutput = [RMSOutput defaultOutput];
	}
	
	return _audioOutput;
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
	RMSSource *source = [RMSAudioUnitFilePlayer instanceWithURL:url];
	if (source != nil)
	{
		if (source.sampleRate != self.audioOutput.sampleRate)
		{
			source = [RMSAudioUnitVarispeed instanceWithSource:source];
		}
	}
	
	// Attaching automatically sets the output sampleRate for source
	[self.audioOutput setSource:source];
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////






