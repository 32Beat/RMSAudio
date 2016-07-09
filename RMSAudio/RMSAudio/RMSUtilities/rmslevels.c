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

static inline double rms_add(double A, double M, double S) \
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
	
	levels->mAvgM = 1.0 / (1.0 + decayRate);
	levels->mMaxM = decayRate / (decayRate + 1.0);
}

////////////////////////////////////////////////////////////////////////////////

rmslevels_t RMSLevelsInit(double sampleRate)
{
	rmslevels_t levels = { 0.0, 0.0, 0.0, 0.0 };
	
	RMSLevelsSetResponse(&levels, 300, sampleRate);
	
	return levels;
}

////////////////////////////////////////////////////////////////////////////////

inline void RMSLevelsUpdateWithSample(rmslevels_t *levels, double sample)
{
	// Compute absolute value
	sample = fabs(sample);
	
	// Update maximum
	if (levels->mMax < sample)
		levels->mMax = sample;
	else
		levels->mMax *= levels->mMaxM;


	// the s in rms
	sample *= sample;
	
	// Update short term rms average
	levels->mAvg = rms_add(levels->mAvg, levels->mAvgM, sample);
}

////////////////////////////////////////////////////////////////////////////////

void RMSLevelsUpdateWithSamples32(rmslevels_t *levels, float *srcPtr, uint32_t n)
{
	for (; n!=0; n--)
	RMSLevelsUpdateWithSample(levels, *srcPtr++);
}

////////////////////////////////////////////////////////////////////////////////

rmslevels_t RMSLevelsFetchResult(const rmslevels_t *levelsPtr)
{
	rmslevels_t levels = { 0.0, 0.0, 0.0, 0.0 };
	
	if (levelsPtr != NULL)
	{
		levels.mAvg = sqrt(levelsPtr->mAvg);
		levels.mMax = levelsPtr->mMax;
	}
	
	return levels;
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





