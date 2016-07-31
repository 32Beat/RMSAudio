////////////////////////////////////////////////////////////////////////////////
/*
	RMSClip
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSSource.h"

@interface RMSClip : RMSSource

+ (instancetype) sineWaveWithLength:(UInt64)N;
+ (instancetype) blockWaveWithLength:(UInt64)N;
- (instancetype) initWithLength:(UInt64)size;

- (size_t) sampleCount;
- (float *) mutablePtrL;
- (float *) mutablePtrR;

- (void) normalize;

@end
