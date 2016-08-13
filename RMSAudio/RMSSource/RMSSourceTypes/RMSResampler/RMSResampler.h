////////////////////////////////////////////////////////////////////////////////
/*
	RMSResampler
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSCache.h"

////////////////////////////////////////////////////////////////////////////////
// TODO: this is currently a resampler/converter not a varispeed
// TODO: probably requires renaming

@interface RMSResampler : RMSCache
{
}

@property (nonatomic, assign) float parameter;
@property (nonatomic, assign) BOOL shouldFilter;
@property (nonatomic, assign) int filterOrder;

@end

////////////////////////////////////////////////////////////////////////////////


