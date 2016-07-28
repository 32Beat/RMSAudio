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
	
	// initialize levels struct with samplerate
	rmslevels_t levels = RMSLevelsInit(44100);
	
	// on audio thread, for each sample call:
	RMSLevelsUpdateWithSample(&levels, sample);
	
	// on main thread, periodically call:
	rmsresult_t levels = RMSLevelsFetchResult(&levels);
	
	
*/
////////////////////////////////////////////////////////////////////////////////

// Structure for intermediate sample processing
typedef struct rmslevels_t
{
	float avg; // rms average response
	float max; // maximum since last fetch

	// multipliers based on samplerate
	float avgM;
}
rmslevels_t;

// Structure for communicating result
typedef struct rmsresult_t
{
	float avg;
	float max;
}
rmsresult_t;

////////////////////////////////////////////////////////////////////////////////

// Prepare engine struct using samplerate
rmslevels_t RMSLevelsInit(double sampleRate);

// Update engine with squared samples
void RMSLevelsScanSample(rmslevels_t *levels, float sample);

// Convenience routine for processing packed floats
void RMSLevelsScanSamples(rmslevels_t *levels, const float *srcPtr, size_t n);

// Get sqrt results. Save to call with levelsPtr == nil
rmsresult_t RMSLevelsFetchResult(rmslevels_t *levels);

////////////////////////////////////////////////////////////////////////////////
#endif // rmslevels_h
////////////////////////////////////////////////////////////////////////////////






