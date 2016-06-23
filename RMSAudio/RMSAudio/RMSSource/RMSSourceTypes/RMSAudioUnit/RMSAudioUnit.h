////////////////////////////////////////////////////////////////////////////////
/*
	RMSAudioUnit
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSSource.h"
#import "RMSAudioUnitUtilities.h"

@interface RMSAudioUnit : RMSSource
{
	AudioUnit mAudioUnit;
}

//- (instancetype) initWithAUHAL;

+ (instancetype) instanceWithDescription:(AudioComponentDescription)desc;
- (instancetype) initWithDescription:(AudioComponentDescription)desc;

- (OSStatus) getSourceFormat:(AudioStreamBasicDescription *)streamInfoPtr;
- (OSStatus) setSourceFormat:(const AudioStreamBasicDescription *)streamInfoPtr;
- (OSStatus) getResultFormat:(AudioStreamBasicDescription *)streamInfoPtr;
- (OSStatus) setResultFormat:(const AudioStreamBasicDescription *)streamInfoPtr;

- (OSStatus) initializeAudioUnit;
- (OSStatus) uninitializeAudioUnit;

@end
