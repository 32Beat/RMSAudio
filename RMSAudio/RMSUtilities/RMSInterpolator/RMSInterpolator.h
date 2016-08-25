////////////////////////////////////////////////////////////////////////////////
/*
	RMSInterpolator
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#ifndef RMSInterpolator_h
#define RMSInterpolator_h

#include <stddef.h>

////////////////////////////////////////////////////////////////////////////////

typedef struct rmsdecimator_t
{
	double A0;
	double A1;
	double M;
}
rmsdecimator_t;

rmsdecimator_t RMSDecimatorInitWithSize(double size);
void RMSDecimatorUpdate(rmsdecimator_t *decimator, double S);
double RMSDecimatorFetch(rmsdecimator_t *decimator, double t);

////////////////////////////////////////////////////////////////////////////////

enum RMSInterpolatorType
{
	kRMSInterpolatorTypeJittered = -1,
	kRMSInterpolatorTypeNearest = 0,
	kRMSInterpolatorTypeLinear,
	kRMSInterpolatorTypeSpline
};

typedef struct rmsinterpolator_t rmsinterpolator_t;

struct rmsinterpolator_t
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

	void (*write)(rmsinterpolator_t *info, double S);
	double (*fetch)(rmsinterpolator_t *info, double t);
};

////////////////////////////////////////////////////////////////////////////////

rmsinterpolator_t RMSJitteredInterpolator(void);
rmsinterpolator_t RMSNearestInterpolator(void);
rmsinterpolator_t RMSLinearInterpolator(void);
rmsinterpolator_t RMSSplineInterpolator(void);

void RMSInterpolatorUpdate(rmsinterpolator_t *ptr, double S);
void RMSInterpolatorUpdateWithParameter(rmsinterpolator_t *ptr, double S, double P);

double RMSInterpolatorFetch(rmsinterpolator_t *ptr, double t);

////////////////////////////////////////////////////////////////////////////////

#endif



