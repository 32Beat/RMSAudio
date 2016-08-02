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

OSStatus RunRMSChain(void *link, const RMSCallbackInfo *infoPtr)
{
	OSStatus result = noErr;
	
	link = RMSLinkGetLink(link);
	while (link != nil)
	{
		result = RunRMSSource(link, infoPtr);
		if (result != noErr) return result;
		
		link = RMSLinkGetLink(link);
	}
	
	return result;
}

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
	// Run the callback for self
	OSStatus result = RunRMSCallback(rmsObject, infoPtr);
	if (result != noErr) return result;
	
	// Run the filters if available
	void *filter = RMSSourceGetFilter(rmsObject);
	if (filter != nil)
	{
		result = RunRMSChain(filter, infoPtr);
		if (result != noErr) return result;
	}
	
	// Run the monitors if available
	void *monitor = RMSSourceGetMonitor(rmsObject);
	if (monitor != nil)
	{
		result = RunRMSChain(monitor, infoPtr);
		if (result != noErr) return result;
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
// macro for condensed, unmanaged access
// for use by the audiothread
#define RMSSourceBridge(objectPtr) \
((__bridge __unsafe_unretained RMSSource *)(objectPtr))
////////////////////////////////////////////////////////////////////////////////

void *RMSSourceGetSource(void *source)
{ return (__bridge void *)RMSSourceBridge(source)->mSource; }

void *RMSSourceGetFilter(void *source)
{ return (__bridge void *)RMSSourceBridge(source)->mFilter; }

void *RMSSourceGetMonitor(void *source)
{ return (__bridge void *)RMSSourceBridge(source)->mMonitor; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (RMSLink *) source
{
	if (mSource == nil)
	{ mSource = [RMSLink new]; }
	return mSource;
}

////////////////////////////////////////////////////////////////////////////////

- (RMSLink *) filter
{
	if (mFilter == nil)
	{ mFilter = [RMSLink new]; }
	return mFilter;
}

////////////////////////////////////////////////////////////////////////////////

- (RMSLink *) monitor
{
	if (mMonitor == nil)
	{ mMonitor = [RMSLink new]; }
	return mMonitor;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (void) setSource:(RMSSource *)source
{ [self addSource:source]; }

////////////////////////////////////////////////////////////////////////////////

- (void) addSource:(RMSSource *)source
{ [self.source addLink:source]; }

////////////////////////////////////////////////////////////////////////////////

- (void) insertSource:(RMSSource *)source
{ [self.source insertLink:source]; }

////////////////////////////////////////////////////////////////////////////////

- (void) removeSource:(RMSSource *)source
{ [mSource removeLink:source]; }

////////////////////////////////////////////////////////////////////////////////

- (void) removeSource
{ [mSource removeLink]; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark 
////////////////////////////////////////////////////////////////////////////////

- (void) setFilter:(RMSSource *)filter
{ [self addFilter:filter]; }

////////////////////////////////////////////////////////////////////////////////

- (void) addFilter:(RMSSource *)filter
{ [self.filter addLink:filter]; }

////////////////////////////////////////////////////////////////////////////////

- (void) insertFilter:(RMSSource *)filter
{ [self.filter insertLink:filter]; }

////////////////////////////////////////////////////////////////////////////////

- (void) removeFilter:(RMSSource *)filter
{ [mFilter removeLink:filter]; }

////////////////////////////////////////////////////////////////////////////////

- (void) removeFilter
{ [mFilter removeLink]; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark 
////////////////////////////////////////////////////////////////////////////////

- (void) setMonitor:(RMSSource *)monitor
{ [self addMonitor:monitor]; }

////////////////////////////////////////////////////////////////////////////////

- (void) addMonitor:(RMSSource *)monitor
{ [self.monitor addLink:monitor]; }

////////////////////////////////////////////////////////////////////////////////

- (void) insertMonitor:(RMSSource *)monitor
{ [self.monitor insertLink:monitor]; }

////////////////////////////////////////////////////////////////////////////////

- (void) removeMonitor:(RMSSource *)monitor
{ [mMonitor removeLink:monitor]; }

////////////////////////////////////////////////////////////////////////////////

- (void) removeMonitor
{ [mMonitor removeLink]; }

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
{
	[mSource makeLinksPerformSelector:@selector(setSampleRate:)
	withObject:[NSNumber numberWithDouble:sampleRate]];
}

- (void) setFilterSampleRate:(Float64)sampleRate
{
	[mFilter makeLinksPerformSelector:@selector(setSampleRate:)
	withObject:[NSNumber numberWithDouble:sampleRate]];
}

- (void) setMonitorSampleRate:(Float64)sampleRate
{
	[mMonitor makeLinksPerformSelector:@selector(setSampleRate:)
	withObject:[NSNumber numberWithDouble:sampleRate]];
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////
