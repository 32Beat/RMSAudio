////////////////////////////////////////////////////////////////////////////////
/*
	RMSMusicLibrary
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import <Cocoa/Cocoa.h>
#import "FSItem.h"

@interface RMSMusicLibrary : FSItem
<NSOutlineViewDataSource, NSOutlineViewDelegate>

- (void) attachToOutlineView:(NSOutlineView *)outlineView;

@end

