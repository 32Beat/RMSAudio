////////////////////////////////////////////////////////////////////////////////
/*
	RMSCallback
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////
/*
	typedef AURenderCallback RMSCallbackProcPtr;

	The system AURenderCallback requires the following parameters:
	
		void 							*refCon,
		AudioUnitRenderActionFlags 		*actionFlags,
		const AudioTimeStamp 			*timeStamp,
		UInt32							busNumber,
		UInt32							frameCount,
		AudioBufferList 				*bufferList

	In order to reduce stack preparation for function calls, 
	we redefine the parameters supplied to the callback chain.
*/

typedef struct RMSCallbackInfo
{
	UInt64				frameIndex;
	UInt32				frameCount;
	AudioBufferList 	*bufferListPtr;
}
RMSCallbackInfo;

typedef OSStatus (*RMSCallbackProcPtr)
(void *objectPtr, const RMSCallbackInfo *info);

OSStatus RunRMSCallback
(void *objectPtr, const RMSCallbackInfo *info);

// macro for condensed, unmanaged access to the RMSCallback object
// for use by the audiothread
#define RMSCallbackBridge(objectPtr) \
((__bridge __unsafe_unretained RMSCallback *)objectPtr)

////////////////////////////////////////////////////////////////////////////////
/*
	RMSCallback
	-----------
	RMSCallback contains the callback logic for RMSSource objects.

	By default, the RMSCallbackProcPtr is assumed to be available thru
	the class global method "callbackPtr". This allows normal object 
	creation by using "new" or "init". The default refcon value supplied to 
	the RMSCallbackProcPtr is "self".
*/

@interface RMSCallback : NSObject

+ (const RMSCallbackProcPtr) callbackPtr;

@end
////////////////////////////////////////////////////////////////////////////////




