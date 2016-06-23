////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUnitPlatformIO
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAudioUnit.h"

@interface RMSAudioUnitPlatformIO : RMSAudioUnit

- (OSStatus) enableInput:(BOOL)state;
- (OSStatus) enableOutput:(BOOL)state;
- (OSStatus) startRunning;
- (OSStatus) stopRunning;

@end
