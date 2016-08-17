////////////////////////////////////////////////////////////////////////////////
/*
	RMSBezierInterpolator
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSBezierInterpolator.h"
#import <math.h>

////////////////////////////////////////////////////////////////////////////////
/*
	Given equally spaced samples P0, P1, P2, P3, 
	Compute interpolated sample between P1 and P2
	
		Compute tangent for P1: T1 = (P2 - P0)/2
		Compute tangent for P2: T2 = (P3 - P1)/2
		
		Compute bezier control point for P1: C1 = P1 + T1/3
		Compute bezier control point for P2: C2 = P2 - T2/3
	
	Fetch value between P1 and P2 with fraction t = [0.0, 1.0] 
	by computing deCasteljau with P1, C1, C2, P2
	
	For update cycle: 
	1. P0 = P1; // not strictly necessary
	2. P1 = P2;
	3. P2 = P3;
	4. P3 = S;
	
	5. C1 = P1 - (C2 - P1);
	6. C2 = P2 - (P3 - P1)*(1.0/6.0);
*/
////////////////////////////////////////////////////////////////////////////////
/*
	RMSResamplerWrite
	-----------------
	Add source-sample to resampler
	
	The resampler keeps track of the samples near the current source index.
	These samples are used to compute the interpolated value. Each time the 
	source index is updated, the resampler needs to be updated accordingly.
	
	Currently S needs to be 2 samples ahead of the source index.
*/
void RMSResamplerWrite(rmscrb_t *ptr, double S)
{
	ptr->P0 = ptr->P1;
	ptr->P1 = ptr->P2;
	ptr->P2 = ptr->P3;
	ptr->P3 = S;
	
	ptr->C1 = ptr->P1 - (ptr->C2 - ptr->P1);
	ptr->C2 = ptr->P2 - (ptr->P3 - ptr->P1)*(0.5*0.71592);
	/*
		0.33333 = true catmull-rom
		0.35468 = approximation of Lanczos2 normalized response
		0.37864 = approximation of Lanczos2 impulse response
		0.39822 = approximation of Lanczos2 edge response
		0.71592 = approximation of sinc center lobe
		
		oddly enough, the latter seems to give best audible result
	*/
}

////////////////////////////////////////////////////////////////////////////////

void RMSResamplerWriteWithParameter(rmscrb_t *ptr, double S, double P)
{
	ptr->P0 = ptr->P1;
	ptr->P1 = ptr->P2;
	ptr->P2 = ptr->P3;
	ptr->P3 = S;
	
	ptr->C1 = ptr->P1 - (ptr->C2 - ptr->P1);

	double D1 = ptr->P2 - ptr->P1;
	double D2 = ptr->P3 - ptr->P2;
	double D = 0.5 * (D1+D2);
		
	ptr->C2 = ptr->P2 - P*D;
}

////////////////////////////////////////////////////////////////////////////////

double RMSResamplerFetch(rmscrb_t *ptr, double t)
{
//	return RMSResamplerNearestFetch(ptr, t);
//	return RMSResamplerJitteredFetch(ptr, t);
//	return RMSResamplerLinearFetch(ptr, t);
	return RMSResamplerSplineFetch(ptr, t);
}

////////////////////////////////////////////////////////////////////////////////

double RMSResamplerNearestFetch(rmscrb_t *ptr, double t)
{ return t < 0.5 ? ptr->P1 : ptr->P2; }

////////////////////////////////////////////////////////////////////////////////

double RMSResamplerJitteredFetch(rmscrb_t *ptr, double t)
{
	// compensate previous offset
	if ((t+ptr->e) < 0.5)
	{
		ptr->e = +t;
		return ptr->P1;
		
	}
	else
	{
		ptr->e = -(1.0-t);
		return ptr->P2;
	}
}

////////////////////////////////////////////////////////////////////////////////

double RMSResamplerLinearFetch(rmscrb_t *ptr, double t)
{
	return ptr->P1 + t * (ptr->P2 - ptr->P1);
}

////////////////////////////////////////////////////////////////////////////////

double RMSResamplerSplineFetch(rmscrb_t *ptr, double t)
{
	double P1 = ptr->P1;
	double C1 = ptr->C1;
	double C2 = ptr->C2;
	double P2 = ptr->P2;
	
	P1 += t * (C1-P1);
	C1 += t * (C2-C1);
	C2 += t * (P2-C2);

	P1 += t * (C1-P1);
	C1 += t * (C2-C1);

	P1 += t * (C1-P1);

	return P1;
}

////////////////////////////////////////////////////////////////////////////////
/*
	sinc
	----
	for N == 0 returns unwindowed sinc,
	for N != 0 returns corresponding Lanczos windowed sinc
*/
/*
static double sinc(double x, double N)
{
	if (x == 0.0) return 1.0;
	
	double s = sin(x*M_PI)/(x*M_PI);
	
	if (N != 0.0)
	{ s *= sin(x*M_PI/N)/(x*M_PI/N); }
	
	return s;
}

////////////////////////////////////////////////////////////////////////////////

typedef struct rmslanczos_t
{
	double P0;
	double P1;
	double P2;
	double P3;
}
rmslanczos_t;

void RMSLanczosUpdate(rmslanczos_t *ptr, double S);
double RMSLanczosSample(rmslanczos_t *ptr, double t);

////////////////////////////////////////////////////////////////////////////////

void RMSLanczosUpdate(rmslanczos_t *ptr, double S)
{
	ptr->P0 = ptr->P1;
	ptr->P1 = ptr->P2;
	ptr->P2 = ptr->P3;
	ptr->P3 = S;
}

////////////////////////////////////////////////////////////////////////////////

double RMSLanczosSample(rmslanczos_t *ptr, double t)
{
	double P0 = ptr->P0;
	double P1 = ptr->P1;
	double P2 = ptr->P2;
	double P3 = ptr->P3;

	double W0 = sinc(-1.0-t, 2.0);
	double W1 = sinc(+0.0-t, 2.0);
	double W2 = sinc(+1.0-t, 2.0);
	double W3 = sinc(+2.0-t, 2.0);

	double y =
	W0 * P0 +
	W1 * P1 +
	W2 * P2 +
	W3 * P3;
	
	return y / (W0 + W1 + W2 + W3);
}
*/
////////////////////////////////////////////////////////////////////////////////

