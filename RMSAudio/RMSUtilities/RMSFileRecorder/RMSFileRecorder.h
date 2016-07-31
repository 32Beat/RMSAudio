////////////////////////////////////////////////////////////////////////////////
/*
	RMSFileRecorder
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import "RMSSampleMonitor.h"

@interface RMSFileRecorder : NSObject

@property (nonatomic, readonly) NSURL *url;

+ (instancetype) instanceWithURL:(NSURL *)url;
+ (instancetype) instanceWithURL:(NSURL *)url fileType:(AudioFileTypeID)typeID;

- (OSStatus) updateWithMonitor:(RMSSampleMonitor *)sampleMonitor;

@end
