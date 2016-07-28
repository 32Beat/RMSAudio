////////////////////////////////////////////////////////////////////////////////
/*
	rmsbuffer_t
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#ifndef rmsbuffer_t_h
#define rmsbuffer_t_h

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

////////////////////////////////////////////////////////////////////////////////
/*
	rmsbuffer_t
	-----------
	Simple general purpose ringbuffer type (without multithreading guards)
	
	usage indication:

		start buffer with desired size
		
			rmsbuffer_t buffer = RMSBufferBegin(sampleCount);
		
		release internal memory when done
		
			RMSBufferEnd(&buffer);
 
	
	Field definitions:
 
		index
		Represents the next virtual write location, or, more specifically,
		the total number of samples written to the buffer so far. It is 
		continuously increased with every write action, without regard for 
		the actual ringBuffer length.
		
		indexMask
		Mask used to limit index to an actual ringBuffer location.
		The length of the ringBuffer always is a power of 2 equal to indexMask+1.
		Any index can simply be masked with a binary AND to find an actual
		ringBuffer location.
		
		sampleData
		pointer to memory created with calloc
	
	Notes:
		The actual length of the ringBuffer will always be a power of 2
		being at least as large as sampleCount supplied at initialization
*/
////////////////////////////////////////////////////////////////////////////////

typedef struct rmsbuffer_t
{
	uint64_t index; // represents next empty slot = number of samples processed
	uint64_t indexMask; // indexMask+1 = length of sampleData
	float   *sampleData;
}
rmsbuffer_t;

typedef struct rmsrange_t
{
	uint64_t index;
	uint64_t count;
}
rmsrange_t;

////////////////////////////////////////////////////////////////////////////////

// Start bufferstruct with internal memory
rmsbuffer_t RMSBufferBegin(size_t maxSampleCount);

// Release internal memory
void RMSBufferEnd(rmsbuffer_t *buffer);

////////////////////////////////////////////////////////////////////////////////

// reset index and clear all samples
void RMSBufferReset(rmsbuffer_t *bufferPtr);

// clear all samples
void RMSBufferClear(rmsbuffer_t *bufferPtr);

////////////////////////////////////////////////////////////////////////////////

void RMSBufferWriteSamples(rmsbuffer_t *bufferPtr, float *srcPtr, size_t N);
void RMSBufferReadSamplesFromIndex(rmsbuffer_t *bufferPtr, uint64_t index, float *dstPtr, size_t N);

int RMSBufferCompareData(rmsbuffer_t *B1, rmsbuffer_t *B2);

////////////////////////////////////////////////////////////////////////////////

// Get & Set sample at current index modulo buffersize
float RMSBufferGetSample(rmsbuffer_t *buffer);
void RMSBufferSetSample(rmsbuffer_t *buffer, float S);

// Get & Set sample at specific index modulo buffersize
float RMSBufferGetSampleAtIndex(rmsbuffer_t *buffer, int64_t index);
void RMSBufferSetSampleAtIndex(rmsbuffer_t *buffer, int64_t index, float S);

// Get & Set sample at (current index + offset) modulo buffersize
float RMSBufferGetSampleAtOffset(rmsbuffer_t *buffer, int64_t offset);
void RMSBufferSetSampleAtOffset(rmsbuffer_t *buffer, int64_t offset, float S);

////////////////////////////////////////////////////////////////////////////////

// Get sample at offset = -sampleDelay
float RMSBufferGetSampleWithDelay(rmsbuffer_t *buffer, uint32_t sampleDelay);
double RMSBufferGetValueWithDelay(rmsbuffer_t *buffer, double sampleDelay);
double RMSBufferGetValueWithDelayCR(rmsbuffer_t *buffer, double sampleDelay);

float RMSBufferGetValueAtOffset(rmsbuffer_t *buffer, double offset);
float RMSBufferGetAverage(rmsbuffer_t *buffer, rmsrange_t R);
float RMSBufferGetMin(rmsbuffer_t *buffer, rmsrange_t R);
float RMSBufferGetMax(rmsbuffer_t *buffer, rmsrange_t R);

// Update index, then set sample at index modulo buffersize
void RMSBufferWriteSample(rmsbuffer_t *buffer, float S);

void RMSBufferWriteSuperSample(rmsbuffer_t *buffer, float y);
////////////////////////////////////////////////////////////////////////////////
#endif // rmsbuffer_t_h
////////////////////////////////////////////////////////////////////////////////






