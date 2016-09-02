//
//  Document.h
//  RMSAudio
//
//  Created by 32BT on 23/06/16.
//  Copyright © 2016 32BT. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RMSMusicLibraryVC.h"

@interface Document : NSDocument

@property (nonatomic) IBOutlet NSTextView *logView;
@property (nonatomic, weak) IBOutlet RMSMusicLibraryVC *libraryVC;

@end

