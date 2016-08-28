////////////////////////////////////////////////////////////////////////////////
/*
	RMSInterpolator
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSInterpolator.h"
#import <math.h>


////////////////////////////////////////////////////////////////////////////////
/*
*/
rmsdecimator_t RMSDecimatorInit(void)
{ return (rmsdecimator_t){ .A0 = 0.0, .A1 = 0.0 }; }

double RMSDecimatorUpdate_(float *ptr, size_t N)
{
	return ((N>>=1) == 0)?
	0.5 * (ptr[0] + ptr[1]):
	0.5 *
	RMSDecimatorUpdate_(&ptr[0], N)+
	RMSDecimatorUpdate_(&ptr[N], N);
}


double RMSDecimatorUpdate2(double *decimator, float *ptr)
{
	double S0 = decimator[0];
	double S1 = ptr[0];
	double S2 = ptr[1];
	decimator[0] = S2;
	
	return 0.25*(S0+S1+S1+S2);
}

double RMSDecimatorUpdate4(double *decimator, float *ptr)
{
	double A0 = decimator[0];
	double A1 = RMSDecimatorUpdate2(&decimator[1], &ptr[0]);
	double A2 = RMSDecimatorUpdate2(&decimator[1], &ptr[2]);
	decimator[0] = A2;

	return 0.25*(A0+A1+A1+A2);
}

double RMSDecimatorUpdate8(double *decimator, float *ptr)
{
	double A0 = decimator[0];
	double A1 = RMSDecimatorUpdate4(&decimator[1], &ptr[0]);
	double A2 = RMSDecimatorUpdate4(&decimator[1], &ptr[4]);
	decimator[0] = A2;

	return 0.25*(A0+A1+A1+A2);
}



/*
void RMSDecimatorUpdateSum(rmsdecimator_t *decimator, float S)
{
	decimator->S0 += decimator->S1;
	decimator->S1 = S;
}

double RMSDecimatorFetchAvg(rmsdecimator_t *decimator, double t)
{
	double S = t * decimator->S1;
	decimator->S0 += S;
	decimator->S1 -= S;

	double D = decimator->S0;
	decimator->S0 = 0.0;

	return decimator->M * D;
}
*/
////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

void RMSInterpolatorWriteJittered(rmsinterpolator_t *info, double S);
void RMSInterpolatorWriteNearest(rmsinterpolator_t *info, double S);
void RMSInterpolatorWriteLinear(rmsinterpolator_t *info, double S);
void RMSInterpolatorWriteSpline(rmsinterpolator_t *info, double S);
void RMSInterpolatorWritePolynomial(rmsinterpolator_t *info, double S);

double RMSInterpolatorFetchNearest(rmsinterpolator_t *ptr, double t);
double RMSInterpolatorFetchJittered(rmsinterpolator_t *ptr, double t);
double RMSInterpolatorFetchLinear(rmsinterpolator_t *ptr, double t);
double RMSInterpolatorFetchSpline(rmsinterpolator_t *ptr, double t);
double RMSInterpolatorFetchPolynomial(rmsinterpolator_t *ptr, double t);

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

rmsinterpolator_t RMSInterpolatorInitWithProcs(void *write, void *fetch)
{
	return (rmsinterpolator_t)
	{
		0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0,
		.write = write,
		.fetch = fetch,
	};
}

////////////////////////////////////////////////////////////////////////////////

rmsinterpolator_t RMSJitteredInterpolator(void)
{
	return RMSInterpolatorInitWithProcs(
	RMSInterpolatorWriteJittered,
	RMSInterpolatorFetchJittered);
}

////////////////////////////////////////////////////////////////////////////////

rmsinterpolator_t RMSNearestInterpolator(void)
{
	return RMSInterpolatorInitWithProcs(
	RMSInterpolatorWriteNearest,
	RMSInterpolatorFetchNearest);
}

////////////////////////////////////////////////////////////////////////////////

rmsinterpolator_t RMSLinearInterpolator(void)
{
	return RMSInterpolatorInitWithProcs(
	RMSInterpolatorWriteLinear,
	RMSInterpolatorFetchLinear);
}

////////////////////////////////////////////////////////////////////////////////

rmsinterpolator_t RMSSplineInterpolator(void)
{
	return RMSInterpolatorInitWithProcs(
	RMSInterpolatorWriteSpline,
	RMSInterpolatorFetchSpline);
}

////////////////////////////////////////////////////////////////////////////////

rmsinterpolator_t RMSPolynomialInterpolator(void)
{
	return RMSInterpolatorInitWithProcs(
	RMSInterpolatorWritePolynomial,
	RMSInterpolatorFetchPolynomial);
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

void RMSInterpolatorUpdate(rmsinterpolator_t *info, double S)
{ info->write(info, S); }

double RMSInterpolatorFetch(rmsinterpolator_t *info, double t)
{ return info->fetch(info, t); }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

void RMSInterpolatorWriteJittered(rmsinterpolator_t *info, double S)
{
	info->P1 = info->P2;
	info->P2 = S;
}

////////////////////////////////////////////////////////////////////////////////

double RMSInterpolatorFetchJittered(rmsinterpolator_t *ptr, double t)
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
#pragma mark
////////////////////////////////////////////////////////////////////////////////

void RMSInterpolatorWriteNearest(rmsinterpolator_t *info, double S)
{
	info->P1 = info->P2;
	info->P2 = S;
}

////////////////////////////////////////////////////////////////////////////////

double RMSInterpolatorFetchNearest(rmsinterpolator_t *ptr, double t)
{ return t < 0.5 ? ptr->P1 : ptr->P2; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

void RMSInterpolatorWriteLinear(rmsinterpolator_t *info, double S)
{
	info->P1 = info->P2;
	info->P2 = S;
}

////////////////////////////////////////////////////////////////////////////////

double RMSInterpolatorFetchLinear(rmsinterpolator_t *info, double t)
{ return info->P1 + t * (info->P2 - info->P1); }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
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
	RMSInterpolatorWrite
	--------------------
	Add source-sample to resampler
	
	The resampler keeps track of the samples near the current source index.
	These samples are used to compute the interpolated value. Each time the 
	source index is updated, the resampler needs to be updated accordingly.
	
	Currently S needs to be 2 samples ahead of the source index.
*/
void RMSInterpolatorWriteSpline(rmsinterpolator_t *ptr, double S)
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

double RMSInterpolatorFetchSpline(rmsinterpolator_t *ptr, double t)
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

void RMSInterpolatorWritePolynomial(rmsinterpolator_t *ptr, double S)
{
	RMSInterpolatorWriteSpline(ptr, S);
	
	double d = ptr->P1;
	double c = 3*(ptr->C1-ptr->P1);
	double b = 3*(ptr->C2-ptr->C1) - c;
	double a = (ptr->P2-ptr->P1) - b - c;
	
	ptr->d = d;
	ptr->c = c;
	ptr->b = b;
	ptr->a = a;
}

////////////////////////////////////////////////////////////////////////////////

double RMSInterpolatorFetchPolynomial(rmsinterpolator_t *ptr, double t)
{
	double a = ptr->a;
	double b = ptr->b;
	double c = ptr->c;
	double d = ptr->d;
	
	return ((a*t+b)*t+c)*t+d;
}

////////////////////////////////////////////////////////////////////////////////

void RMSInterpolatorUpdateWithParameter(rmsinterpolator_t *ptr, double S, double P)
{
	ptr->P0 = ptr->P1;
	ptr->P1 = ptr->P2;
	ptr->P2 = ptr->P3;
	ptr->P3 = S;
	
	ptr->C1 = ptr->P1 - (ptr->C2 - ptr->P1);
	ptr->C2 = ptr->P2 - (ptr->P3 - ptr->P1)*(P);
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

