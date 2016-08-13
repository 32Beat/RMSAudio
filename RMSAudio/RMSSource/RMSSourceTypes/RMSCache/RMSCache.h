////////////////////////////////////////////////////////////////////////////////
/*
	RMSCache
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSSource.h"
#import "RMSUtilities.h"

@interface RMSCache : RMSSource
{
	UInt32 mCacheSize;
	RMSStereoBufferList mCacheBuffer;
}

+ (instancetype)instanceWithSource:(RMSSource *)source;
+ (instancetype)instanceWithSource:(RMSSource *)source length:(UInt32)length;
- (instancetype)initWithSource:(RMSSource *)source length:(UInt32)length;

BOOL RMSCacheShouldRefreshBuffer(void *objectPtr, UInt64 index);
OSStatus RMSCacheRefreshBuffer(void *objectPtr, UInt64 index);
OSStatus RMSCacheFetchNext(void *cachePtr, float *dstPtr);
OSStatus RMSCacheFetch(void *cachePtr, UInt64 index, float *dstPtr);

@end
