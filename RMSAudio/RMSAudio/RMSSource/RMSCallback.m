////////////////////////////////////////////////////////////////////////////////
/*
	RMSCallback
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSCallback.h"



@interface RMSCallback ()
{
	RMSCallbackProcPtr mProcPtr;
}

@end


////////////////////////////////////////////////////////////////////////////////
@implementation RMSCallback
////////////////////////////////////////////////////////////////////////////////

+ (const RMSCallbackProcPtr) callbackPtr
{
#if DEBUG
	NSLog(@"%@", @"ERROR: no class global callbackPtr provided!");
	NSLog(@"%@", [NSThread callStackSymbols]);
#endif

	return nil;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (instancetype) init
{ return [self initWithCallbackPtr:[[self class] callbackPtr]]; }

////////////////////////////////////////////////////////////////////////////////

+ (instancetype) instanceWithCallbackPtr:(void *)procPtr
{ return [[self alloc] initWithCallbackPtr:procPtr]; }

- (instancetype) initWithCallbackPtr:(void *)procPtr
{
	self = [super init];
	if (self != nil)
	{
		mProcPtr = procPtr;
	}
	
	return self;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

OSStatus RunRMSCallback(void *objectPtr, const RMSCallbackInfo *infoPtr)
{
	return RMSCallbackBridge(objectPtr)->mProcPtr(objectPtr, infoPtr);
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////
