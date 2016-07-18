# RMSAudio
## Objective-C AudioEngine for OSX and iOS

RMSAudio is an experiment in designing a simple and comprehensive audio management structure in Objective-C for the Mac OS family. The design principles are based on the following logic: 

1. Connecting objects should be simple and intuitive, in other words, no AUGraph, no separate render trees etc. Connecting objects automatically is the tree. 
2. Nodes and leaves are exponents of a single parent. It is as easy to connect a single object, as it is to connect an entire tree.
3. Separation of object management and audiothread code. While object management is done in Objective-C, rendering is done in C. Hooks are used to maintain inheritance, and object existence is guarded for the audiothread without the need for locks. 

Furthermore writing experimental code to test audio algorithms should be extremely easy to accomplish. It preferably does not require setting up a full environment and writing an entire audiounit.

As an example, PlayThru (from mic to output) is as simple as: 

    self.audioOutput = [RMSOutput defaultOutput];
    self.audioOutput.source = [RMSInput defaultInput];
   
That just works. It even works with different sampleRates between input and output, as the RMSInput has a simple linear-interpolating ringbuffer build in, and the output object automatically sets the samplerate of its source. Setting the sampleRate of a source always refers to the “outputscope” of that source. 

If a more sophisticated algorithm would be desired for sampleRate conversion, it is just as simple to add the Varispeed audiounit in between input and output: 
```obj-c
RMSSource *source = [RMSInput defaultInput];

if (source.sampleRate != self.audioOutput.sampleRate)
{ source = [RMSAudioUnitVarispeed instanceWithSource:source]; }

self.audioOutput.source = source;
```
Which builds a simple tree: input->varispeed->output


## Core object: RMSSource
The core object behind the RMSAudio structure is the RMSSource object. It contains the callback management for producing/manipulating audiosamples, and it also contains the rendertree management by incorporating the ability to connect to other RMSSource objects. Any properly implemented object based on RMSSource can be attached to another RMSSource. RMSSource objects can be a node as well as a leaf in the rendertree. Even the default input and output objects are based on RMSSource. 

There are three distinct connections: a source connection, a filter connection, and a monitor connection. They are processed in that order. 
 * A source connection can be used by an object to produce audio. A variospeed filter for example, can have a fileplayer connected to its source. 
 * The filter connection can be used to add objects that manipulate the audiosamples previously produced by self. The RMSVolume filter is a prime example: it multiplies existing samples to produce proper volume, balance, and gain control. 
 * The monitor connection can be used to monitor results of the rendertree after the particular object has produced and filtered its samples. Levelmonitoring is an obvious example. 


## Stacking Filters
An RMSSource object by default contains ivars for a source, a filter, and a monitor. In some scenarios it will be necessary to connect several filters in a chain. In RMSAudio objects this is accomplished by a linked list approach. Instead of setting the filter connection directly using "setFilter:", you can use "addFilter:" which will traverse the filter chain until an empty slot is encountered. 

While that is not necessarily the best approach for object programming, it is very useful in the context of the audiothread. 
For symmetry this approach is available for the source ivar as well, but using it for that case requires utmost care. It might be useful however for stacking additive oscillators in an FM generator for example.

RMSSource objects are interchangeable, so the order mentioned above is merely the default processing logic: first produce audio, then filter audio, then monitor the results. If however, intermediate monitoring is desired, it is perfectly fine to add a monitor in the filterchain.


## Writing a custom RMSSource
To create your own RMSSource you need to implement a C callback function within the implementation scope. In template form it typically looks like this:
```obj-c
static OSStatus renderCallback(void *objectPtr, RMSCallbackInfo *infoPtr)
{
	__unsafe_unretained MyRMSSource *rmsObject =
	(__bridge __unsafe_unretained MyRMSSource *)objectPtr;

	OSStatus result = noErr;
	
	// Fill buffers in infoPtr->bufferListPtr 

	return result;
}


+ (RMSCallbackProcPtr) callbackPtr
{ return renderCallback; }

```

The class globalscope callbackPtr method allow "new" and "init" to do all the required initialization. Getting your code to run then is as simple as:

```obj-c
self.audioOutput.source = [MyRMSSource new];
```
