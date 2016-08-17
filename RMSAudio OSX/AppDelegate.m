//
//  AppDelegate.m
//  RMSAudio
//
//  Created by 32BT on 23/06/16.
//  Copyright © 2016 32BT. All rights reserved.
//

#import "AppDelegate.h"

#if defined __i386__ || defined __x86_64__

	#define HasVector	1

	#include <fenv.h>
	#if !defined __GNUC__
		/*	This statement should be used when the compiler
			supports it.
		*/
		#pragma STDC FENV_ACCESS ON
	#endif

	typedef fenv_t MathEnvironment;

	// Define FastMathEnvironment to use one provided by Apple via fenv.h.
	#define	FastMathEnvironment	(*FE_DFL_DISABLE_SSE_DENORMS_ENV)

	MathEnvironment SetMathEnvironment(MathEnvironment New)
	{
		MathEnvironment Old;
	
		// Get the old environment.
		if (0 != fegetenv(&Old))
		{
			fprintf(stderr, "Error, fegetenv returned non-zero.\n");
			exit(EXIT_FAILURE);
		}
	
		// Set the new environment.
		if (0 != fesetenv(&New))
		{
			fprintf(stderr, "Error, fesetenv returned non-zero.\n");
			exit(EXIT_FAILURE);
		}

		return Old;
	}

#endif


@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

	// Insert code here to initialize your application
	SetMathEnvironment(FastMathEnvironment);
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

@end
