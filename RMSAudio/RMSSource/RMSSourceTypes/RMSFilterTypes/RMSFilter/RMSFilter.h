////////////////////////////////////////////////////////////////////////////////
/*
	RMSFilter
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSSource.h"

////////////////////////////////////////////////////////////////////////////////

@interface RMSFilter : RMSSource
{
}

@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) float cutOff;
@property (nonatomic, assign) float resonance;

+ (instancetype) instanceWithSource:(RMSSource *)source;
- (instancetype) initWithSource:(RMSSource *)source;

@end

////////////////////////////////////////////////////////////////////////////////





