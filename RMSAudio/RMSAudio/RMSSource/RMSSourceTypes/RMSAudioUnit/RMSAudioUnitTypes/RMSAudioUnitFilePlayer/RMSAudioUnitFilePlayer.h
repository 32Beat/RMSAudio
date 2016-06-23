////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUnitFilePlayer
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSAudioUnit.h"

@interface RMSAudioUnitFilePlayer : RMSAudioUnit

+ (NSArray *) readableTypes;

+ (instancetype) instanceWithURL:(NSURL *)fileURL;

- (OSStatus) getCurrentPlayTime:(AudioTimeStamp *)timeStamp;

@end
