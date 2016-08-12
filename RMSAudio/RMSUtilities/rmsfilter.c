////////////////////////////////////////////////////////////////////////////////
/*
	rmsfilter
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#include "rmsfilter.h"
#include <math.h>

////////////////////////////////////////////////////////////////////////////////

double RMSFilterMultiplierWithCutoff(double Fc, double Fs)
{ return 1.0-exp(-2.0*M_PI * Fc / Fs); }

double RMSFilterAdjustMultiplier(double M, int order)
{
	double size = 1.0 / M;
	size = 1.0 + (size - 1.0) / order;
	return 1.0 / size;
}

////////////////////////////////////////////////////////////////////////////////

rmsfilter_t RMSFilterInitWithMultiplier(double M)
{ return (rmsfilter_t){ .A = 0.0, .M = M }; }

rmsfilter_t RMSFilterInitWithRateChange(double srcRate, double dstRate)
{
	double size = dstRate / srcRate;
	return RMSFilterInitWithMultiplier(1.0/size);
}

rmsfilter_t RMSFilterInitWithCutoff(double Fc, double Fs)
{
	double M = RMSFilterMultiplierWithCutoff(Fc, Fs);
	return RMSFilterInitWithMultiplier(M);
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

static inline float RMSFilterApply(rmsfilter_t *F, float S)
{
	F->A = S = FMA(F->M, S - F->A, F->A);
	return S;
}

////////////////////////////////////////////////////////////////////////////////

void RMSFilterRun(rmsfilter_t *F, float *ptr, uint32_t N)
{
	for (uint32_t n=0; n!=N; n++)
	{ ptr[n] = RMSFilterApply(F, ptr[n]); }
}

////////////////////////////////////////////////////////////////////////////////





