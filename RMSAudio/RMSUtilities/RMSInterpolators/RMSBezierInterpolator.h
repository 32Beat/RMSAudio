////////////////////////////////////////////////////////////////////////////////
/*
	RMSBezierInterpolator
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#ifndef RMSInterpolator_h
#define RMSInterpolator_h

////////////////////////////////////////////////////////////////////////////////

typedef struct rmscrb_t
{
	double P0;
	double P1;
	double P2;
	double P3;

	double C1;
	double C2;

	double e;
}
rmscrb_t;

void RMSResamplerWrite(rmscrb_t *ptr, double S);
double RMSResamplerFetch(rmscrb_t *ptr, double t);

void RMSResamplerWriteWithParameter(rmscrb_t *ptr, double S, double P);
double RMSResamplerNearestFetch(rmscrb_t *ptr, double t);
double RMSResamplerJitteredFetch(rmscrb_t *ptr, double t);
double RMSResamplerLinearFetch(rmscrb_t *ptr, double t);

////////////////////////////////////////////////////////////////////////////////

#endif



