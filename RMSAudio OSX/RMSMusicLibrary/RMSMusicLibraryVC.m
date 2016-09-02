////////////////////////////////////////////////////////////////////////////////
/*
	RMSMusicLibrary
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSMusicLibraryVC.h"
#import "RMSMusicLibrary.h"

////////////////////////////////////////////////////////////////////////////////
@interface RMSMusicLibraryVC ()
@property (nonatomic) RMSMusicLibrary *musicLibrary;
@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSMusicLibraryVC
////////////////////////////////////////////////////////////////////////////////

- (void) awakeFromNib
{
	self.listView.target = self;
	self.listView.doubleAction = @selector(outlineViewDoubleClicked:);
	self.listView.delegate = self;
	self.listView.dataSource = self;
	
	[self setLibraryURL:nil];
}

////////////////////////////////////////////////////////////////////////////////

- (IBAction) didSelectLibraryButton:(NSButton *)button
{ [self selectLibrary:nil]; }

- (IBAction) selectLibrary:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	panel.canChooseDirectories = YES;
	panel.canChooseFiles = NO;
	
	// start selection sheet ...
	[panel beginSheetModalForWindow:self.listView.window

		// ... with result block
		completionHandler:^(NSInteger result)
		{
			if (result == NSFileHandlingPanelOKButton)
			{
				if ([panel URLs].count != 0)
				{
					NSURL *url = [panel URLs][0];
					NSLog(@"%@", url);

					[self setLibraryURL:url];
				}
			}
		}];
}

////////////////////////////////////////////////////////////////////////////////

- (void) setLibraryURL:(NSURL *)url
{
	if (url == nil)
	{
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *musicURLs = [fileManager URLsForDirectory:NSMusicDirectory
		inDomains:NSUserDomainMask];
		if (musicURLs.count != 0)
		{ url = musicURLs[0]; }
	}

	self.musicLibrary = [RMSMusicLibrary itemWithURL:url];
	[self.listView reloadData];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark DataSource
////////////////////////////////////////////////////////////////////////////////

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (item == nil)
	{ item = self.musicLibrary; }

	return [item isContainer];
}

////////////////////////////////////////////////////////////////////////////////

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
	{ item = self.musicLibrary; }
	
	return ((FSItem *)item).containerItems.count;
}

////////////////////////////////////////////////////////////////////////////////

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (item == nil)
	{ item = self.musicLibrary; }

	return ((FSItem *)item).containerItems[index];
}

////////////////////////////////////////////////////////////////////////////////

- (id)outlineView:(NSOutlineView *)outlineView
	objectValueForTableColumn:(NSTableColumn *)tableColumn
	byItem:(id)item
{
	if (item == nil)
	{ item = self.musicLibrary; }

	if ([[tableColumn identifier] isEqualToString:@"name"])
	{
		return [(FSItem *)item localizedName];
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Delegate
////////////////////////////////////////////////////////////////////////////////

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSOutlineView *outlineView = notification.object;
	FSItem *item = [outlineView itemAtRow:outlineView.selectedRow];
	
	NSLog(@"%@", item.localizedName);
}

////////////////////////////////////////////////////////////////////////////////

- (void) outlineViewDoubleClicked:(id)sender
{
	NSOutlineView *outlineView = sender;
	FSItem *item = [outlineView itemAtRow:outlineView.clickedRow];
	
	NSLog(@"%@", item.localizedName);
}
////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





