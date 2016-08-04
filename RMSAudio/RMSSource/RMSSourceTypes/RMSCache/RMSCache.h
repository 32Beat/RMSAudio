////////////////////////////////////////////////////////////////////////////////
/*
	RMSCache
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSSource.h"

@interface RMSCache : RMSSource

+ (instancetype)instanceWithSource:(RMSSource *)source;
+ (instancetype)instanceWithSource:(RMSSource *)source length:(UInt32)length;
- (instancetype)initWithSource:(RMSSource *)source length:(UInt32)length;

OSStatus RMSCacheFetch(void *cachePtr, UInt64 index, float *dstPtr);

@end
