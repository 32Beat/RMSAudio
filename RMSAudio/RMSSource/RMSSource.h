////////////////////////////////////////////////////////////////////////////////
/*
	RMSSource
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////
/*
	RMSSource
	---------
	Rootobject of the RMSAudio rendertree
	
	RMSSource is based on the RMSCallback object which provides the renderlogic,
	and contains three connectors for connecting to other RMSSource objects.
	A source connector, a filter connector, and a monitor connector.
	
		mSource
		Can be used by self to produce audiosamples,
		
		mFilter
		Meant to attach objects that adjust the samples produced by self
		
		mMonitor 
		Meant to attach objects that merely read the samples produced by self
	
	
	Recursion is established thru RunRMSSource, which calls RunRMSSource on the 
	connectors as well. The default implementation first runs the callback of
	the current object, and then runs the filter and monitor connections.
	In pseudo template form:
 
		RMSSourceRun(this)
		{
			RMSCallbackRun(this->callback);
 
			RMSSourceRun(this->filter);
			RMSSourceRun(this->monitor);
		}
	
	The callback can call RunRMSSource on this->source if desired.
	
	If this->filter contains itself a filter, it will be run eventually. 
	As will all filters in the chain: this->filter->filter>filter...
	To attach a filter to the end of this chain, the RMSSource object 
	contains a "convenience" method called "addFilter:"
	In pseudo template form:

		addFilter:filter
		{
			if (this->filter == nil)
				this->filter = filter // Set filter
			else
				this->filter->addFilter:filter // Hand it down the chain
		}
 
	idem for monitors.
	
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSCallback.h"

@interface RMSSource : RMSCallback
{
	Float64 mSampleRate;

	RMSSource *mSource;
	RMSSource *mFilter;
	RMSSource *mMonitor;
}

////////////////////////////////////////////////////////////////////////////////
@property (nonatomic, assign) BOOL shouldUpdateSource;

- (RMSSource *) source;
- (void) setSource:(RMSSource *)source;
- (void) addSource:(RMSSource *)source;
- (void) removeSource:(RMSSource *)source;
- (void) removeSource;

- (RMSSource *) filter;
- (void) setFilter:(RMSSource *)filter;
- (void) addFilter:(RMSSource *)filter;
- (void) insertFilter:(RMSSource *)filter;
- (void) removeFilter:(RMSSource *)filter;
- (void) removeFilter;

- (RMSSource *) monitor;
- (void) setMonitor:(RMSSource *)monitor;
- (void) addMonitor:(RMSSource *)monitor;
- (void) removeMonitor:(RMSSource *)monitor;
- (void) removeMonitor;

////////////////////////////////////////////////////////////////////////////////

- (Float64) sampleRate;
- (void) setSampleRate:(Float64)sampleRate;

////////////////////////////////////////////////////////////////////////////////

- (void) trashObject:(id)object;

// Get the value of the corresponding objectpointers in an RMSSource
void *RMSSourceGetSource(void *source);
void *RMSSourceGetFilter(void *source);
void *RMSSourceGetMonitor(void *source);

@end

////////////////////////////////////////////////////////////////////////////////
/*
	RunRMSSource
	------------
	Run the callback of an RMSSource variant, 
	in AudioUnit parlance this would be the equivalent of AudioUnitRender
	
	Can be used in a rendercallback to produce audio from a source
*/
OSStatus RunRMSSource(void *rmsObject, const RMSCallbackInfo *infoPtr);

////////////////////////////////////////////////////////////////////////////////







