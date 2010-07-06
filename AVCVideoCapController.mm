/*
	File:		AVCVideoCapController.mm
 
 Synopsis: This is the source file for the main application controller object 
 
	Copyright: 	© Copyright 2001-2005 Apple Computer, Inc. All rights reserved.
 
	Written by: ayanowitz
 
 Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
 ("Apple") in consideration of your agreement to the following terms, and your
 use, installation, modification or redistribution of this Apple software
 constitutes acceptance of these terms.  If you do not agree with these terms,
 please do not use, install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject
 to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
 copyrights in this original Apple software (the "Apple Software"), to use,
 reproduce, modify and redistribute the Apple Software, with or without
 modifications, in source and/or binary forms; provided that if you redistribute
 the Apple Software in its entirety and without modifications, you must retain
 this notice and the following text and disclaimers in all such redistributions of
 the Apple Software.  Neither the name, trademarks, service marks or logos of
 Apple Computer, Inc. may be used to endorse or promote products derived from the
 Apple Software without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or implied,
 are granted by Apple herein, including but not limited to any patent rights that
 may be infringed by your derivative works or by other works in which the Apple
 Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
 WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
 WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
 COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
 OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
 (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
*/

#include <AVCVideoServices/AVCVideoServices.h>
using namespace AVS;
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/uio.h>
#include <unistd.h>

#import "AVCVideoCapController.h"

// Defines

#define kNumCyclesInMPEGReceiverSegment 20
#define kNumSegmentsInMPEGReceiverProgram 100
#define kNumSecondsOfNoPacketsToAbortCapture 17
#define kMicroSecondsPerSecond 1000000
#define kCaptureButtonText @"Capture From Device"
#define kStopCaptureText @"Abort Capture Now"

// AVCDeviceController, and AVCDevice callbacks
IOReturn MyAVCDeviceControllerNotification(AVCDeviceController *pAVCDeviceController, void *pRefCon, AVCDevice* pDevice);
IOReturn MyAVCDeviceMessageNotification (class AVCDevice *pAVCDevice,
										 natural_t messageType,
										 void * messageArgument,
										 void *pRefCon);

// MPEG Receiver callbacks
IOReturn MPEGPacketDataStoreHandler(UInt32 tsPacketCount, 
									UInt32 **ppBuf, 
									void *pRefCon, 
									UInt32 isochHeader,
									UInt32 cipHeader0,
									UInt32 cipHeader1,
									UInt32 fireWireTimeStamp);
void MPEGReceiverMessageReceivedProc(UInt32 msg, UInt32 param1, UInt32 param2, void *pRefCon);

// DV Receiver callbacks
IOReturn DVFrameReceivedHandler (DVFrameReceiveMessage msg, DVReceiveFrame* pFrame, void *pRefCon);
void DVReceiverMessageReceivedProc(UInt32 msg, UInt32 param1, UInt32 param2, void *pRefCon);

// States for capture process
enum
{
	kCaptureStateRewind,
	kCaptureStateReceivePackets,
	kCaptureStateTimerArmed
};

// Capture Modes for capture process
enum
{
	kCaptureModeTape,
	kCaptureModeTuner,
};


// AVCVideoServices based global objects
AVCDeviceController *pAVCDeviceController = nil;
AVCDeviceStream* pAVCDeviceStream = nil;
AVCDevice *pCaptureDevice = nil;
TapeSubunitController *tapeController = nil;

// Other globals
FILE *outFile = nil;
bool captureInProgress = false;
UInt32 captureState;
UInt32 captureMode;
UInt32 captureDeviceIndex = 0xFFFFFFFF;
UInt32 packetCount = 0;
UInt32 lastPacketCount = 0;
UInt32 captureStalledCount = 0;
UInt32 currentTimeInSeconds;
UInt32 tunerRecordingStopTimeInSeconds;
UInt32 scheduledTunerRecordingStartTimeInSeconds;

@implementation AVCVideoCapController


//////////////////////////////////////////////////////
// awakeFromNib
//////////////////////////////////////////////////////
- (id)init
{
	if( self = [super init] )
	{
		IOReturn err;
		
		// Create a AVCDeviceController
		err = CreateAVCDeviceController(&pAVCDeviceController,MyAVCDeviceControllerNotification, self);
		if (!pAVCDeviceController)
		{
			// TODO: This should never happen (unless we've run out of memory), but we should handle it cleanly anyway
		}

		[CaptureButton setEnabled:NO];
		[CaptureStatus setStringValue:@"Idle"];
		[PacketCount setStringValue:@"0"];
		[Overruns setStringValue:@"0"];
		[Dropped setStringValue:@"0"];
		[FileName setStringValue:@"No File Selected"];
		[recordingTimeInMinutes setIntValue:30];
		
		[EMI setStringValue:@""];
		
		// Start a repeating timer to handle log & user-interface updates
		userInterfaceUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 // 2 times a sec
																	target:self
																  selector:@selector(userInterfaceUpdateTimerExpired:)
																  userInfo:nil repeats:YES];
	}
return self;
}

//////////////////////////////////////////////////////////////////////
//
// MyStructuredDataPushProc
//
//////////////////////////////////////////////////////////////////////
IOReturn MyStructuredDataPushProc(UInt32 CycleDataCount, MPEGReceiveCycleData *pCycleData, void *pRefCon)
{
	int vectIndex = 0;
	struct iovec iov[kNumCyclesInMPEGReceiverSegment*5];
	int viewerSocket = (int) pRefCon;
	
	if (viewerSocket)
	{
		for (int cycle=0;cycle<CycleDataCount;cycle++)
		{
			for (int sourcePacket=0;sourcePacket<pCycleData[cycle].tsPacketCount;sourcePacket++)
			{
				iov[vectIndex].iov_base = pCycleData[cycle].pBuf[sourcePacket];
				iov[vectIndex].iov_len = kMPEG2TSPacketSize;
				vectIndex += 1;
			}
		}
		
		writev(viewerSocket, iov, vectIndex);
	}
	
	return 0;
}

- (void) streamToPort
{
	IOReturn res;
	NSMutableArray *viewerTaskArgs;
	int pid;
	ProcessSerialNumber psn;
	captureDeviceIndex = 0;
	pCaptureDevice = (AVCDevice*) CFArrayGetValueAtIndex(pAVCDeviceController->avcDeviceArray,captureDeviceIndex);
	
	// Attempt to open the device
	res = pCaptureDevice->openDevice(MyAVCDeviceMessageNotification, self);
	
	if (!pCaptureDevice->isOpened())
	{
		NSLog(@"Bailed");
		//	[self addToAVCLog:[NSString stringWithFormat:@"Cannot use viewer since device is not opened!\n\n"]];	
		return;
	}
	
	//	if ([[ViewerButton title] isEqualTo:kViewerButtonStartText] == YES)
	{
		// Start viewer and MPEG receiver
		
		// Setup the arguments for VLC
		viewerTaskArgs = [NSMutableArray arrayWithCapacity:0];
		
		[viewerTaskArgs addObject:@"--no-fullscreen"];
		
		// These optional arguments enable the deinterlacer by default,
		// and cause VLC to start without the VLC controller window.
		//[viewerTaskArgs addObject:@"--deinterlace-mode"];
		//[viewerTaskArgs addObject:@"bob"];
		//[viewerTaskArgs addObject:@"--intf"];
		//[viewerTaskArgs addObject:@"rc"];
		//[viewerTaskArgs addObject:@"--rc-fake-tty"];
		
		//[viewerTaskArgs addObject:[NSString stringWithString:@"udp://@:41394"]];
		
		// Create a new viewerTask
		//viewerTask = [[NSTask alloc] init];
		//[viewerTask setStandardInput: [NSPipe pipe]];
		//[viewerTask setStandardOutput: [NSPipe pipe]];
		//[viewerTask setLaunchPath:@"/Applications/VLC.app/Contents/MacOS/VLC"];
		//[viewerTask setArguments:viewerTaskArgs];
		// [viewerTask launch];
		//usleep(600000);
		//pid = [viewerTask processIdentifier];
		//GetProcessForPID(pid, &psn);
		//SetFrontProcess(&psn);
		
		/* open UDP socket */
		int viewerSocket = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
		if (viewerSocket == -1)
		{
			NSLog(@"Couldn't open socket");
			//	[self addToAVCLog:[NSString stringWithFormat:@"Could not create socket for UDP streaming to viewer\n\n"]];	
			return;
		}
		
		// Set address to "local node"
		struct sockaddr_in socketAddr;
		inet_aton("127.0.0.1", &socketAddr.sin_addr);
		
		/* target port 41394 */
		socketAddr.sin_family = AF_INET;
		socketAddr.sin_port = htons(41394);
		
		if (connect(viewerSocket, (struct sockaddr *) &socketAddr, sizeof socketAddr) == -1)
		{
			[self addToAVCLog:[NSString stringWithFormat:@"Could not connect to viewer socket\n\n"]];	
			return;
		}
		
		pAVCDeviceStream = pCaptureDevice->CreateMPEGReceiverForDevicePlug(0,
																	   nil, // We'll install the structured callback later (MyStructuredDataPushProc),
																	   self,
																	   MPEGReceiverMessageReceivedProc,
																	   self,
																	   nil,
																	   kNumCyclesInMPEGReceiverSegment,
																	   kNumSegmentsInMPEGReceiverProgram);
		if (pAVCDeviceStream == nil)
		{
			[self addToAVCLog:[NSString stringWithFormat:@"Could not create MPEGReceiver\n\n"]];	
			return;
		}
		
		pAVCDeviceStream->pMPEGReceiver->registerStructuredDataPushCallback(MyStructuredDataPushProc, kNumCyclesInMPEGReceiverSegment, (void*) viewerSocket);
		
		res = pCaptureDevice->StartAVCDeviceStream(pAVCDeviceStream);
		if (res != kIOReturnSuccess)
		{
			[self addToAVCLog:[NSString stringWithFormat:@"Could not start MPEGReceiver\n\n"]];	
			pCaptureDevice->DestroyAVCDeviceStream(pAVCDeviceStream);
			return;
		}
		
		//[ViewerButton setTitle:kViewerButtonStopText];
	}
/*	else
	{
		// Stop viewer and MPEG receiver
		
		res = pAVCDevice->StopAVCDeviceStream(pAVCDeviceStream);
		pAVCDevice->DestroyAVCDeviceStream(pAVCDeviceStream);
		pAVCDeviceStream = nil;
		
		[viewerTask terminate];
		[viewerTask release];
		viewerTask = nil;
		
		close(viewerSocket);
		
		[ViewerButton setTitle:kViewerButtonStartText];
	}*/
}


- (void) startCapture
{
	IOReturn res;
	int status;
	
	if (captureInProgress == true)
	{
		[self abortCapture:@"User aborted capture"];
	}
	else
	{
		captureDeviceIndex = 0;
		pCaptureDevice = (AVCDevice*) CFArrayGetValueAtIndex(pAVCDeviceController->avcDeviceArray,captureDeviceIndex);
		
		// Attempt to open the device
		res = pCaptureDevice->openDevice(MyAVCDeviceMessageNotification, self);
		if (res != kIOReturnSuccess)
		{
			[CaptureStatus setStringValue:@"Could not open device"];
		}
		else
		{
			[CaptureStatus setStringValue:@"Device opened"];
			
			// Attempt to get a filename from the user
			/*if (pCaptureDevice->isDVDevice)
			{
				[savePanel setTitle:@"Select DV Capture File"];
				[savePanel setRequiredFileType:@"dv"];
			}
			else
			{
				[savePanel setTitle:@"Select MPEG2 Capture File"];
				[savePanel setRequiredFileType:@"m2t"];
			}*/
			
			//status = [savePanel runModal];
			/*if (status != NSOKButton)
			{
				[FileName setStringValue:@"No File Selected"];
				[CaptureStatus setStringValue:@"Idle"];
				pCaptureDevice->closeDevice();
				pCaptureDevice = nil;
			}*/
			//else
			{
				//	[FileName setStringValue:[savePanel filename]];
				
				// Create the file
				//	outFile = fopen([[savePanel filename] cString],"wb");
				/*if (!outFile)
				{
					[FileName setStringValue:@"Unable to open output file"];
					[CaptureStatus setStringValue:@"Idle"];
					pCaptureDevice->closeDevice();
					pCaptureDevice = nil;
				}
				else*/
				{
					[CaptureStatus setStringValue:@"File opened"];
					[PacketCount setStringValue:@"0"];
					[Overruns setStringValue:@"0"];
					[Dropped setStringValue:@"0"];
					[EMI setStringValue:@""];
					
					// Set the Recording Date/Time popups for the tuner recording prefs 
					// sheet to the current date and time.
					/*					GetTime(&currentDateAndTime);
					 [RecordingStartMonth selectItemAtIndex: (currentDateAndTime.month - 1)];
					 [RecordingStartDay selectItemAtIndex: (currentDateAndTime.day - 1)];
					 if  ((currentDateAndTime.year > 2004) && (currentDateAndTime.year < 2010))
					 [RecordingStartYear selectItemAtIndex:(currentDateAndTime.year-2005)];
					 else
					 [RecordingStartYear selectItemAtIndex:0];
					 
					 if (currentDateAndTime.hour > 11)
					 {
					 [RecordingStartHour selectItemAtIndex:(currentDateAndTime.hour-12)];
					 [RecordingStartAMPM selectItemAtIndex:1];
					 }
					 else
					 {
					 [RecordingStartHour selectItemAtIndex:currentDateAndTime.hour];
					 [RecordingStartAMPM selectItemAtIndex:0];
					 }
					 [RecordingStartMinute selectItemAtIndex:currentDateAndTime.minute];
					 */
					// See if we're capturing from a tape unit or a tuner unit
					/*if (pCaptureDevice->hasTapeSubunit)
					{
						// Hide the channel changing stuff on the tuner prefs sheet,
						// and disable channel change.
						[tunerChannel setHidden:YES];
						[enableChannelChangeButton setState:NSOffState];
						[enableChannelChangeButton setHidden:YES];
						[tunerChannelDescriptionText setHidden:YES];
						
						// Raise tape prefs sheet
						[self raiseTapePrefsSheet:self];
					}
					else
					{
						// Unhide the channel changing stuff on the tuner prefs sheet.
						[tunerChannel setHidden:NO];
						[enableChannelChangeButton setHidden:NO];
						[tunerChannelDescriptionText setHidden:NO];
						
						// Raise tuner prefs sheet
						[self raiseTunerPrefsSheet:self];
					}*/
				}
			}
		}
	}	
	captureMode = kCaptureModeTuner;
	captureState = kCaptureStateTimerArmed;
	captureInProgress = true;
}

//////////////////////////////////////////////////////
// CaptureButtonPushed
//////////////////////////////////////////////////////
- (IBAction) CaptureButtonPushed:(id)sender
{
	IOReturn res;
	int status;
	NSObject *savePanel = nil;//[NSSavePanel savePanel];
	DateTimeRec currentDateAndTime;
	
	if (captureInProgress == true)
	{
		[self abortCapture:@"User aborted capture"];
	}
	else
	{
		pCaptureDevice = (AVCDevice*) CFArrayGetValueAtIndex(pAVCDeviceController->avcDeviceArray,captureDeviceIndex);
		
		// Attempt to open the device
		res = pCaptureDevice->openDevice(MyAVCDeviceMessageNotification, self);
		if (res != kIOReturnSuccess)
		{
			[CaptureStatus setStringValue:@"Could not open device"];
		}
		else
		{
			[CaptureStatus setStringValue:@"Device opened"];
			
			// Attempt to get a filename from the user
			if (pCaptureDevice->isDVDevice)
			{
				[savePanel setTitle:@"Select DV Capture File"];
				[savePanel setRequiredFileType:@"dv"];
			}
			else
			{
				[savePanel setTitle:@"Select MPEG2 Capture File"];
				[savePanel setRequiredFileType:@"m2t"];
			}
			
			//status = [savePanel runModal];
			if (status != NSOKButton)
			{
				[FileName setStringValue:@"No File Selected"];
				[CaptureStatus setStringValue:@"Idle"];
				pCaptureDevice->closeDevice();
				pCaptureDevice = nil;
			}
			else
			{
				[FileName setStringValue:[savePanel filename]];
				
				// Create the file
				outFile = fopen([[savePanel filename] cString],"wb");
				if (!outFile)
				{
					[FileName setStringValue:@"Unable to open output file"];
					[CaptureStatus setStringValue:@"Idle"];
					pCaptureDevice->closeDevice();
					pCaptureDevice = nil;
				}
				else
				{
					[CaptureStatus setStringValue:@"File opened"];
					[PacketCount setStringValue:@"0"];
					[Overruns setStringValue:@"0"];
					[Dropped setStringValue:@"0"];
					[EMI setStringValue:@""];

					// Set the Recording Date/Time popups for the tuner recording prefs 
					// sheet to the current date and time.
/*					GetTime(&currentDateAndTime);
					[RecordingStartMonth selectItemAtIndex: (currentDateAndTime.month - 1)];
					[RecordingStartDay selectItemAtIndex: (currentDateAndTime.day - 1)];
					if  ((currentDateAndTime.year > 2004) && (currentDateAndTime.year < 2010))
						[RecordingStartYear selectItemAtIndex:(currentDateAndTime.year-2005)];
					else
						[RecordingStartYear selectItemAtIndex:0];
					
					if (currentDateAndTime.hour > 11)
					{
						[RecordingStartHour selectItemAtIndex:(currentDateAndTime.hour-12)];
						[RecordingStartAMPM selectItemAtIndex:1];
					}
					else
					{
						[RecordingStartHour selectItemAtIndex:currentDateAndTime.hour];
						[RecordingStartAMPM selectItemAtIndex:0];
					}
					[RecordingStartMinute selectItemAtIndex:currentDateAndTime.minute];
*/
					// See if we're capturing from a tape unit or a tuner unit
					if (pCaptureDevice->hasTapeSubunit)
					{
						// Hide the channel changing stuff on the tuner prefs sheet,
						// and disable channel change.
						[tunerChannel setHidden:YES];
						[enableChannelChangeButton setState:NSOffState];
						[enableChannelChangeButton setHidden:YES];
						[tunerChannelDescriptionText setHidden:YES];
						
						// Raise tape prefs sheet
						[self raiseTapePrefsSheet:self];
					}
					else
					{
						// Unhide the channel changing stuff on the tuner prefs sheet.
						[tunerChannel setHidden:NO];
						[enableChannelChangeButton setHidden:NO];
						[tunerChannelDescriptionText setHidden:NO];
						
						// Raise tuner prefs sheet
						[self raiseTunerPrefsSheet:self];
					}
				}
			}
		}
	}
}

//////////////////////////////////////////////////////
// DeviceTableInteraction
//////////////////////////////////////////////////////
- (IBAction) DeviceTableInteraction:(id)sender
{	
	// No longer used. Code from here was moved
	// into tableViewSelectionDidChange delegate method.
}

//////////////////////////////////////////////////////
// userInterfaceUpdateTimerExpired
//////////////////////////////////////////////////////
- (void) userInterfaceUpdateTimerExpired:(NSTimer*)timer
{
	IOReturn res;
	UInt8 transportMode;
	UInt8 transportState;
	bool isStable;
	UInt32 remainingTimeInSeconds;
	UInt32 remainingHours;
	UInt32 remainingMinutes;
	UInt32 remainingSeconds;

	PanelSubunitController *panelController;
	UInt8 powerState;
				
	if ((captureInProgress == true) && (captureMode == kCaptureModeTape))
	{
		[PacketCount setIntValue:packetCount];
		[Overruns setIntValue:overrunCount];
		[Dropped setIntValue:droppedCount];
		
		if (!pCaptureDevice->isDVDevice)
		{
			// report the correct EMI string
			switch (lastEMIValue)
			{
				case 0:
					[EMI setStringValue:@"Copy Freely"];
					break;
					
				case 1:
					[EMI setStringValue:@"No More Copies"]; 
					break;
					
				case 2:
					[EMI setStringValue:@"Copy Once"];
					break;
					
				case 3:
					[EMI setStringValue:@"Copy Never"];
					break;
					
				default:
					[EMI setStringValue:@""];
					break;
			}
		}
		else
			[EMI setStringValue:@""];
		
		switch (captureState)
		{
			case kCaptureStateRewind:
				res = tapeController->GetTransportState(&transportMode,&transportState,&isStable);
				if (res != kIOReturnSuccess)
				{
					[self abortCapture:@"Communication error with device"];
				}
				else
				{
					// See if we are done rewinding, and if so, create receiver object and start transport playing
					if (!((transportMode == kAVCTapeTportModeWind) && (transportState == kAVCTapeWindRew)))
					{
						// Done rewinding
						packetCount = 0;
						lastPacketCount = 0;
						captureStalledCount = 0;
						[self resetDCLOverrunCount];
						[self resetDroppedFrameCount];
						
						// Create receiver object
						if (pCaptureDevice->isMPEGDevice)
						{
							pAVCDeviceStream = pCaptureDevice->CreateMPEGReceiverForDevicePlug(0,
																							nil, // We'll install the extended callback later (MPEGPacketDataStoreHandler),
																							self,
																							MPEGReceiverMessageReceivedProc,
																							self,
																							nil,
																							kCyclesPerReceiveSegment,
																							kNumReceiveSegments*2);
							if (pAVCDeviceStream == nil)
							{
								[self abortCapture:@"Could not create MPEGReceiver"];
							}
							else
							{
								// Install the extended MPEG receive callback 
								pAVCDeviceStream->pMPEGReceiver->registerExtendedDataPushCallback(MPEGPacketDataStoreHandler,self);
								lastEMIValue = 0xFFFFFFFF;
								
								pCaptureDevice->StartAVCDeviceStream(pAVCDeviceStream);
								captureState = kCaptureStateReceivePackets;

								// Start transport playing
								res = tapeController->Play();
								[CaptureStatus setStringValue:@"Capturing from device"];
							}
						}
						else
						{
							pAVCDeviceStream = pCaptureDevice->CreateDVReceiverForDevicePlug(0,
																						  DVFrameReceivedHandler,
																						  self,
																						  DVReceiverMessageReceivedProc,
																						  self,
																						  nil,
																						  kCyclesPerDVReceiveSegment,
																						  kNumReceiveSegments*2,
																						  pCaptureDevice->dvMode);
							if (pAVCDeviceStream == nil)
							{
								[self abortCapture:@"Could not create DVReceiver"];
							}
							else
							{
								pCaptureDevice->StartAVCDeviceStream(pAVCDeviceStream);
								captureState = kCaptureStateReceivePackets;
								
								// Start transport playing
								res = tapeController->Play();
								[CaptureStatus setStringValue:@"Capturing from device"];

							}
						}
						
					}
				}
				break;
				
			case kCaptureStateReceivePackets:
				if (packetCount != lastPacketCount)
				{
					// We're still receiving frames/packets, so keep capturing
					lastPacketCount = packetCount;
					captureStalledCount = 0;
				}
				else
				{
					// This callback happens twice a second. If no packets have been received within 
					// the last kNumSecondsOfNoPacketsToAbortCapture seconds, then we're done.
					captureStalledCount += 1;
					if (captureStalledCount > kNumSecondsOfNoPacketsToAbortCapture*2)
					{
						[self abortCapture:@"Capture complete"];
					}
				}

			default:
				break;
			
		};
	}
	else if ((captureInProgress == true) && (captureMode == kCaptureModeTuner))
	{
		//	GetDateTime(&currentTimeInSeconds);

		if (captureState == kCaptureStateTimerArmed)
		{
			if (currentTimeInSeconds >= scheduledTunerRecordingStartTimeInSeconds)
			{
				// Start recording here!!!!!!!

				// Calcuate when we should stop recording
				tunerRecordingStopTimeInSeconds = currentTimeInSeconds + ([recordingTimeInMinutes intValue]*60);
				
				// First, make sure the tuner is powered on!
				res = pCaptureDevice->GetPowerState(&powerState);
				if ((res == kIOReturnSuccess) && (powerState == kAVCPowerStateOff))
				{
					pCaptureDevice->SetPowerState(kAVCPowerStateOn);
					
					// Give it time to power up.
					usleep(2000000); // Sleep for two seconds
				}
				
				// Change channel if needed.
				if ([enableChannelChangeButton state] == NSOnState)
				{
					panelController = new PanelSubunitController(pCaptureDevice);
					
					res = panelController->Tune([tunerChannel intValue]);
					if (res != kIOReturnSuccess)
					{
						// TODO: What (if anything) should we do if the channel change fails?
						// Currently we do nothing, proceed as normal.
					}
					
					// Give it time to transition.
					usleep(1000000); // Sleep for one second
					
					delete panelController;
				}
				
				// Start capture.
				packetCount = 0;
				lastPacketCount = 0;
				captureStalledCount = 0;
				[self resetDCLOverrunCount];
				[self resetDroppedFrameCount];
				
				// Create receiver object
				if (pCaptureDevice->isDVDevice)
				{
					pAVCDeviceStream = pCaptureDevice->CreateDVReceiverForDevicePlug(0,
																					 DVFrameReceivedHandler,
																					 self,
																					 DVReceiverMessageReceivedProc,
																					 self,
																					 nil,
																					 kCyclesPerDVReceiveSegment,
																					 kNumReceiveSegments*2,
																					 pCaptureDevice->dvMode);
					if (pAVCDeviceStream == nil)
					{
						[self abortCapture:@"Could not create DVReceiver"];
					}
					else
					{
						pCaptureDevice->StartAVCDeviceStream(pAVCDeviceStream);
						captureState = kCaptureStateReceivePackets;
						[CaptureStatus setStringValue:@"Capturing from device"];
					}
				}
				else
				{
					pAVCDeviceStream = pCaptureDevice->CreateMPEGReceiverForDevicePlug(0,
																					   nil, // We'll install the extended callback later (MPEGPacketDataStoreHandler),
																					   self,
																					   MPEGReceiverMessageReceivedProc,
																					   self,
																					   nil,
																					   kCyclesPerReceiveSegment,
																					   kNumReceiveSegments*2);
					if (pAVCDeviceStream == nil)
					{
						[self abortCapture:@"Could not create MPEGReceiver"];
					}
					else
					{
						// Install the extended MPEG receive callback 
						pAVCDeviceStream->pMPEGReceiver->registerExtendedDataPushCallback(MPEGPacketDataStoreHandler,self);
						lastEMIValue = 0xFFFFFFFF;

						pCaptureDevice->StartAVCDeviceStream(pAVCDeviceStream);
						captureState = kCaptureStateReceivePackets;
						[CaptureStatus setStringValue:@"Capturing from device"];
					}
				}
			}
			else
			{
				// Update status message with remaining time until timer record starts
				remainingSeconds = (scheduledTunerRecordingStartTimeInSeconds - currentTimeInSeconds);
				remainingHours = remainingSeconds / 3600;
				remainingSeconds -= (remainingHours*3600);
				remainingMinutes = remainingSeconds/60;
				remainingSeconds -= (remainingMinutes*60);
				
				[CaptureStatus setStringValue:[NSString stringWithFormat:@"Timer-based recording will start in %02d:%02d:%02d",
					remainingHours,remainingMinutes,remainingSeconds]];
			}
		}
		else
		{
			[PacketCount setIntValue:packetCount];
			[Overruns setIntValue:overrunCount];
			[Dropped setIntValue:droppedCount];
			
			if (!pCaptureDevice->isDVDevice)
			{
				// report the correct EMI string
				switch (lastEMIValue)
				{
					case 0:
						[EMI setStringValue:@"Copy Freely"];
						break;
						
					case 1:
						[EMI setStringValue:@"No More Copies"]; 
						break;
						
					case 2:
						[EMI setStringValue:@"Copy Once"];
						break;
						
					case 3:
						[EMI setStringValue:@"Copy Never"];
						break;
						
					default:
						[EMI setStringValue:@""];
						break;
				}
			}
			else
				[EMI setStringValue:@""];
			
			if (currentTimeInSeconds > tunerRecordingStopTimeInSeconds)
			{
				[self abortCapture:@"Capture complete"];
			}
			else
			{
				remainingTimeInSeconds = tunerRecordingStopTimeInSeconds - currentTimeInSeconds;
				
				remainingSeconds = remainingTimeInSeconds;
				remainingHours = remainingSeconds / 3600;
				remainingSeconds -= (remainingHours*3600);
				remainingMinutes = remainingSeconds/60;
				remainingSeconds -= (remainingMinutes*60);
				
				[CaptureStatus setStringValue:[NSString stringWithFormat:@"Timer-based recording in process, ends in %02d:%02d:%02d",
					remainingHours,remainingMinutes,remainingSeconds]];
			}
		}
	}
	
	[availableDevices reloadData];
}	

//////////////////////////////////////////////////////
// abortCapture
//////////////////////////////////////////////////////
- (void) abortCapture: (NSString*) abortString
{
	IOReturn res;

	captureInProgress = false;
	
	[CaptureStatus setStringValue:abortString];
	[CaptureButton setTitle:kCaptureButtonText];
	
	// Stop and destroy the receive stream object
	if (pAVCDeviceStream)
	{
		pCaptureDevice->StopAVCDeviceStream(pAVCDeviceStream);
		pCaptureDevice->DestroyAVCDeviceStream(pAVCDeviceStream);
		pAVCDeviceStream = nil;
	}

	// Close the file
	if (outFile)
		fclose(outFile);
	
	if(captureMode == kCaptureModeTape)
	{
		// Stop the device
		res = tapeController->Wind(kAVCTapeWindStop);
		
		// Close the device
		delete tapeController;
	}

	pCaptureDevice->closeDevice();
	pCaptureDevice = nil;
}
	
//////////////////////////////////////////////////////
// setCurrentEMI
//////////////////////////////////////////////////////
- (void) setCurrentEMI:(UInt32)emiValue
{
	lastEMIValue = emiValue;
}

//////////////////////////////////////////////////////
// incrementDCLOverrunCount
//////////////////////////////////////////////////////
- (void) incrementDCLOverrunCount
{
	overrunCount += 1;
}

//////////////////////////////////////////////////////
// resetDCLOverrunCount
//////////////////////////////////////////////////////
- (void) resetDCLOverrunCount
{
	overrunCount = 0;
}

//////////////////////////////////////////////////////
// incrementDroppedFrameCount
//////////////////////////////////////////////////////
- (void) incrementDroppedFrameCount
{
	droppedCount += 1;
}

//////////////////////////////////////////////////////
// resetDroppedFrameCount
//////////////////////////////////////////////////////
- (void) resetDroppedFrameCount
{
	droppedCount = 0;
}


//////////////////////////////////////////////////////
// raiseTunerPrefsSheet
//////////////////////////////////////////////////////
- (void) raiseTunerPrefsSheet:(id)sender
{
/*	[NSApp beginSheet:tunerRecordingPrefsWindow 
	   modalForWindow:[NSApp mainWindow]
		modalDelegate:self
	   didEndSelector:@selector(tunerPrefsSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];*/
}

//////////////////////////////////////////////////////
// endTunerPrefsSheet
//////////////////////////////////////////////////////
- (IBAction) endTunerPrefsSheet:(id)sender
{
	DateTimeRec timerDateAndTime;
	UInt32 timerTimeInSeconds;
	
	// Make sure if timer recording is enabled, the specified time is not in the past
	if ([enableTimerRecordingButton state] == NSOnState)
	{
		timerDateAndTime.year = ([RecordingStartYear indexOfSelectedItem]+2005);
		timerDateAndTime.month = ([RecordingStartMonth indexOfSelectedItem]+1);
		timerDateAndTime.day = ([RecordingStartDay indexOfSelectedItem]+1);
		
		if ([RecordingStartAMPM indexOfSelectedItem] == 0)
		{
			// AM
			timerDateAndTime.hour = [RecordingStartHour indexOfSelectedItem];
		}
		else
		{
			// PM
			timerDateAndTime.hour = ([RecordingStartHour indexOfSelectedItem]+12);
		}
		timerDateAndTime.minute = [RecordingStartMinute indexOfSelectedItem];
		timerDateAndTime.second = 0;
		//	DateToSeconds(&timerDateAndTime,&timerTimeInSeconds); 
		
		//		GetDateTime(&currentTimeInSeconds);
		//if/ (currentTimeInSeconds >= timerTimeInSeconds)
		{
			//		NSRunAlertPanel(@"Error, Invalid Recording Time Specified",@"Specified record start time is in the past!",@"OK",nil,nil);
			//		return;
		}
		
		//	scheduledTunerRecordingStartTimeInSeconds = timerTimeInSeconds;
	}
	else
	{
		scheduledTunerRecordingStartTimeInSeconds = 0; // Start now!!!!
	}

	captureMode = kCaptureModeTuner;
	captureState = kCaptureStateTimerArmed;
	captureInProgress = true;
	
	[tunerRecordingPrefsWindow orderOut:sender];
	//[NSApp endSheet:tunerRecordingPrefsWindow returnCode:1];
}

//////////////////////////////////////////////////////
// tunerPrefsSheetDidEnd
//////////////////////////////////////////////////////
- (void) tunerPrefsSheetDidEnd:(NSWindow*) sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
	[CaptureButton setTitle:kStopCaptureText];
}

//////////////////////////////////////////////////////
// raiseTapePrefsSheet
//////////////////////////////////////////////////////
- (void) raiseTapePrefsSheet:(id)sender
{
	/*[NSApp beginSheet:tapeRecordingPrefsWindow 
	   modalForWindow:[NSApp mainWindow]
		modalDelegate:self
	   didEndSelector:@selector(tapePrefsSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];*/
}

//////////////////////////////////////////////////////
// endTapePrefsSheet
//////////////////////////////////////////////////////
- (IBAction) endTapePrefsSheet:(id)sender
{
	[tapeRecordingPrefsWindow orderOut:sender];
	//[NSApp endSheet:tapeRecordingPrefsWindow returnCode:1];
}

//////////////////////////////////////////////////////
// tapePrefsSheetDidEnd
//////////////////////////////////////////////////////
- (void) tapePrefsSheetDidEnd:(NSWindow*) sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
	IOReturn res;
	UInt8 transportMode;
	UInt8 transportState;
	bool isStable;
	
	// See if the user selected timer-based recording, or tape-control type recording
	if ([tapeRecordingMode indexOfSelectedItem] != 0)
	{
		// Create a tape subunit controller for this device
		tapeController = new TapeSubunitController(pCaptureDevice);
		
		// Verify there's a tape in the device
		res = tapeController->GetTransportState(&transportMode,&transportState,&isStable);
		if (res != kIOReturnSuccess)
		{
			// Cannot determine if there's a tape in the device, don't allow capture
			[CaptureStatus setStringValue:@"Could not determine device transport state"];
			fclose(outFile);
			delete tapeController;
			pCaptureDevice->closeDevice();
			pCaptureDevice = nil;
		}
		else
		{
			if (transportMode == kAVCTapeTportModeLoad)
			{
				// No tape, don't allow capture
				[CaptureStatus setStringValue:@"No tape detected in device"];
				fclose(outFile);
				delete tapeController;
				pCaptureDevice->closeDevice();
				pCaptureDevice = nil;
			}
			else
			{
				// We have the device opened, a file opened, and we
				// determined that there is a tape in the device, so
				// we can now start the capture engine.
				
				// Start the capture engine
				[CaptureStatus setStringValue:@"Rewinding tape"];
				
				// Start a rewind
				res = tapeController->Wind(kAVCTapeWindStop);
				usleep(kMicroSecondsPerSecond/2);
				res = tapeController->Wind(kAVCTapeWindRew);
				
				captureMode = kCaptureModeTape;
				captureInProgress = true;
				captureState = kCaptureStateRewind;
				[CaptureButton setTitle:kStopCaptureText];
			}
		}
	}
	else
	{
		// Bring up the tuner prefs sheet for timer-based recording from this tape device.
		[self raiseTunerPrefsSheet:self];
	}
}

//////////////////////////////////////////////////////
// TableView methods
//////////////////////////////////////////////////////
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	AVCDevice *pAVCDevice;
	int row = [availableDevices selectedRow];
	
	// This function is called whenever the user clicks somewhere on the availableDevices table 
	
	if (captureInProgress == true)
	{
		// Don't allow alternative selection when capture in progress
		[availableDevices selectRow:captureDeviceIndex byExtendingSelection:NO];
	}
	else
	{
		if (row < 0)
		{
			if (CFArrayGetCount(pAVCDeviceController->avcDeviceArray) > 0)
			{	
				row = 0;
				[availableDevices selectRow:row byExtendingSelection:NO];
			}
			else
				return;
		}
		
		// A valid row is selected
		captureDeviceIndex = row;
		pAVCDevice = (AVCDevice*) CFArrayGetValueAtIndex(pAVCDeviceController->avcDeviceArray,row);
		if (!pAVCDevice)
			return;
		
		if ((pAVCDevice->isAttached) && ((pAVCDevice->hasTapeSubunit) || (pAVCDevice->hasMonitorOrTunerSubunit)))
		{
			// This is a device we can capture from
			[CaptureButton setEnabled:YES];
		}
		else
		{
			// Not a device we can capture from
			[CaptureButton setEnabled:NO];
		}
	}
}

- (int) numberOfRowsInTableView: (NSTableView*) aTableView
{
	if (pAVCDeviceController)
		return CFArrayGetCount(pAVCDeviceController->avcDeviceArray);
	else
		return 0;
}

- (id) tableView: (NSTableView*) aTableView
objectValueForTableColumn: (NSTableColumn*) aTableColumn
			 row: (int) rowIndex
{
	AVCDevice *pAVCDevice;
	NSString *identifier = [aTableColumn identifier];
	NSString *indexString = NULL;

	if ((aTableView == availableDevices) && (pAVCDeviceController))
	{
		pAVCDevice = (AVCDevice*) CFArrayGetValueAtIndex(pAVCDeviceController->avcDeviceArray,rowIndex);
		if (!pAVCDevice)
			return NULL;

		if ([identifier isEqualToString:@"device"] == YES)
		{
			indexString = [NSString stringWithCString:pAVCDevice->deviceName];
		}
		else if ([identifier isEqualToString:@"mode"] == YES)
		{
			if (pAVCDevice->isDVDevice)
			{
				indexString = [NSString stringWithFormat:@"DV"];
			}
			else if (pAVCDevice->isMPEGDevice)
			{
				indexString = [NSString stringWithFormat:@"MPEG2-TS"];
			}
			else
			{
				indexString = [NSString stringWithFormat:@"Other/Unknown"];
			}
		}
		else if ([identifier isEqualToString:@"attached"] == YES)
		{
			indexString = [NSString stringWithFormat:@"%s",pAVCDevice->isAttached ? "Yes" : "No"];
		}
		else if ([identifier isEqualToString:@"devicetype"] == YES)
		{
			if (pAVCDevice->hasTapeSubunit)
				indexString = [NSString stringWithFormat:@"Tape"];
			else
				if (pAVCDevice->hasMonitorOrTunerSubunit)
					indexString = [NSString stringWithFormat:@"Tuner"];
			else
				indexString = [NSString stringWithFormat:@"Other"];
		}
	}
	
	return indexString;
}

- (void) tableView: (NSTableView*) aTableView
	setObjectValue: (id) anObject
	forTableColumn: (NSTableColumn*) aTableColumn
			   row: (int) rowIndex
{
	if (aTableView == availableDevices)
	{
		
	}
	else
	{
		
	}
	
}

@end



//////////////////////////////////////////////////////////////////////
//
// MyAVCDeviceControllerNotification
//
//////////////////////////////////////////////////////////////////////
IOReturn MyAVCDeviceControllerNotification(AVCDeviceController *pAVCDeviceController, void *pRefCon, AVCDevice* pDevice)
{	
	// Note: This app doesn't use this callback, and instead relies on polling in the userInterfaceUpdateTimerExpired function
}	

//////////////////////////////////////////////////////////////////////
//
// MyAVCDeviceMessageNotification
//
//////////////////////////////////////////////////////////////////////
IOReturn MyAVCDeviceMessageNotification (class AVCDevice *pAVCDevice,
												 natural_t messageType,
												 void * messageArgument,
												 void *pRefCon)
{

	AVCVideoCapController *controller = (AVCVideoCapController*) pRefCon;

	if ((messageType == kIOMessageServiceIsRequestingClose) && (captureInProgress == true))
		[controller abortCapture:@"Device disconnected during capture"];
}

//////////////////////////////////////////////////////////////////////
//
// MPEGPacketDataStoreHandler
//
//////////////////////////////////////////////////////////////////////
IOReturn MPEGPacketDataStoreHandler(UInt32 tsPacketCount, 
									UInt32 **ppBuf, 
									void *pRefCon, 
									UInt32 isochHeader,
									UInt32 cipHeader0,
									UInt32 cipHeader1,
									UInt32 fireWireTimeStamp)
{
	unsigned int i;
	unsigned int cnt;
	UInt8 *pTSPacketBytes;
	AVCVideoCapController *controller = (AVCVideoCapController*) pRefCon;
	
	// Set the EMI
	[controller setCurrentEMI:((isochHeader & 0x0000000C) >> 2)];

	// Increment packet count for progress display
	packetCount += tsPacketCount;
	
	// Write packets to file
	for (i=0;i<tsPacketCount;i++)
	{
		// Write TS packet to m2t file
		cnt = fwrite(ppBuf[i],1,kMPEG2TSPacketSize,stdout);
		if (cnt != kMPEG2TSPacketSize)
		{
			[controller abortCapture:@"Error writing capture file"];

			return kIOReturnError;
		}
	}
	
	return kIOReturnSuccess;
}	

//////////////////////////////////////////////////////////////////////
//
// MPEGReceiverMessageReceivedProc
//
//////////////////////////////////////////////////////////////////////
void MPEGReceiverMessageReceivedProc(UInt32 msg, UInt32 param1, UInt32 param2, void *pRefCon)
{
	AVCVideoCapController *controller = (AVCVideoCapController*) pRefCon;
	
	switch (msg)
	{
		case kMpeg2ReceiverDCLOverrun:
		case kMpeg2ReceiverReceivedBadPacket:
			[controller incrementDCLOverrunCount];
			break;
			
		default:
			break;
	};
}

//////////////////////////////////////////////////////////////////////
//
// DVFrameReceivedHandler
//
//////////////////////////////////////////////////////////////////////
IOReturn DVFrameReceivedHandler (DVFrameReceiveMessage msg, DVReceiveFrame* pFrame, void *pRefCon)
{
	
	UInt32 cnt;
	AVCVideoCapController *controller = (AVCVideoCapController*) pRefCon;
	
	if (msg == kDVFrameReceivedSuccessfully)
	{
		packetCount += 1;
		
		cnt = fwrite(pFrame->pFrameData,1,pFrame->frameLen,outFile);
		if (cnt != pFrame->frameLen)
		{
			[controller abortCapture:@"Error writing capture file"];
		}
	}
	else if ((msg ==kDVFrameDropped) || (msg == kDVFrameCorrupted))
	{
		[controller incrementDroppedFrameCount];
	}
	
	// By returning an error, we don't have to subsequently release the frame
	return kIOReturnError;
	
}

//////////////////////////////////////////////////////////////////////
//
// DVReceiverMessageReceivedProc
//
//////////////////////////////////////////////////////////////////////
void DVReceiverMessageReceivedProc(UInt32 msg, UInt32 param1, UInt32 param2, void *pRefCon)
{
	AVCVideoCapController *controller = (AVCVideoCapController*) pRefCon;
	
	switch (msg)
	{
		case kDVReceiverDCLOverrun:
		case kDVReceiverReceivedBadPacket:
			[controller incrementDCLOverrunCount];
			break;
			
		default:
			break;
	};
}
