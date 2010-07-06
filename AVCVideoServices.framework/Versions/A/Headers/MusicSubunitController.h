/*
	File:   MusicSubunitController.h
 
 Synopsis: This is the header for the MusicSubunitController Class 
 
	Copyright: 	¬© Copyright 2001-2003 Apple Computer, Inc. All rights reserved.
 
	Written by: ayanowitz
 
 Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
 ("Apple") in consideration of your agreement to the following terms, and your
 use, installation, modification or redistribution of this Apple software
 constitutes acceptance of these terms.  If you do not agree with these terms,
 please do not use, install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject
 to these terms, Apple grants you a personal, non-exclusive license, under Apple‚Äôs
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

#ifndef __AVCVIDEOSERVICES_MUSICSUBUNITCONTROLLER__
#define __AVCVIDEOSERVICES_MUSICSUBUNITCONTROLLER__

namespace AVS
{

#define kMusicSubunitDeviceParserVersion 1	
	
// These are the constants for sample rates in AV/C Stream Format Information Specification
// Note that they are different from what's in the Music Subunit descriptors.
enum
{
	kAVCStreamFormat_SampleRate_22_05_KHz	= 0x00,
	kAVCStreamFormat_SampleRate_24_KHz		= 0x01,
	kAVCStreamFormat_SampleRate_32_Khz		= 0x02,
	kAVCStreamFormat_SampleRate_44_10_KHz	= 0x03,
	kAVCStreamFormat_SampleRate_48_KHz		= 0x04,
	kAVCStreamFormat_SampleRate_96_KHz		= 0x05,
	kAVCStreamFormat_SampleRate_176_40_KHz	= 0x06,
	kAVCStreamFormat_SampleRate_192_KHz		= 0x07,
	kAVCStreamFormat_SampleRate_88_20_KHz	= 0x0A,
	kAVCStreamFormat_SampleRate_Dont_Care	= 0x0F,
};
	
// These are the stream-formats for both the AV/C Stream Format Information Specification
// And the Music Subunit Specification
typedef unsigned int MusicClusterFormats;
enum
{
	kStreamFormatIEC60958_3				= 0x00,
	kStreamFormatIEC61937_3				= 0x01,
	kStreamFormatIEC61937_4				= 0x02,
	kStreamFormatIEC61937_5				= 0x03,
	kStreamFormatIEC61937_6				= 0x04,
	kStreamFormatIEC61937_7				= 0x05,
	kStreamFormatMBLA					= 0x06,
	kStreamFormatDVDAudio				= 0x07,
	kStreamFormatOneBit					= 0x08,
	kStreamFormatOneBitSACD				= 0x09,
	kStreamFormatOneBitEncoded			= 0x0A,
	kStreamFormatOneBitSACDEncoded		= 0x0B,
	kStreamFormatHiPrecisionMBLA		= 0x0C,
	kStreamFormatMidiConf				= 0x0D,
	kStreamFormatSMPTETimeCode			= 0x0E,
	kStreamFormatSampleCount			= 0x0F,
	kStreamFormatAncillaryData			= 0x10,
	kStreamFormatSyncStream				= 0x40,
	kStreamFormatDontCare				= 0xFF
};

typedef unsigned int MusicSubunitInfoBlockTypes;
enum
{
	kGeneralMusicSubunitStatusAreaInfoBlockType	= 0x8100,
	kMusicOutputPlugStatusAreaInfoBlockType		= 0x8101,
	kSourcePlugStatusInfoBlockType				= 0x8102,
	kAudioInfoBlockType							= 0x8103,
	kMIDIInfoBlockType							= 0x8104,
	kSMPTETimeCodeInfoBlockType					= 0x8105,
	kSampleCountInfoBlockType					= 0x8106,
	kAudioSyncInfoBlockType						= 0x8107,
	kRoutingStatusInfoBlockType					= 0x8108,
	kSubunitPlugInfoBlockType					= 0x8109,
	kClusterInfoBlockType						= 0x810A,
	kMusicPlugInfoBlockType						= 0x810B,
	kNameInfoBlockType							= 0x000B,
	kRawTextInfoBlockType						= 0x000A
};	
		

// These are the constants for sample rates in the Music Subunit descriptors
// Note that they are different from what's in the AV/C Stream Format Information data-structures.
typedef unsigned int MusicSubunitSampleRate;
enum
{
	kMusicSubunitSampleRate_32000 = 0x00,
	kMusicSubunitSampleRate_44100 = 0x01,
	kMusicSubunitSampleRate_48000 = 0x02,
	kMusicSubunitSampleRate_88200 = 0x03,
	kMusicSubunitSampleRate_96000 = 0x04,
	kMusicSubunitSampleRate_176400 = 0x05,
	kMusicSubunitSampleRate_192000 = 0x06
};		

typedef unsigned int MusicSubunitPlugUsages;
enum 
{
	kIsochStreamSubunitPlug		= 0x00,
	kAsynchStreamSubunitPlug	= 0x01,
	kMidiSubunitPlug			= 0x02,
	kSyncSubunitPlug			= 0x03,
	kAnalogSubunitPlug			= 0x04,
	kDigitalSubunitPlug			= 0x05
};

typedef unsigned int MusicPortTypes;
enum 
{
	kMusicPortTypeSpeaker 		= 0x00,
	kMusicPortTypeHeadPhone 	= 0x01,
	kMusicPortTypeMicrophone 	= 0x02,
	kMusicPortTypeLine 			= 0x03,
	kMusicPortTypeSpdif 		= 0x04,
	kMusicPortTypeAdat 			= 0x05,
	kMusicPortTypeTdif			= 0x06,
	kMusicPortTypeMadi 			= 0x07,
	kMusicPortTypeAnalog 		= 0x08,
	kMusicPortTypeDigital 		= 0x09,
	kMusicPortTypeMidi 			= 0x0A,
	kMusicPortTypeAesEbu 		= 0x0B,
	kMusicPortTypeNoType 		= 0xFF,
};

typedef unsigned int MusicPlugLocation;
enum 
{
	kMusicPlugLocationLeftFront 		= 0x01,
	kMusicPlugLocationRightFront 		= 0x02,
	kMusicPlugLocationCenterFront		= 0x03,
	kMusicPlugLocationLowFreqEnhance	= 0x04,
	kMusicPlugLocationLeftSurround		= 0x05,
	kMusicPlugLocationRightSurround		= 0x06,
	kMusicPlugLocationLeftOfCenter		= 0x07,
	kMusicPlugLocationRightOfCenter		= 0x08,
	kMusicPlugLocationSurround			= 0x09,
	kMusicPlugLocationSideLeft			= 0x0A,
	kMusicPlugLocationSideRight			= 0x0B,
	kMusicPlugLocationTop				= 0x0C,
	kMusicPlugLocationBottom			= 0x0D,
	kMusicPlugLocationLeftFrontEffect	= 0x0E,
	kMusicPlugLocationRightFrontEffect	= 0x0F,
	kMusicPlugLocationUnknown			= 0xFF
};

typedef unsigned int MusicPlugTypes;
enum 
{
	kMusicPlugTypeAudio 		= 0x00,
	kMusicPlugTypeMidi 			= 0x01, 
	kMusicPlugTypeSmpte 		= 0x02,
	kMusicPlugTypeSampleCount	= 0x03,
	kMusicPlugTypeSync 			= 0x80
};

typedef unsigned int MusicPlugRoutingSupport;
enum 
{
	kMusicPlugRoutingFixed 		= 0x00,
	kMusicPlugRoutingCluster 	= 0x01,
	kMusicPlugRoutingFlexible	= 0x02,
	kMusicPlugRoutingUnknown	= 0xFF
};


class MusicSubunitController;	

class AVCInfoBlock
{
public:
		
	// Constructor that takes raw info-block bytes
	AVCInfoBlock(UInt8 *pInfoBlockBytes, StringLogger *pStringLogger = nil);
		
	// Destructor
	~AVCInfoBlock();

	// Get the compound length of this info block
	UInt16 CompoundLength(void);
		
	// Get the length of the primary fields
	UInt16 PrimaryFieldsLength(void);

	// Get the info block type
	UInt16 InfoBlockType(void);

	// Get the raw bytes of this info block
	// pLength is passed the length of the buffer
	// pLength is returned the actual length copied into the buffer
	// returns false if passed in pLength is too small to hold entire length
	bool GetInfoBlockBytes(UInt8 *pBuffer, UInt16 *pLength);
		
	// Get the primary fields bytes of this info block
	// pLength is passed the length of the buffer
	// pLength is returned the actual length copied into the buffer
	// returns false if passed in pLength is too small to hold the fields length
	bool GetPrimaryFields(UInt8 *pPrimaryFieldsBytes, UInt16 *pLength);
		
	// Get a pointer to a nested info block 
	AVCInfoBlock* GetNestedInfoBlock(UInt16 info_block_type,
									 UInt16 index);
		
	// Useful parse utility for debugging, or analyzing info-blocks
	IOReturn ParseInfoBlock(UInt32 nestingDepth = 0, CFMutableArrayRef array = nil);
		
private:
			
	UInt16 infoBlockType;
	
	UInt8 *pBlockBytes;
		
	UInt16 primaryFieldsLength;
	UInt8 *pPrimaryFields;
		
	std::deque<AVCInfoBlock*> nestedInfoBlockList;
	
	StringLogger *pLogger;
};
	
	
class ExtendedStreamFormatInfo
{

public:	
	
	// Constructor
	ExtendedStreamFormatInfo(StringLogger *pStringLogger = nil);

	// Destructor
	~ExtendedStreamFormatInfo();

	IOReturn InitWithFormatInfo(UInt8 *pFormatInfo, UInt32 formatInfoLen);

	UInt32 len;
	UInt8 *pFormatInfoBytes;
	
	void PrintFormatInformation(CFMutableDictionaryRef dict = nil);

private:
		StringLogger *pLogger;
};
	
class MusicDevicePlug
{

public:

	// Constructor
	MusicDevicePlug();

	// Destructor
	~MusicDevicePlug();
	
	// A pointer to the MusicSubunitController that owns this plug
	MusicSubunitController *pMusicSubunitController;

	// Info about this plug
	UInt8 subUnit;
	UInt8 plugNum;
	bool isDest;	// plug is either a subunit dest plug, or a unit output plug
	
	// For subunit dest plugs (and unit output plugs), a place to record the current source.
	UInt8 sourceSubUnit;
	UInt8 sourcePlugNum;
	UInt8 sourcePlugStatus;

	StringLogger *pLogger;

	IOReturn GetSignalSource(CFMutableDictionaryRef dict = nil); 
	IOReturn GetCurrentStreamFormatInformation(CFMutableDictionaryRef dict = nil);
	IOReturn GetSupportedStreamFormatInformation(CFMutableDictionaryRef dict = nil);
	
	IOReturn SetCurrentStreamFormat(ExtendedStreamFormatInfo *pFormat);

	ExtendedStreamFormatInfo *pCurrentFormat;
	std::deque<ExtendedStreamFormatInfo*> supportedFormats;
};

class MusicSubunitController
{
	friend class MusicDevicePlug;
	
public:
	
	// Constructor
	MusicSubunitController(AVCDevice *pDevice, UInt8 subUnitID = 0x00, StringLogger *pStringLogger = nil);
	
	// Alternate Constructor for use with AVCDeviceCommandInterface
	MusicSubunitController(AVCDeviceCommandInterface *pDeviceCommandInterface, UInt8 subUnitID = 0x00, StringLogger *pStringLogger = nil);
	
	// Destructor
	~MusicSubunitController();
	
	// Discover device configuration
	IOReturn DiscoverConfiguration(void);
	
	// Return a non-mutable copy of the dictionary created during the DiscoverConfiguration() call
	CFDictionaryRef CopyDeviceDiscoveryDictionary(void);
	
	// Send a command to the device to switch stream formats on a plug.
	IOReturn SetPlugStreamFormatWithListIndex(bool isInputPlug, UInt32 plugNum, UInt32 listIndex);

protected:

	// Send and AV/C Command to the device (using either the open device, or activated device-command-interface)
	IOReturn DoAVCCommand(const UInt8 *command, UInt32 cmdLen, UInt8 *response, UInt32 *responseLen);
	
	UInt8 extendedStreamFormatCommandOpcode;

private:
	
	void CleanUpDiscoveryResources(void);	
		
	IOReturn GetMusicSubunitStatusDescriptor(void);
	IOReturn ParseMusicSubunitStatusDescriptor(CFMutableDictionaryRef dict = nil);
		
	AVCDevice *pAVCDevice;
	AVCDeviceCommandInterface *pAVCDeviceCommandInterface;
	UInt8 subunitTypeAndID;

	bool hasMusicSubunit;
	bool hasAudioSubunit;
	
	UInt32 numIsoInPlugs;
	UInt32 numIsoOutPlugs;
	UInt32 numExtInPlugs;
	UInt32 numExtOutPlugs;
	
	UInt32 numMusicSubunitDestPlugs;
	UInt32 numMusicSubunitSourcePlugs;
	
	UInt32 numAudioSubunitDestPlugs;
	UInt32 numAudioSubunitSourcePlugs;
	
	MusicDevicePlug *pIsoInPlugs;
	MusicDevicePlug *pIsoOutPlugs;
	MusicDevicePlug *pExtInPlugs;
	MusicDevicePlug *pExtOutPlugs;
	
	MusicDevicePlug *pMusicSubunitDestPlugs;
	MusicDevicePlug *pMusicSubunitSourcePlugs;

	MusicDevicePlug *pAudioSubunitDestPlugs;
	MusicDevicePlug *pAudioSubunitSourcePlugs;
	
	UInt8 *pMusicSubunitStatusDescriptor;
	std::deque<AVCInfoBlock*> musicSubunitStatusDescriptorInfoBlocks;
	
	CFMutableDictionaryRef deviceConfigurationDictionary; 
	
	IOReturn Initialize(void);

	StringLogger *pLogger;
};

	
} // namespace AVS

#endif /* __AVCVIDEOSERVICES_MUSICSUBUNITCONTROLLER__ */
