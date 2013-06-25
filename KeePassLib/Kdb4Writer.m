/*
 * Copyright 2011-2012 Jason Rush and John Flanagan. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "Kdb4Writer.h"
#import "Kdb4Node.h"
#import "Kdb4Persist.h"
#import "KdbPassword.h"
#import "DataOutputStream.h"
#import "AesOutputStream.h"
#import "HashedOutputStream.h"
#import "GZipOutputStream.h"
#import "Salsa20RandomStream.h"
#import "UUID.h"
#import "NSData+Random.h"

#define DEFAULT_BIN_SIZE (32*1024)

@interface Kdb4Writer (PrivateMethods)
- (void)writeHeaderField:(OutputStream*)outputStream headerId:(uint8_t)headerId data:(const void*)data length:(uint16_t)length;
- (void)writeHeader:(OutputStream*)outputStream withTree:(Kdb4Tree*)tree;
@end

@implementation Kdb4Writer

- init {
  self = [super init];
  if (self) {
    masterSeed = [[NSData dataWithRandomBytes:32] retain];
    transformSeed = [[NSData dataWithRandomBytes:32] retain];
    encryptionIv = [[NSData dataWithRandomBytes:16] retain];
    protectedStreamKey = [[NSData dataWithRandomBytes:32] retain];
    streamStartBytes = [[NSData dataWithRandomBytes:32] retain];
  }
  return self;
}

- (void)dealloc {
  [masterSeed release];
  [transformSeed release];
  [encryptionIv release];
  [protectedStreamKey release];
  [streamStartBytes release];
  [super dealloc];
}

- (BOOL)persist:(Kdb4Tree *)tree fileURL:(NSURL *)fileURL withPassword:(KdbPassword *)kdbPassword error:(NSError **)error {
  // Configure the output stream
  DataOutputStream *outputStream = [[[DataOutputStream alloc] init] autorelease];
  
  // Write the header
  [self writeHeader:outputStream withTree:tree];
  
  // Create the encryption output stream
  NSData *key = [kdbPassword createFinalKeyForVersion:4 masterSeed:masterSeed transformSeed:transformSeed rounds:tree.rounds];
  AesOutputStream *aesOutputStream = [[[AesOutputStream alloc] initWithOutputStream:outputStream key:key iv:encryptionIv] autorelease];
  
  // Write the stream start bytes
  [aesOutputStream write:streamStartBytes];
  
  // Create the hashed output stream
  OutputStream *stream = [[[HashedOutputStream alloc] initWithOutputStream:aesOutputStream blockSize:1024*1024] autorelease];
  
  // Create the gzip output stream
  if (tree.compressionAlgorithm == COMPRESSION_GZIP) {
    stream = [[[GZipOutputStream alloc] initWithOutputStream:stream] autorelease];
  }
  
  // Create the random stream
  RandomStream *randomStream = [[[Salsa20RandomStream alloc] init:protectedStreamKey] autorelease];
  
  // Serialize the XML
  Kdb4Persist *persist = [[[Kdb4Persist alloc] initWithTree:tree outputStream:stream randomStream:randomStream] autorelease];
  [persist persist];
  
  // Close the output stream
  [stream close];
  
  // Write to the file
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
  if(![outputStream.data writeToURL:fileURL options:NSDataWritingFileProtectionComplete error:error]) {
    return NO;
  }
#endif
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
  if(![outputStream.data writeToURL:fileURL options:0 error:error]) {
    return NO;
  }
  return YES;
  
#endif
}

- (void)writeHeaderField:(OutputStream*)outputStream headerId:(uint8_t)headerId data:(const void*)data length:(uint16_t)length {
  [outputStream writeInt8:headerId];
  
  [outputStream writeInt16:CFSwapInt16HostToLittle(length)];
  
  if (length > 0) {
    [outputStream write:data length:length];
  }
}

- (void)writeHeader:(OutputStream*)outputStream withTree:(Kdb4Tree*)tree {
  uint8_t buffer[16];
  uint32_t i32;
  uint64_t i64;
  
  // Signature and version
  [outputStream writeInt32:CFSwapInt32HostToLittle(KDB4_SIG1)];
  [outputStream writeInt32:CFSwapInt32HostToLittle(KDB4_SIG2)];
  [outputStream writeInt32:CFSwapInt32HostToLittle(KDB4_VERSION)];
  
  UUID *cipherUuid = [UUID getAESUUID];
  [cipherUuid getBytes:buffer length:16];
  [self writeHeaderField:outputStream headerId:HEADER_CIPHERID data:buffer length:16];
  
  i32 = CFSwapInt32HostToLittle(tree.compressionAlgorithm);
  [self writeHeaderField:outputStream headerId:HEADER_COMPRESSION data:&i32 length:4];
  
  [self writeHeaderField:outputStream headerId:HEADER_MASTERSEED data:masterSeed.bytes length:masterSeed.length];
  
  [self writeHeaderField:outputStream headerId:HEADER_TRANSFORMSEED data:transformSeed.bytes length:transformSeed.length];
  
  i64 = CFSwapInt64HostToLittle(tree.rounds);
  [self writeHeaderField:outputStream headerId:HEADER_TRANSFORMROUNDS data:&i64 length:8];
  
  [self writeHeaderField:outputStream headerId:HEADER_ENCRYPTIONIV data:encryptionIv.bytes length:encryptionIv.length];
  
  [self writeHeaderField:outputStream headerId:HEADER_PROTECTEDKEY data:protectedStreamKey.bytes length:protectedStreamKey.length];
  
  [self writeHeaderField:outputStream headerId:HEADER_STARTBYTES data:streamStartBytes.bytes length:streamStartBytes.length];
  
  i32 = CFSwapInt32HostToLittle(CSR_SALSA20);
  [self writeHeaderField:outputStream headerId:HEADER_RANDOMSTREAMID data:&i32 length:4];
  
  buffer[0] = '\r';
  buffer[1] = '\n';
  buffer[2] = '\r';
  buffer[3] = '\n';
  [self writeHeaderField:outputStream headerId:HEADER_EOH data:buffer length:4];
}

- (BOOL)newFile:(NSURL *)fileURL withPassword:(KdbPassword *)kdbPassword error:(NSError **)error {

  NSDate *currentTime = [NSDate date];
  
  Kdb4Tree *tree = [[Kdb4Tree alloc] init];
  tree.generator = @"MiniKeePass";
  tree.databaseName = @"";
  tree.databaseNameChanged = currentTime;
  tree.databaseDescription = @"";
  tree.databaseDescriptionChanged = currentTime;
  tree.defaultUserName = @"";
  tree.defaultUserNameChanged = currentTime;
  tree.maintenanceHistoryDays = 365;
  tree.color = @"";
  tree.masterKeyChanged = currentTime;
  tree.masterKeyChangeRec = -1;
  tree.masterKeyChangeForce = -1;
  tree.protectTitle = NO;
  tree.protectUserName = NO;
  tree.protectPassword = YES;
  tree.protectUrl = NO;
  tree.protectNotes = NO;
  tree.recycleBinEnabled = YES;
  tree.recycleBinUuid = [UUID nullUuid];
  tree.recycleBinChanged = currentTime;
  tree.entryTemplatesGroup = [UUID nullUuid];
  tree.entryTemplatesGroupChanged = currentTime;
  tree.historyMaxItems = 10;
  tree.historyMaxSize = 6 * 1024 * 1024; // 6 MB
  tree.lastSelectedGroup = [UUID nullUuid];
  tree.lastTopVisibleGroup = [UUID nullUuid];
  
  KdbGroup *parentGroup = [tree createGroup:nil];
  parentGroup.name = @"General";
  parentGroup.image = 48;
  tree.root = parentGroup;
  
  KdbGroup *group = [tree createGroup:parentGroup];
  group.name = @"Windows";
  group.image = 38;
  [parentGroup addGroup:group];
  
  group = [tree createGroup:parentGroup];
  group.name = @"Network";
  group.image = 3;
  [parentGroup addGroup:group];
  
  group = [tree createGroup:parentGroup];
  group.name = @"Internet";
  group.image = 1;
  [parentGroup addGroup:group];
  
  group = [tree createGroup:parentGroup];
  group.name = @"eMail";
  group.image = 19;
  [parentGroup addGroup:group];
  
  group = [tree createGroup:parentGroup];
  group.name = @"Homebanking";
  group.image = 37;
  [parentGroup addGroup:group];
  
  BOOL ok = [self persist:tree fileURL:fileURL withPassword:kdbPassword error:error];
  
  [tree release];
  return ok;
}

@end
