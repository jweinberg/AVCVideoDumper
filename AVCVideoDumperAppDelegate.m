//
//  AVCVideoDumperAppDelegate.m
//  AVCVideoDumper
//
//  Created by Joshua Weinberg on 8/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "AVCVideoDumperAppDelegate.h"
#import "AVCVideoCapController.h"

@implementation AVCVideoDumperAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
	AVCVideoCapController* controller = [[AVCVideoCapController alloc] init];
	[controller streamToPort];
	//	[controller startCapture];
	//	[self performSelector:@selector(kill:) withObject:nil afterDelay:5];
}

- (void) kill:(id) obj
{
	exit(0);
	
}
@end
