////////////////////////////////////////////////////////////////////////////////
/*
	rmsavg
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#ifndef rmsavg_t_h
#define rmsavg_t_h

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

////////////////////////////////////////////////////////////////////////////////
/*
	rmsavg = running average
	(for discrete average see rmssum)
	
	usage indication:
*/
////////////////////////////////////////////////////////////////////////////////

typedef struct rmsavg_t
{
	double A;
	double M;
}
rmsavg_t;

////////////////////////////////////////////////////////////////////////////////

rmsavg_t RMSAverageInitWithSize(double size);
rmsavg_t RMSAverageInitWithMultiplier(double M);
rmsavg_t RMSAverageInitWithRateChange(double srcRate, double dstRate);

float RMSAverageUpdate(rmsavg_t *avgPtr, float S);
void RMSAverageRun(rmsavg_t *avgPtr, float *ptr, uint32_t N);
void RMSAverageRun121(rmsavg_t *avgPtr, float *ptr, uint32_t N);

////////////////////////////////////////////////////////////////////////////////
#endif // rmsavg_t_h
////////////////////////////////////////////////////////////////////////////////






