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

@property (nonatomic, assign) UInt32 defaultBusIndex;

//- (instancetype) initWithAUHAL;

+ (instancetype) instanceWithDescription:(AudioComponentDescription)desc;
- (instancetype) initWithDescription:(AudioComponentDescription)desc;

- (OSStatus) getSourceFormat:(AudioStreamBasicDescription *)streamInfoPtr;
- (OSStatus) setSourceFormat:(const AudioStreamBasicDescription *)streamInfoPtr;
- (OSStatus) getResultFormat:(AudioStreamBasicDescription *)streamInfoPtr;
- (OSStatus) setResultFormat:(const AudioStreamBasicDescription *)streamInfoPtr;

- (OSStatus) initializeAudioUnit;
- (OSStatus) uninitializeAudioUnit;

- (void) setRenderQuality:(float)quality;

- (Float64) inputScopeSampleRate;
//- (Float64) inputScopeSampleRateAtIndex:(UInt32)busIndex;
- (void) setInputSampleRate:(Float64)sampleRate;

@end
