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
#pragma mark Select File
////////////////////////////////////////////////////////////////////////////////

- (IBAction) didSelectFileButton:(NSButton *)button
{
//*
	[self didSelectAudioFileButton:button];
/*/
	[self didSelectImageFileButton:button];
/*/
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Select Audio File
////////////////////////////////////////////////////////////////////////////////
/*
	Select an audio file and play it.
	
	Note that the RMSAudioUnitVarispeed is attached if necessary.
	
	sampleRate always refers to the output samplerate of an RMSSource.
	Where appropriate, the input sampleRate should be set by a specific method, 
	unless the sampleRate is implicated.
*/

- (IBAction) didSelectAudioFileButton:(NSButton *)button
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	panel.allowedFileTypes = [RMSAudioUnitFilePlayer readableTypes];
	
	// start selection sheet
	[panel beginSheetModalForWindow:self.windowForSheet completionHandler:
		// with result block
		^(NSInteger result)
		{
			if (result != 0)
			{
				NSURL *url = [panel URLs][0];
				[self startFileWithURL:url];
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
			//source = [RMSAudioUnitVarispeed instanceWithSource:source];
		}
	}
	
	// Attaching automatically sets the output sampleRate for source
	[self.audioOutput setSource:source];
}

////////////////////////////////////////////////////////////////////////////////
















+ (BOOL)autosavesInPlace {
	return YES;
}

- (NSString *)windowNibName {
	// Override returning the nib file name of the document
	// If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
	return @"Document";
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
	// Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
	// You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
	[NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
	return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	// Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
	// You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
	// If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
	[NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
	return YES;
}

@end
