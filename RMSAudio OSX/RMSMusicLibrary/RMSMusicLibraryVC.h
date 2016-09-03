////////////////////////////////////////////////////////////////////////////////
/*
	RMSMusicLibraryVC
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import <Cocoa/Cocoa.h>
#import "RMSMusicLibrary.h"

@protocol RMSMusicLibraryControllerDelegate
- (void) musicLibraryController:(id)controller didSelectItem:(id)item;
@end

@interface RMSMusicLibraryVC : NSObject
<NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (nonatomic, weak) id<RMSMusicLibraryControllerDelegate> delegate;

@property (nonatomic, weak) IBOutlet NSOutlineView *listView;

@property (nonatomic) FSItem *selectedItem;

@end

