/*
	File:		FWA_IORemapper.h
 
 Synopsis: This is the header for the FWA_IORemapper Class object
  
	Copyright: 	© Copyright 2001-2003 Apple Computer, Inc. All rights reserved.
 
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

#ifndef __AVCVIDEOSERVICES_FWA_IOREMAPPER__
#define __AVCVIDEOSERVICES_FWA_IOREMAPPER__

namespace AVS
{

#define kRemapperNumCyclesPerUniversalReceiveSegment 4
#define kRemapperNumUniversalReceiveSegments 12

// Note: Transmit program length must be a factor of 8000 for the math to work!
#define kRemapperNumCyclesPerUniversalTransmitSegment 16
#define kRemapperNumUniversalTransmitSegments 4
#define kRemapperNumCyclesInTransmitProgram (kRemapperNumCyclesPerUniversalTransmitSegment*kRemapperNumUniversalTransmitSegments)

// Note: The following constant must be a multiple of 16 (1*16) = 2 mSec latency. So, latency setting is always in 2 mSec increments.
// It must be a multiple of 16 since the SYT field which we are copying from in to out includes 4-bits of cycle value (i.e. 16 cycles)
#define kRemapperInToOutLatencyInCycles (2*16)

// Number of samples per cycle (8 for up to 96KHz, 16 for 96KHz, 32 for greater than 96KHz)
#define kRemapperNumSourcePacketsPerCycle 32

class FWA_IORemapper
{

public:
	
	// Constructor
	FWA_IORemapper(UInt8 isochInChan,
				   UInt8 isochOutChan,
				   UInt8 numSubStreamsInOutput,
				   UInt8 *pInputSubStreamIndexes,
				   IOFWSpeed transmitterFWSpeed = kFWSpeed400MBit,
				   Boolean doIRMForTransmitter = true);
	
	// Destructor
	~FWA_IORemapper();
	
	// Start/Stop routines
	IOReturn start(void);
	IOReturn stop(void);
	
	// Allow the client to change the IO Mapping
	IOReturn setNewIOMap(UInt8 numSubStreamsInOutput, UInt8 *pInputSubStreamIndexes);

private:

	// Callbacks for the receiver and transmitter
	static void ReceiverMessageReceivedProc(UInt32 msg, UInt32 param1, UInt32 param2, void *pRefCont);
	static void TransmitterMessageReceivedProc(UInt32 msg, UInt32 param1, UInt32 param2, void *pRefCont);
	static IOReturn DataReceiveCallback(UInt32 CycleDataCount, UniversalReceiveCycleData *pCycleData, void *pRefCon);
	static IOReturn ReceiverNoDataProc(void *pRefCon);
	static IOReturn TransmitterDataPullProc(UniversalTransmitterCycleInfo *pCycleInfo, class UniversalTransmitter *pTransmitter, void *pRefCon);
	
	UniversalReceiver *receiver;				// A pointer to a universal isoch receiver
	UniversalTransmitter *transmitter;			// A pointer to a universal isoch transmitter
	
	UInt8 numSubStreams;						// Number of sub-streams to insert into output program
	UInt8 inputSubStreamIndexes[256];			// The array of indexes from the receive stream for each of the substreams added to the transmitter stream
	UInt8 maxSubStreams;						// Save the original numSubStreams to ensure that future IO mappings don't exceed what we can support
	
	UInt8 isochInChannel;						// The channel for the UniversalReceiver
	UInt8 isochOutChannel;						// The channel for the UniversalTransmitter 

	IOFWSpeed transmitterSpeed;					// The FireWire speed for the transmitter
	Boolean doTransmitterIRM;					// A boolean specifying whether or not we should do IRM allocations for the transmitter
	
	UInt8 *pTransmitterTransmitBuffer;			// A pointer to the transmitter's buffer

	UInt32 transmitterCycleBufferFullSize;		// The full size of buffer we ask the transmitter to allocate for us
	
	UInt8 *pTransmitCycleBuf[kRemapperNumCyclesInTransmitProgram];		// An array of pointers to individual cycle buffers
	UInt32 transmitCycleBufLen[kRemapperNumCyclesInTransmitProgram];	// An array of length values, one associated with each cycle buffer	
	
	UInt32 *pCIPOnlyBuffer;						// A pointer to the CIP-only portion of the transmitter buffer
	
	UInt32 lastReceiveCycle;					// The cycle nummber of the last receive packet
};

} // namespace AVS

#endif //  __AVCVIDEOSERVICES_FWA_IOREMAPPER__
