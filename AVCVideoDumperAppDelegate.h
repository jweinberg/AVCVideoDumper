//
//  AVCVideoDumperAppDelegate.h
//  AVCVideoDumper
//
//  Created by Joshua Weinberg on 8/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AVCVideoDumperAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
