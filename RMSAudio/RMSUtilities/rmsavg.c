////////////////////////////////////////////////////////////////////////////////
/*
	rmsavg
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#include "rmsavg.h"
#include <math.h>

////////////////////////////////////////////////////////////////////////////////

double RMSAverageMultiplierWithCutoff(double Fc, double Fs)
{ return 1.0-exp(-2.0*M_PI * Fc / Fs); }

////////////////////////////////////////////////////////////////////////////////

rmsavg_t RMSAverageInitWithSize(double size)
{ return (rmsavg_t){ .A = 0.0, .M = 1.0/size }; }

rmsavg_t RMSAverageInitWithMultiplier(double M)
{ return (rmsavg_t){ .A = 0.0, .M = M }; }

rmsavg_t RMSAverageInitWithRateChange(double srcRate, double dstRate)
{
	double size = dstRate / srcRate;
	return RMSAverageInitWithSize(size);
}

////////////////////////////////////////////////////////////////////////////////

static inline float FMA(float A, float B, float C)
{
#ifdef FP_FAST_FMAF
	return fmaf(A, B, C);
#else
	return A*B+C;
#endif
}

////////////////////////////////////////////////////////////////////////////////

float RMSAverageUpdate(rmsavg_t *avgPtr, float S)
{
	avgPtr->A = FMA(avgPtr->M, S - avgPtr->A, avgPtr->A);
	return avgPtr->A;
}

////////////////////////////////////////////////////////////////////////////////

void RMSAverageRun(rmsavg_t *avgPtr, float *ptr, uint32_t N)
{
	double A = avgPtr->A;
	double M = avgPtr->M;
	
	for (uint32_t n=0; n!=N; n++)
	{ ptr[n] = (A += (ptr[n] - A) * M); }
	
	avgPtr->A = A;
}

////////////////////////////////////////////////////////////////////////////////





