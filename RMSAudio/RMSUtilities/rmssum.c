////////////////////////////////////////////////////////////////////////////////
/*
	rmssum
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#include "rmssum.h"
#include <math.h>


struct rmssum_t
{
	float S;
	float M;
	uint32_t N;
	uint32_t index;
	float A[];
};

////////////////////////////////////////////////////////////////////////////////

#ifdef FP_FAST_FMAF
#define rms_add(A, B, C) fmaf((A), (B), (C))
#else
#define rms_add(A, B, C) ((A)*(B)+(C))
#endif

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

rmssum_t *RMSSumNew(uint32_t N)
{
	rmssum_t *sumPtr = malloc(sizeof(rmssum_t)+N*sizeof(float));
	if (sumPtr != NULL)
	{
		sumPtr->S = 0.0;
		sumPtr->M = N & 0x01 ? 1.0/N : 1.0/(N+N);
		sumPtr->N = N;
		sumPtr->index = 0;
		for (int n=0; n!=N; n++)
		{ sumPtr->A[n] = 0.0; }
	}
	
	return sumPtr;
}

////////////////////////////////////////////////////////////////////////////////

void RMSSumRelease(rmssum_t *sumPtr)
{
	if (sumPtr != NULL)
	{
		free(sumPtr);
	}
}

////////////////////////////////////////////////////////////////////////////////

static inline float RMSSumUpdate(rmssum_t *sum, float S)
{
	uint32_t i = sum->index;
	
	sum->S -= sum->A[i];
	sum->A[i] = S;
	sum->S += sum->A[i];
	
	if (i == 0)
	{ i = sum->N; }
	sum->index = i-1;
	
	return sum->S;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark Average
////////////////////////////////////////////////////////////////////////////////

void RMSSumRunAverage(rmssum_t *sumPtr, float *ptr, size_t N)
{
	if (sumPtr->N & 0x01)
	{
		for (size_t n=0; n!=N; n++)
		{ ptr[n] = sumPtr->M * RMSSumUpdate(sumPtr, ptr[n]); }
	}
	else
	{
		for (size_t n=0; n!=N; n++)
		{ ptr[n] = sumPtr->M * (sumPtr->S + RMSSumUpdate(sumPtr, ptr[n])); }
	}
}

////////////////////////////////////////////////////////////////////////////////

float RMSSumUpdateAverage2(rmssum_t **sumPtr, float M, float S)
{
	S = RMSSumUpdate(sumPtr[0], S);
	S = RMSSumUpdate(sumPtr[1], S);
	return S * M;
}

////////////////////////////////////////////////////////////////////////////////

void RMSSumRunAverage2(rmssum_t **sumPtr, float *ptr, size_t N)
{
	float M = sumPtr[0]->M * sumPtr[1]->M;
	for (size_t n=0; n!=N; n++)
	{
		ptr[n] = RMSSumUpdateAverage2(sumPtr, M, ptr[n]);
	}
}

////////////////////////////////////////////////////////////////////////////////



