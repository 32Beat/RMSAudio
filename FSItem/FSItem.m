////////////////////////////////////////////////////////////////////////////////
/*
	RMSLowPassFilter
	
	Created by 32BT on 15/11/15.
	Copyright © 2015 32BT. All rights reserved.
*/
////////////////////////////////////////////////////////////////////////////////


#import "FSItem.h"


////////////////////////////////////////////////////////////////////////////////

@interface FSItem ()
{
	BOOL mInfo;
	BOOL mContainer;
	NSString *mName;
	NSMutableArray *mContainerItems;
}

@end

////////////////////////////////////////////////////////////////////////////////
@implementation FSItem
////////////////////////////////////////////////////////////////////////////////

+ (instancetype) itemWithURL:(NSURL *)url
{ return [[self alloc] initWithURL:url]; }

- (instancetype) initWithURL:(NSURL *)url
{
	self = [super init];
	self.url = url;
	return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void) loadInfo
{
	NSError *errorPtr = nil;

	NSDictionary *values =
		[self.url resourceValuesForKeys:@[
			NSURLLocalizedNameKey,
			NSURLIsRegularFileKey,
			NSURLIsDirectoryKey,
			NSURLIsHiddenKey] error:&errorPtr];
		
	mContainer = [[values valueForKey:NSURLIsDirectoryKey] boolValue];
	mName = [values valueForKey:NSURLLocalizedNameKey];
	
	mInfo = YES;
}

////////////////////////////////////////////////////////////////////////////////

- (BOOL) isContainer
{
	if (mInfo == NO)
	{ [self loadInfo]; }
	
	return mContainer;
}

////////////////////////////////////////////////////////////////////////////////

- (NSString *) localizedName
{
	if (mInfo == NO)
	{ [self loadInfo]; }
	
	return mName;
}

////////////////////////////////////////////////////////////////////////////////

- (NSArray *) containerItems
{
	if (mContainerItems == nil)
	{
		NSError *errorPtr = nil;
		
		NSArray *urlArray =
			[[NSFileManager defaultManager]
				contentsOfDirectoryAtURL:self.url
				includingPropertiesForKeys:nil
				options:NSDirectoryEnumerationSkipsHiddenFiles
				error:&errorPtr];
		
		for (NSURL *url in urlArray)
		{
			FSItem *item = [[self class] itemWithURL:url];
			if ([self shouldAddItem:item])
			{
				[self addItem:item];
			}
		}
	}
	
	return mContainerItems;
}

////////////////////////////////////////////////////////////////////////////////

- (BOOL) shouldAddItem:(FSItem *)item
{
	return YES;
}

////////////////////////////////////////////////////////////////////////////////

- (void) addItem:(FSItem *)item
{
	if (mContainerItems == nil)
	{ mContainerItems = [NSMutableArray new]; }
	[mContainerItems addObject:item];
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////





