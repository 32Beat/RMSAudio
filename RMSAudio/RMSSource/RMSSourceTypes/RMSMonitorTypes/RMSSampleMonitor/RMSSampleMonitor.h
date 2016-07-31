////////////////////////////////////////////////////////////////////////////////
/*
	RMSSampleMonitor
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////
/*
	RMSSampleMonitor is a simple ringbuffer monitor which can be used by 
	multiple observers to display information about the latest samples. 
	This significantly reduces the strain on the real-time audio thread 
	when multiple metering is required.
	
	The length count of the RMSSampleMonitor should obviously be appropriate 
	for the largest possible demand. 
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSSource.h"
#import "rmsbuffer.h"
#import "rmslevels.h"


////////////////////////////////////////////////////////////////////////////////
// convenience struct for processing stereo signal

typedef struct RMSStereoLevels
{
	Float64 sampleRate;
	uint64_t index;
	rmslevels_t L;
	rmslevels_t R;
}
RMSStereoLevels;

/*
possible design concept: always as extension to RMSSampleMonitor

@interface RMSSampleMonitor (RMSStereoLevels)
- (void) updateStereoLevels:(RMSStereoLevels *)levels;
@end

@interface RMSSampleMonitor (RMSLissajouxData)
- (void) updateLissajouxData:(RMSLissajouxData *)data;
@end
*/
////////////////////////////////////////////////////////////////////////////////

@interface RMSSampleMonitor : RMSSource

+ (instancetype) instanceWithCount:(size_t)sampleCount;

- (rmsrange_t) availableRange;
- (rmsrange_t) availableRangeWithIndex:(uint64_t)index;

- (rmsbuffer_t *) bufferAtIndex:(NSUInteger)n;

- (void) reset;
- (void) updateLevels;
- (void) updateLevels:(RMSStereoLevels *)levels;

- (rmsresult_t) levelsAtIndex:(NSUInteger)index;

@end






