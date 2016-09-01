////////////////////////////////////////////////////////////////////////////////
/*
	RMSMusicLibrary
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSMusicLibrary.h"

////////////////////////////////////////////////////////////////////////////////
@interface RMSMusicLibrary () 
@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSMusicLibrary
////////////////////////////////////////////////////////////////////////////////

- (void) attachToOutlineView:(NSOutlineView *)outlineView
{
	outlineView.target = self;
	outlineView.doubleAction = @selector(outlineViewDoubleClicked:);
	outlineView.delegate = self;
	outlineView.dataSource = self;
	[outlineView reloadData];
}

////////////////////////////////////////////////////////////////////////////////

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (item == nil)
	{ item = self; }

	return [item isContainer];
}

////////////////////////////////////////////////////////////////////////////////

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
	{ item = self; }
	
	return ((FSItem *)item).containerItems.count;
}

////////////////////////////////////////////////////////////////////////////////

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (item == nil)
	{ item = self; }

	return ((FSItem *)item).containerItems[index];
}

////////////////////////////////////////////////////////////////////////////////

- (id)outlineView:(NSOutlineView *)outlineView
	objectValueForTableColumn:(NSTableColumn *)tableColumn
	byItem:(id)item
{
	if (item == nil)
	{ item = self; }

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





