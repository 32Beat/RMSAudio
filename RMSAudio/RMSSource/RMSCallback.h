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
	The system AURenderCallback requires the following parameters:
	
		void 							*refCon,
		AudioUnitRenderActionFlags 		*actionFlags,
		const AudioTimeStamp 			*timeStamp,
		UInt32							busNumber,
		UInt32							frameCount,
		AudioBufferList 				*bufferList

	In order to reduce stack preparation for function calls, 
	we redefine the parameters supplied to the callback chain.
	
	In abstract a render function then looks like this:
	
		procPtr(dataPtr, infoPtr)
	
	dataPtr = the refCon value, typically will be an RMSSource pointer
	infoPtr = the timing info and the corresponding bufferList
*/

// refCon value
typedef void RMSCallbackData;

// timing & buffer info
typedef struct RMSCallbackInfo
{
	UInt64				frameIndex;
	UInt32				frameCount;
	AudioBufferList 	*bufferListPtr;
}
RMSCallbackInfo;

// callback function
typedef OSStatus (RMSCallbackProc)
(RMSCallbackData *dataPtr, const RMSCallbackInfo *infoPtr);

// corresponding pointertypes
typedef RMSCallbackProc *RMSCallbackProcPtr;
typedef RMSCallbackData *RMSCallbackDataPtr;
typedef RMSCallbackInfo *RMSCallbackInfoPtr;
////////////////////////////////////////////////////////////////////////////////
/*
	RunRMSCallback
	--------------
	Triggers the callback function of an RMSCallback object via direct access.
	Meant to be used by the audiothread for running the callback function of 
	any RMSSource object using unmanaged access (unsafe, unretained).
	Object existence should obviously be guaranteed by the main thread.
	
	See also RunRMSSource in RMSSource
*/
OSStatus RunRMSCallback
(void *objectPtr, const RMSCallbackInfo *info);


////////////////////////////////////////////////////////////////////////////////
/*
	RMSCallback
	-----------
	RMSCallback contains the callback logic for RMSSource objects.

	By default, the RMSCallbackProcPtr is assumed to be available thru
	the class global method "callbackProcPtr". This allows normal object
	creation by using "new" or "init". 
	
	The default refcon value supplied to the RMSCallbackProcPtr is "self".
	If a custom refcon value is desired, overwrite callbackDataPtr. 
	(See RMSSampleMonitor for an example).
*/

@interface RMSCallback : NSObject

+ (const RMSCallbackProcPtr) callbackProcPtr;
- (const RMSCallbackDataPtr) callbackDataPtr;

@end
////////////////////////////////////////////////////////////////////////////////




