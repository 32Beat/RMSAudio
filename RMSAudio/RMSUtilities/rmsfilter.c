////////////////////////////////////////////////////////////////////////////////
/*
	rmsfilter
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#include "rmsfilter.h"
#include "rmsavg.h"
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
{
	return (rmsfilter_t)
	{
		.V = 0.0,
		.M = M,
		.E = 0.0,
		.R = 0.0
	};
}

////////////////////////////////////////////////////////////////////////////////

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
/*
static inline float RMSTestApply(rmsfilter_t *F, float S)
{
	double E = S - F->V;

	F->E *= (1.0-F->M);
	E *= F->M;
	F->V += F->E * F->R;
	F->E += E;
	F->V += E;
	
	return F->V;
}
*/




static inline float FMA(float A, float B, float C)
{
#ifdef FP_FAST_FMAF
	return fmaf(A, B, C);
#else
	return A*B+C;
#endif
}

////////////////////////////////////////////////////////////////////////////////
/*
double RMSOscillatorNext(rmsfilter_t *F)
{
	double E = 0.0 - F->V;
	F->E += E * F->R;
	F->V += F->E;
	return F->V;
}

resonance
resonant
averaged
average
default


*/

void RMSFilterRunRES(rmsfilter_t *F, float *ptr, uint32_t N)
{
	const double M = F->M;
	const double R = F->R;
	
	for(uint32_t n=0; n!=N; n++)
	{
		// fetch source
		double S = ptr[n];
		
		// compute errors
		double E = S - F->V;
		double Ep = E * M;
		double Ei = F->E + (E - F->E) * M;
		
		// interpolate between flat error and resonant error
		E = Ep + (Ei - Ep) * R;

		// update filter
		F->E = Ei;
		F->V = F->V + E;
		
		// write result
		ptr[n] = F->V;
	}
}

////////////////////////////////////////////////////////////////////////////////

void RMSFilterRunAVG(rmsfilter_t *F, float *ptr, uint32_t N)
{
	for(uint32_t n=0; n!=N; n++)
	{ ptr[n] = (F->V += (ptr[n] - F->V) * F->M); }
}

////////////////////////////////////////////////////////////////////////////////

void RMSFilterRun(rmsfilter_t *F, float *ptr, uint32_t N)
{
	if (F->R > 0.0)
	{ RMSFilterRunRES(F, ptr, N); }
	else
	{ RMSFilterRunAVG(F, ptr, N); }
}

////////////////////////////////////////////////////////////////////////////////





