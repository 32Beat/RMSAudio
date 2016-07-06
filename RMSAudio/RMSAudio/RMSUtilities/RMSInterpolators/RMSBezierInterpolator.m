////////////////////////////////////////////////////////////////////////////////
/*
	RMSBezierInterpolator
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "RMSBezierInterpolator.h"


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

void RMSCatmullRomUpdate(rmscatmullrom_t *ptr, double S)
{
	ptr->P0 = ptr->P1;
	ptr->P1 = ptr->P2;
	ptr->P2 = ptr->P3;
	ptr->P3 = S;

	ptr->C1 = ptr->P1 - (ptr->C2 - ptr->P1);
	ptr->C2 = ptr->P2 - (ptr->P3 - ptr->P1)*(5.0/24.0);
	//(5.0/12.0) = good approximation of sinc2
}

////////////////////////////////////////////////////////////////////////////////

double RMSCatmullRomFetch(rmscatmullrom_t *ptr, double t)
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

