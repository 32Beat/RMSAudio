////////////////////////////////////////////////////////////////////////////////
/*
	RMSSource
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSSource.h"
#import "RMSUtilities.h"
#import "RMSAudio.h"

////////////////////////////////////////////////////////////////////////////////
/*
	Multithreading:
	Adding an object to the rendertree is not generally a problem
	Removing an object however is a problem requiring careful consideration.
 
	Strategy for removing objects from the rendertree:
	1. remove the object from the RMSSource connection, 
	2. insert it in the trash (linked list)
	
	3. renderCallback checks mTrash prior to rendering,
	4. if not nil, communicate mTrash as void* to main (mTrashSeen)
	5. on main, remove mTrashSeen from linked list
*/
@interface RMSSource ()
{
	RMSSource *mTrash;
	NSTimer *mTrashTimer;
	void *mTrashSeen;
}
@end

////////////////////////////////////////////////////////////////////////////////
@implementation RMSSource
////////////////////////////////////////////////////////////////////////////////
#pragma mark
#pragma mark Trash Management
////////////////////////////////////////////////////////////////////////////////

- (void) trashObject:(id)object
{
	if (object != nil)
	{ [self insertTrash:object]; }
	[self updateTrash:nil];
}

////////////////////////////////////////////////////////////////////////////////

- (void) insertTrash:(id)object
{
	if (mTrash != nil)
	{ [object insertTrash:mTrash]; }
	mTrash = object;
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeTrash:(void *)object
{
	if (mTrash == object)
	{ mTrash = nil; }
	else
	{ [mTrash removeTrash:object]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) updateTrash:(id)sender
{
	// Reset timer if necessary
	if (mTrashTimer == sender)
	{ mTrashTimer = nil; }
	
	if (mTrashSeen != nil)
	{
		[self removeTrash:mTrashSeen];
		mTrashSeen = nil;
	}
	
	// Try emptying more trash later if necessary
	if (mTrash != nil)
	{
		/*
			caller is either a previous timer, 
			or the trashObject method. In the latter case 
			there may already be an active timer.
		*/
		if (mTrashTimer == nil)
		{
			mTrashTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
			target:self selector:@selector(updateTrash:) userInfo:nil repeats:NO];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
/*

	Step 1:
	First communicate the current head of the trashlist to main. 
	This allows the main thread to eventually delete the associated objects. 
	
	Step 2:
	Run the callback routine for this object. 
	The callback should operate on the audiobuffers given in infoPtr.
	Depending on the character of the object, it should fill, edit,
	or simply read the buffer.
	
	Step 3:
	If there is any filter associated with this object,
	it should be run as a complete RMSSource. This will recursively call 
	filters attached to the initial filter.
	
	Step 4: 
	If there is any monitor associated with this object,
	it should be run after the filters as a complete source. 
	This will recursively call additional monitors.

*/

OSStatus RunRMSSource(void *rmsObject, const RMSCallbackInfo *infoPtr)
{
	__unsafe_unretained RMSSource *rmsSource =
	(__bridge __unsafe_unretained RMSSource *)rmsObject;



	// Communicate prerender trash to main
	if (rmsSource->mTrash != nil)
	{
		if (rmsSource->mTrashSeen == nil)
		{
			rmsSource->mTrashSeen = (__bridge void *)rmsSource->mTrash;
		}
	}
	
	
	
	// Run the callback for self
	OSStatus result = RunRMSCallback(rmsObject, infoPtr);
	if (result != noErr) return result;
	
	// Run the filters if available
	void *filter = RMSSourceGetFilter(rmsObject);
	if (filter != nil)
	{
		result = RunRMSSource(filter, infoPtr);
		if (result != noErr) return result;
	}
	
	// Run the monitors if available
	void *monitor = RMSSourceGetMonitor(rmsObject);
	if (monitor != nil)
	{
		result = RunRMSSource(monitor, infoPtr);
		if (result != noErr) return result;
	}
	
	
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

void *RMSSourceGetSource(void *source)
{ return (__bridge void *)((__bridge RMSSource *)source)->mSource; }

void *RMSSourceGetFilter(void *source)
{ return (__bridge void *)((__bridge RMSSource *)source)->mFilter; }

void *RMSSourceGetMonitor(void *source)
{ return (__bridge void *)((__bridge RMSSource *)source)->mMonitor; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (RMSSource *) source
{ return mSource; }

- (RMSSource *) filter
{ return mFilter; }

- (RMSSource *) monitor
{ return mMonitor; }

////////////////////////////////////////////////////////////////////////////////

- (void) setSource:(RMSSource *)source
{
	if (mSource != source)
	{
		id oldSource = mSource;
		
		if (self.shouldUpdateSource == YES)
		{ [source setSampleRate:self.sampleRate]; }
		
		mSource = source;

		[self trashObject:oldSource];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) addSource:(RMSSource *)source
{
	if (mSource == nil)
	{ [self setSource:source]; }
	else
	{ [mSource addSource:source]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeSource:(RMSSource *)source
{
	if (mSource == source)
	{ [self removeSource]; }
	else
	{ [mSource removeSource:source]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeSource
{
	if (mSource != nil)
	{ [self setSource:[mSource source]]; }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark 
////////////////////////////////////////////////////////////////////////////////

- (void) setFilter:(RMSSource *)filter
{
	if (mFilter != filter)
	{
		id oldFilter = mFilter;
		
		[filter setSampleRate:[self sampleRate]];
		mFilter = filter;
		
		[self trashObject:oldFilter];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) addFilter:(RMSSource *)filter
{
	if (self == filter)
	{ NSLog(@"%@", @"addFilter error!"); return; }
	
	if (mFilter == nil)
	{ [self setFilter:filter]; }
	else
	{ [mFilter addFilter:filter]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) insertFilter:(RMSSource *)filter
{
	if (mFilter != nil)
	{ [filter addFilter:mFilter]; }
	[self setFilter:filter];
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeFilter:(RMSSource *)filter
{
	if (mFilter == filter)
	{ [self removeFilter]; }
	else
	{ [mFilter removeFilter:filter]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeFilter
{
	if (mFilter != nil)
	{ [self setFilter:[mFilter filter]]; }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark 
////////////////////////////////////////////////////////////////////////////////

- (void) setMonitor:(RMSSource *)monitor
{
	if (mMonitor != monitor)
	{
		id oldMonitor = mMonitor;
		
		[monitor setSampleRate:[self sampleRate]];
		mMonitor = monitor;
		
		[self trashObject:oldMonitor];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) addMonitor:(RMSSource *)monitor
{
	if (self == monitor)
	{ NSLog(@"%@", @"addMonitor error!"); return; }

	if (mMonitor == nil)
	{ [self setMonitor:monitor]; }
	else
	{ [mMonitor addMonitor:monitor]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeMonitor:(RMSSource *)monitor
{
	if (mMonitor == monitor)
	{ [self removeMonitor]; }
	else
	{ [mMonitor removeMonitor:monitor]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeMonitor
{
	if (mMonitor != nil)
	{ [self setMonitor:[mMonitor monitor]]; }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (Float64) sampleRate
{ return mSampleRate != 0.0 ? mSampleRate : 44100.0; }

////////////////////////////////////////////////////////////////////////////////

- (void) setSampleRate:(Float64)sampleRate
{
	if (mSampleRate != sampleRate)
	{
		mSampleRate = sampleRate;
		if (self.shouldUpdateSource == YES)
		{ [self setSourceSampleRate:sampleRate]; }
		[self setFilterSampleRate:sampleRate];
		[self setMonitorSampleRate:sampleRate];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) setSourceSampleRate:(Float64)sampleRate
{ [mSource setSampleRate:sampleRate]; }

- (void) setFilterSampleRate:(Float64)sampleRate
{ [mFilter setSampleRate:sampleRate]; }

- (void) setMonitorSampleRate:(Float64)sampleRate
{ [mMonitor setSampleRate:sampleRate]; }

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////
