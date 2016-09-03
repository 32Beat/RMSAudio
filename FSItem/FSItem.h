////////////////////////////////////////////////////////////////////////////////
/*
	FSItem
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////

@interface FSItem : NSObject
{
}

@property (nonatomic, copy) NSURL *url;

//+ (instancetype) instanceWithURL:(NSURL *)url;
+ (instancetype) itemWithURL:(NSURL *)url;
- (instancetype) initWithURL:(NSURL *)url;

- (BOOL) isContainer;
- (NSString *) localizedName;
- (NSArray *) containerItems;

- (BOOL) shouldAddItem:(FSItem *)item;
- (void) addItem:(FSItem *)item;

@end

////////////////////////////////////////////////////////////////////////////////





