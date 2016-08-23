////////////////////////////////////////////////////////////////////////////////
/*
	RMSInterpolator
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#ifndef RMSInterpolator_h
#define RMSInterpolator_h

////////////////////////////////////////////////////////////////////////////////

enum RMSInterpolatorType
{
	kRMSInterpolatorTypeJittered = -1,
	kRMSInterpolatorTypeNearest = 0,
	kRMSInterpolatorTypeLinear,
	kRMSInterpolatorTypeSpline
};


typedef struct rmsinterpolator_t
{
	// equally spaced samples, interpolation occurs from P1 to P2
	double P0;
	double P1;
	double P2;
	double P3;

	double A; 	// parameter value
	double e; 	// error for jittered fetch
	double C1; 	// control points for spline fetch
	double C2;
}
rmsinterpolator_t;

////////////////////////////////////////////////////////////////////////////////

static inline rmsinterpolator_t RMSInterpolatorInit(void)
{ return (rmsinterpolator_t){ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 }; }


void RMSInterpolatorUpdate(rmsinterpolator_t *ptr, double S);
void RMSInterpolatorUpdateWithParameter(rmsinterpolator_t *ptr, double S, double P);

double RMSInterpolatorFetch(rmsinterpolator_t *ptr, double t);
double RMSInterpolatorFetchNearest(rmsinterpolator_t *ptr, double t);
double RMSInterpolatorFetchJittered(rmsinterpolator_t *ptr, double t);
double RMSInterpolatorFetchLinear(rmsinterpolator_t *ptr, double t);
double RMSInterpolatorFetchSpline(rmsinterpolator_t *ptr, double t);

////////////////////////////////////////////////////////////////////////////////

#endif



