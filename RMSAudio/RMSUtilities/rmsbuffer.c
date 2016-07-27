////////////////////////////////////////////////////////////////////////////////
/*
	rmsbuffer_t
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#include "rmsbuffer.h"
#include <string.h>
#include <math.h>


////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

rmsbuffer_t RMSBufferBegin(size_t maxSampleCount)
{
	size_t sampleCount = 4;
	while (sampleCount < maxSampleCount)
	{ sampleCount <<= 1; }
	
	return (rmsbuffer_t)
	{
		.index = 0,
		.indexMask = sampleCount-1,
		.sampleData = calloc(sampleCount, sizeof(float))
	};
}

////////////////////////////////////////////////////////////////////////////////

void RMSBufferEnd(rmsbuffer_t *buffer)
{
	if (buffer != NULL)
	{
		if (buffer->sampleData != NULL)
		{
			free(buffer->sampleData);
			buffer->sampleData = NULL;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////

rmsbuffer_t *RMSBufferNew(size_t maxSampleCount)
{
	rmsbuffer_t *bufferPtr = malloc(sizeof(rmsbuffer_t));
	if (bufferPtr != NULL)
	{
		bufferPtr[0] = RMSBufferBegin(maxSampleCount);
		if (bufferPtr->sampleData != NULL)
		{
			return bufferPtr;
		}
		
		free(bufferPtr);
	}
	
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////

rmsbuffer_t *RMSBufferRelease(rmsbuffer_t *bufferPtr)
{
	if (bufferPtr != NULL)
	{
		if (bufferPtr->sampleData != NULL)
		{ free(bufferPtr->sampleData); }

		free(bufferPtr);
	}
	
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

void RMSBufferReset(rmsbuffer_t *bufferPtr)
{
	bufferPtr->index = 0;
	RMSBufferClear(bufferPtr);
}

////////////////////////////////////////////////////////////////////////////////

void RMSBufferClear(rmsbuffer_t *bufferPtr)
{
	uint64_t n = (bufferPtr->indexMask + 1) >> 1;

	while (n != 0)
	{
		((uint64_t *)bufferPtr->sampleData)[(n -= 1)] = 0;
		((uint64_t *)bufferPtr->sampleData)[(n -= 1)] = 0;
	}
}

////////////////////////////////////////////////////////////////////////////////

static inline void CopyFloats(float *srcPtr, float *dstPtr, size_t n)
{ memcpy(dstPtr, srcPtr, n<<2); }

void RMSBufferWriteSamples(rmsbuffer_t *bufferPtr, float *srcPtr, size_t N)
{
	float *dstPtr = bufferPtr->sampleData;
	uint64_t indexMask = bufferPtr->indexMask;
//*
	uint64_t index = bufferPtr->index;
	uint64_t count = indexMask + 1;
	
	// compute index in ringbuffer
	index &= indexMask;
	// compute remaining buffercount until end-of-buffer
	count -= index;
	
	// if N fits the remaining buffercount...
	if (N <= count)
	{
		// ... copy directly to index
		CopyFloats(&srcPtr[0], &dstPtr[index], N);
		bufferPtr->index += N;
	}
	else
	// if N exceeds remaining buffercount...
	{
		// ... first copy to index and up to end-of-buffer
		CopyFloats(&srcPtr[0], &dstPtr[index], count);
		bufferPtr->index += count;
		
		N -= count;
		
		// ... then copy remainder to start-of-buffer
		CopyFloats(&srcPtr[count], &dstPtr[0], N);
		bufferPtr->index += N;
	}
	
/*/
	for (size_t n=0; n!=N; n++)
	{
		uint64_t index = bufferPtr->index+1;
		dstPtr[index&indexMask] = srcPtr[n];
		bufferPtr->index = index;
	}
//*/
}

////////////////////////////////////////////////////////////////////////////////

void RMSBufferReadSamplesFromIndex
(rmsbuffer_t *bufferPtr, uint64_t index, float *dstPtr, size_t N)
{
	if (bufferPtr && bufferPtr->sampleData)
	{
		float *srcPtr = bufferPtr->sampleData;
		uint64_t indexMask = bufferPtr->indexMask;
		
		for (size_t n=0; n!=N; n++)
		{
			dstPtr[n] = srcPtr[index&indexMask];
			index++;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

float RMSBufferGetSampleAtIndex(rmsbuffer_t *buffer, int64_t index)
{ return buffer->sampleData[index&buffer->indexMask]; }

void RMSBufferSetSampleAtIndex(rmsbuffer_t *buffer, int64_t index, float S)
{ buffer->sampleData[index&buffer->indexMask] = S; }

float RMSBufferGetSampleAtOffset(rmsbuffer_t *buffer, int64_t offset)
{ return RMSBufferGetSampleAtIndex(buffer, buffer->index+offset); }

void RMSBufferSetSampleAtOffset(rmsbuffer_t *buffer, int64_t offset, float S)
{ RMSBufferSetSampleAtIndex(buffer, buffer->index+offset, S); }

////////////////////////////////////////////////////////////////////////////////

float RMSBufferGetSample(rmsbuffer_t *buffer)
{ return RMSBufferGetSampleAtIndex(buffer, buffer->index); }

void RMSBufferSetSample(rmsbuffer_t *buffer, float S)
{ RMSBufferSetSampleAtIndex(buffer, buffer->index, S); }

// TODO: first write, then update index
void RMSBufferWriteSample(rmsbuffer_t *buffer, float S)
{ RMSBufferSetSampleAtIndex(buffer, (buffer->index += 1), S); }

////////////////////////////////////////////////////////////////////////////////

float RMSBufferGetSampleWithDelay(rmsbuffer_t *buffer, uint32_t sampleDelay)
{
	uint64_t index = buffer->index;
	uint64_t indexMask = buffer->indexMask;	
	return buffer->sampleData[(index-sampleDelay)&indexMask];
}

////////////////////////////////////////////////////////////////////////////////

double RMSBufferGetValueWithDelay(rmsbuffer_t *buffer, double sampleDelay)
{
	uint64_t index = buffer->index;
	uint64_t indexMask = buffer->indexMask;
	
	index -= (int64_t)sampleDelay;
	float *sampleData = (float *)buffer->sampleData;
	double R0 = sampleData[(index-0)&indexMask];
	double R1 = sampleData[(index-1)&indexMask];
	
	double M = sampleDelay - trunc(sampleDelay);
	
	return R0 + M * (R1 - R0);
}

////////////////////////////////////////////////////////////////////////////////

static double Bezier
(double x, double P1, double C1, double C2, double P2)
{
	P1 += x * (C1 - P1);
	C1 += x * (C2 - C1);
	C2 += x * (P2 - C2);
	
	P1 += x * (C1 - P1);
	C1 += x * (C2 - C1);

	P1 += x * (C1 - P1);

	return P1;
}

////////////////////////////////////////////////////////////////////////////////

static double CRCompute
(double x, double Y0, double Y1, double Y2, double Y3)
{
	static const double a = (1.0/4.0);
	double d1 = a * (Y2 - Y0);
	double d2 = a * (Y3 - Y1);
	return Bezier(x, Y1, Y1+d1, Y2-d2, Y2);
}

////////////////////////////////////////////////////////////////////////////////

double RMSBufferGetValueWithDelayCR(rmsbuffer_t *buffer, double sampleDelay)
{
	uint64_t index = buffer->index;
	uint64_t indexMask = buffer->indexMask;
	
	float *sampleData = (float *)buffer->sampleData;
	double M = sampleDelay - trunc(sampleDelay);
	
	int64_t D = sampleDelay;
	if (D != 0)
	{
		index -= D-1;

		double R0 = sampleData[(index-0)&indexMask];
		double R1 = sampleData[(index-1)&indexMask];
		double R2 = sampleData[(index-2)&indexMask];
		double R3 = sampleData[(index-3)&indexMask];
	
		return CRCompute(M, R0, R1, R2, R3);
	}

	// Edge case, use 3 samples only
	double R0 = sampleData[(index-0)&indexMask];
	double R1 = sampleData[(index-1)&indexMask];
	double R2 = sampleData[(index-2)&indexMask];
	double C1 = R1-(1.0/6.0)*(R2-R0);
	double C0 = R0+(1.0/2.0)*(C1-R0);
	return Bezier(M, R0, C0, C1, R1);
}

////////////////////////////////////////////////////////////////////////////////

float RMSBufferStepSizeForFrequency(rmsbuffer_t *buffer, float F)
{ return F / (buffer->indexMask + 1.0); }

float RMSBufferGetValueAtOffset(rmsbuffer_t *buffer, double offset)
{
	uint64_t index = offset;
	uint64_t indexMask = buffer->indexMask;
	
	float R0 = buffer->sampleData[(index+0)&indexMask];
	float R1 = buffer->sampleData[(index+1)&indexMask];
	
	float M = offset - truncf(offset);
	
	return R0 + M * (R1 - R0);
}

////////////////////////////////////////////////////////////////////////////////

float RMSBufferGetAverage(rmsbuffer_t *buffer, rmsrange_t R)
{
	uint64_t index = R.index;
	uint64_t count = R.count;
	uint64_t indexMask = buffer->indexMask;
	
	float S = buffer->sampleData[index&indexMask];

	while (--count != 0)
	{ S += buffer->sampleData[(++index)&indexMask]; }
	
	return S / R.count;
}

////////////////////////////////////////////////////////////////////////////////

float RMSBufferGetMin(rmsbuffer_t *buffer, rmsrange_t R)
{
	uint64_t index = R.index;
	uint64_t count = R.count;
	uint64_t indexMask = buffer->indexMask;
	
	float M = buffer->sampleData[index&indexMask];

	while (--count != 0)
	{
		float T = buffer->sampleData[(++index)&indexMask];
		if (M > T) M = T;
	}
	
	return M;
}

////////////////////////////////////////////////////////////////////////////////

float RMSBufferGetMax(rmsbuffer_t *buffer, rmsrange_t R)
{
	uint64_t index = R.index;
	uint64_t count = R.count;
	uint64_t indexMask = buffer->indexMask;
	
	float M = buffer->sampleData[index&indexMask];

	while (--count != 0)
	{
		float T = buffer->sampleData[(++index)&indexMask];
		if (M < T) M = T;
	}
	
	return M;
}

////////////////////////////////////////////////////////////////////////////////
/*
	UNDER CONSTRUCTION
	------------------
	
	An oversampled buffer, using int32 types so we can use 
	Turkowski/Gabriel decimators.
*/
void RMSBufferWriteSuperSample(rmsbuffer_t *buffer, float y)
{
	uint64_t index = buffer->index;
	uint64_t indexMask = buffer->indexMask;

	int32_t *sampleData = (int32_t *)buffer->sampleData;
	int32_t Y0 = sampleData[(index - 4)&indexMask];
	int32_t Y1 = sampleData[(index - 2)&indexMask];
	int32_t Y2 = sampleData[(index - 0)&indexMask];
	int32_t Y3 = round(0x10000000 * y);

	index += 2;
	sampleData[(index - 0)&indexMask] = Y3;
	sampleData[(index - 1)&indexMask] = (Y2+Y3)>>1;

	int32_t A1 = Y1+Y2;
	int32_t A2 = Y0+Y3;
	sampleData[(index - 3)&indexMask] = ((A1<<3) + A1 - A2)>>4;
	
	buffer->index = index;
}

////////////////////////////////////////////////////////////////////////////////







