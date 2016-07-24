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

@class RMSSampleMonitor;

@protocol RMSSampleMonitorObserverProtocol <NSObject>
- (BOOL) active;
- (void) updateWithSampleMonitor:(RMSSampleMonitor *)sampleMonitor;
@end

@protocol RMSSampleMonitorDelegateProtocol <NSObject>
- (void) sampleMonitor:(RMSSampleMonitor *)sampleMonitor
	didUpdateObserver:(id)observer;
@end

@interface RMSSampleMonitor : RMSSource

@property (nonatomic, weak) id delegate;

+ (instancetype) instanceWithCount:(size_t)sampleCount;
- (instancetype) initWithCount:(size_t)sampleCount;

- (size_t) length;
- (uint64_t) maxIndex;

- (rmsrange_t) availableRange;
- (rmsrange_t) availableRangeWithIndex:(uint64_t)index;

- (BOOL) getSamples:(float **)dstPtr count:(size_t)count;
- (BOOL) getSamples:(float **)dstPtr withRange:(rmsrange_t)R;
- (void) getSamplesL:(float *)dstPtr withRange:(rmsrange_t)R;
- (void) getSamplesR:(float *)dstPtr withRange:(rmsrange_t)R;

- (rmsbuffer_t *) bufferAtIndex:(int)n;

- (void) reset;
- (void) updateLevels:(RMSStereoLevels *)levels;

- (void) addObserver:(id<RMSSampleMonitorObserverProtocol>)observer;
- (void) removeObserver:(id<RMSSampleMonitorObserverProtocol>)observer;
- (void) updateObservers;

@end
