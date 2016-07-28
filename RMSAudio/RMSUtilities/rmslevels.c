////////////////////////////////////////////////////////////////////////////////
/*
	rmslevels.h
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#include "rmslevels.h"
#include <math.h>

////////////////////////////////////////////////////////////////////////////////

#define rms_add(A, M, S) (A+M*(S-A))

//static inline double rms_add(double A, double M, double S) \
{ return A + M * (S - A); }

//static inline double rms_max(double A, double M, double S) \
{ return A > S ? rms_add(A, M, S) : S; }

//static inline double rms_min(double A, double M, double S) \
{ return A < S ? rms_add(A, M, S) : S; }

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

void RMSLevelsSetResponse(rmslevels_t *levels, double milliSeconds, double sampleRate)
{
	double decayRate = 0.001 * milliSeconds * sampleRate;
	
	levels->avgM = 1.0 / (1.0 + decayRate);
}

////////////////////////////////////////////////////////////////////////////////

rmslevels_t RMSLevelsInit(double sampleRate)
{
	rmslevels_t levels = { 0.0, 0.0, 0.0 };
	
	RMSLevelsSetResponse(&levels, 300, sampleRate);
	
	return levels;
}

////////////////////////////////////////////////////////////////////////////////

inline void RMSLevelsScanSample(rmslevels_t *levels, float sample)
{
	if (sample < 0.0)
	{ sample = -sample; }
	
	// update max value
	if (levels->max < sample)
	{ levels->max = sample; }

	// the s in rms
	sample *= sample;
	
	// Update short term average
	levels->avg = rms_add(levels->avg, levels->avgM, sample);
}

////////////////////////////////////////////////////////////////////////////////

void RMSLevelsScanSamples(rmslevels_t *levels, const float *srcPtr, size_t N)
{
	for(size_t n=0; n!=N; n++)
	{ RMSLevelsScanSample(levels, srcPtr[n]); }
}

////////////////////////////////////////////////////////////////////////////////

rmsresult_t RMSLevelsFetchResult(rmslevels_t *levelsPtr)
{
	rmsresult_t result = { 0.0, 0.0 };
	
	if (levelsPtr != NULL)
	{
		result.avg = sqrt(levelsPtr->avg);
		result.max = (levelsPtr->max);
		levelsPtr->max = 0.0;
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////
// 20.0*log10(sqrt()) == 10.0*log10()
/*
rmsresult_t RMSEngineFetchResultDB(rmsengine_t *enginePtr)
{
	rmsresult_t levels = RMSEngineFetchResult(enginePtr);
	
	levels.mBal = 10.0*log10(levels.mBal);
	levels.mAvg = 10.0*log10(levels.mAvg);
	levels.mMax = 20.0*log10(levels.mMax);
	levels.mHld = 20.0*log10(levels.mHld);

	return levels;
}
*/
////////////////////////////////////////////////////////////////////////////////





