////////////////////////////////////////////////////////////////////////////////
/*
	RMSSampleMonitor
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSSource.h"
#import "rmsbuffer.h"
#import "rmslevels.h"

/*
	RMSSampleMonitor is a simple ringbuffer monitor which can be used by 
	multiple observers to display information about the latest samples. 
	This significantly reduces the strain on the real-time audio thread.
	
	The length count of the RMSSampleMonitor should obviously be appropriate 
	for the largest possible demand. 
*/


typedef struct RMSStereoLevels
{
	uint64_t index;
	rmslevels_t L;
	rmslevels_t R;
}
RMSStereoLevels;

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

- (NSRange) availableRange;
- (NSRange) availableRangeWithIndex:(uint64_t)index;

- (BOOL) getSamples:(float **)dstPtr count:(size_t)count;
- (BOOL) getSamples:(float **)dstPtr withRange:(NSRange)R;
- (void) getSamplesL:(float *)dstPtr withRange:(NSRange)R;
- (void) getSamplesR:(float *)dstPtr withRange:(NSRange)R;

- (rmsbuffer_t *) bufferAtIndex:(int)n;

- (void) updateLevels:(RMSStereoLevels *)levels;

- (void) addObserver:(id<RMSSampleMonitorObserverProtocol>)observer;
- (void) removeObserver:(id<RMSSampleMonitorObserverProtocol>)observer;
- (void) updateObservers;

@end
