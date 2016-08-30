////////////////////////////////////////////////////////////////////////////////
/*
	rmsfilter
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#ifndef rmsfilter_t_h
#define rmsfilter_t_h

#include <stddef.h>
#include <stdint.h>

////////////////////////////////////////////////////////////////////////////////
/*
	usage indication:
*/
////////////////////////////////////////////////////////////////////////////////
/*	
	V = value
	M = multiplier,

	E = error
	R = resonance,
	(Q is technically more like resonance decay time, 
	which is not controlled by this parameter)
	
	
	// error = current sample - previous filter value
	E = S - F->V
	
	// update proportional error
	E *= F->M; // = normal filter response y[n] = ax[n] + by[n-1], b = 1-a, a = M

	// update running average error
	F->E += (E - F->E) * F->M // = resonant response
	
	// adjust between Ep & Ei
	E += (F->E - E) * F->R;
	
	// update filter value
	F->V += E;
	
	return F->V
*/

typedef struct rmsfilter_t
{
	double V;
	double M;
	double E;
	double R;
}
rmsfilter_t;

////////////////////////////////////////////////////////////////////////////////

rmsfilter_t RMSFilterInitWithMultiplier(double M);
rmsfilter_t RMSFilterInitWithRateChange(double srcRate, double dstRate);
rmsfilter_t RMSFilterInitWithCutoff(double Fc, double Fs);

void RMSFilterRun(rmsfilter_t *filterInfo, float *ptr, uint32_t N);
void RMSFilterRunWithAdjustment(rmsfilter_t *F, double M, double R, float *ptr, uint32_t N);

double RMSOscillatorNext(rmsfilter_t *F);

////////////////////////////////////////////////////////////////////////////////
#endif // rmslevels_h
////////////////////////////////////////////////////////////////////////////////






