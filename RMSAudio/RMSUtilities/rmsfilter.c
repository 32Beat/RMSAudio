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

rmsfilter_t RMSFilterInitWithMultiplier(double M, int order)
{ return (rmsfilter_t){ .M = M, 0.0, 0.0, 0.0, 0.0, order }; }

rmsfilter_t RMSFilterInitWithRateChange(double srcRate, double dstRate, int order)
{
	double size = dstRate / srcRate;
	size = 1.0 + (size - 1.0) / order;
	return RMSFilterInitWithMultiplier(1.0/size, order);
}

rmsfilter_t RMSFilterInitWithCutoff(double Fc, double Fs, int order)
{
	double M = RMSFilterMultiplierWithCutoff(Fc, Fs);
	M = RMSFilterAdjustMultiplier(M, order);
	return RMSFilterInitWithMultiplier(M, order);
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

float RMSFilterApply1(rmsfilter_t *F, float S)
{
	F->A0 = S = FMA(F->M, S - F->A0, F->A0);
	return S;
}

float RMSFilterApply2(rmsfilter_t *F, float S)
{
	F->A0 = S = FMA(F->M, S - F->A0, F->A0);
	F->A1 = S = FMA(F->M, S - F->A1, F->A1);
	return S;
}

float RMSFilterApply3(rmsfilter_t *F, float S)
{
	F->A0 = S = FMA(F->M, S - F->A0, F->A0);
	F->A1 = S = FMA(F->M, S - F->A1, F->A1);
	F->A2 = S = FMA(F->M, S - F->A2, F->A2);
	return S;
}

float RMSFilterApply4(rmsfilter_t *F, float S)
{
	F->A0 = S = FMA(F->M, S - F->A0, F->A0);
	F->A1 = S = FMA(F->M, S - F->A1, F->A1);
	F->A2 = S = FMA(F->M, S - F->A2, F->A2);
	F->A3 = S = FMA(F->M, S - F->A3, F->A3);
	return S;
}

////////////////////////////////////////////////////////////////////////////////

void RMSFilterRun(rmsfilter_t *F, float *ptr, uint32_t N)
{
	if (F->order <= 1)
	for (uint32_t n=0; n!=N; n++)
	{ ptr[n] = RMSFilterApply1(F, ptr[n]); }
	else
	if (F->order == 2)
	for (uint32_t n=0; n!=N; n++)
	{ ptr[n] = RMSFilterApply2(F, ptr[n]); }
	else
	if (F->order == 3)
	for (uint32_t n=0; n!=N; n++)
	{ ptr[n] = RMSFilterApply3(F, ptr[n]); }
	else
	//if (F->order >= 4)
	for (uint32_t n=0; n!=N; n++)
	{ ptr[n] = RMSFilterApply4(F, ptr[n]); }
}

////////////////////////////////////////////////////////////////////////////////





