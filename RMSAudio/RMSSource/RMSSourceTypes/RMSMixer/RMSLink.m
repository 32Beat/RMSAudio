////////////////////////////////////////////////////////////////////////////////
/*
	RMSLink
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSLink.h"
#import "RMSUtilities.h"
#import "RMSAudio.h"


@interface RMSLink ()
{
	RMSLink *mLink;

	RMSLink *mTrash;
	NSTimer *mTrashTimer;
	void *mTrashSeen;
}
@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSLink
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
// macro for condensed, unmanaged access
// for use by the audiothread
#define RMSLinkBridge(objectPtr) \
((__bridge __unsafe_unretained RMSLink *)(objectPtr))
////////////////////////////////////////////////////////////////////////////////

void *RMSLinkGetLink(void *linkPtr)
{ return (__bridge void *)RMSLinkBridge(linkPtr)->mLink; }

void RMSLinkUpdateTrash(void *linkPtr)
{
	__unsafe_unretained RMSLink *link =
	(__bridge __unsafe_unretained RMSLink *)linkPtr;

	// Communicate current trash to main
	if (link != nil && link->mTrash != nil)
	{
		if (link->mTrashSeen == nil)
		{
			link->mTrashSeen = (__bridge void *)link->mTrash;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (id) link
{ return mLink; }

////////////////////////////////////////////////////////////////////////////////

- (void) setLink:(RMSLink *)link
{
	if (mLink != link)
	{
		id trash = mLink;
		mLink = link;
		[self trashObject:trash];
	}
}

////////////////////////////////////////////////////////////////////////////////

- (void) addLink:(RMSLink *)link
{
	if (mLink == nil)
	{ [self setLink:link]; }
	else
	{ [mLink addLink:link]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) insertLink:(RMSLink *)link
{
	if (mLink != nil)
	{ [link addLink:mLink]; }
	[self setLink:link];
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeLink:(RMSLink *)link
{
	if (mLink == link)
	{ [self removeLink]; }
	else
	{ [mLink removeLink:link]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) removeLink
{
	if (mLink != nil)
	{ [self setLink:[mLink link]]; }
}

////////////////////////////////////////////////////////////////////////////////

- (void) makeLinksPerformSelector:(SEL)selector withObject:(id)object
{
	RMSLink *link = self.link;
	while (link != nil)
	{
		[link performSelector:selector withObject:object];
		link = link.link;
	}
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////
