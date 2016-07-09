////////////////////////////////////////////////////////////////////////////////
/*
	rmslevels.h
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#ifndef rmslevels_t_h
#define rmslevels_t_h

#include <stddef.h>
#include <stdint.h>

////////////////////////////////////////////////////////////////////////////////
/*
	usage indication:
	
	// initialize engine struct with samplerate
	rmsengine_t engine = RMSEngineInit(44100);
	
	// on audio thread, for each sample call:
	RMSEngineAddSample(&engine, sample);
	
	// on main thread, periodically call:
	rmsresult_t levels = RMSEngineFetchResult(&engine);
	
	
*/
////////////////////////////////////////////////////////////////////////////////

// Structure for intermediate sample processing
typedef struct rmslevels_t
{
	double mAvg;
	double mMax;

	// multipliers based on samplerate
	double mAvgM;
	double mMaxM;
}
rmslevels_t;

////////////////////////////////////////////////////////////////////////////////

// Prepare engine struct using samplerate
rmslevels_t RMSLevelsInit(double sampleRate);

// Update engine with squared samples
void RMSLevelsUpdateWithSample(rmslevels_t *levels, double sample);

// Convenience routine for processing packed floats
void RMSLevelsUpdateWithSamples32(rmslevels_t *levels, float *srcPtr, uint32_t n);

// Get sqrt results. Save to call with levelsPtr == nil
rmslevels_t RMSLevelsFetchResult(const rmslevels_t *levelsPtr);

////////////////////////////////////////////////////////////////////////////////
#endif // rmslevels_h
////////////////////////////////////////////////////////////////////////////////






