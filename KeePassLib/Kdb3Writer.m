//
//  Kdb3Persist.m
//  KeePass2
//
//  Created by Qiang Yu on 2/16/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import "Kdb3Writer.h"
#import "Kdb3Utils.h"
#import "KdbPassword.h"
#import "FileOutputStream.h"
#import "AesOutputStream.h"
#import "Sha256OutputStream.h"
#import "DataOutputStream.h"
#import "NSString+Empty.h"
#import "NSData+Random.h"
#import "NSDate+Packed.h"

#define DEFAULT_BIN_SIZE (32*1024)

@interface Kdb3Writer (PrivateMethods)
- (NSUInteger)numOfGroups:(Kdb3Group *)root;
- (NSUInteger)numOfEntries:(Kdb3Group *)root;
- (void)writeHeader:(OutputStream *)outputStream withTree:(Kdb3Tree *)tree;
- (void)writeGroups:(Kdb3Group *)root withOutputStream:(OutputStream *)outputStream;
- (void)writeEntries:(Kdb3Group *)root withOutputStream:(OutputStream *)outputStream;
- (void)writeMetaEntries:(Kdb3Group *)root withOutputStream:(OutputStream *)outputStream;
- (void)writeGroup:(Kdb3Group *)group withOutputStream:(OutputStream *)outputStream;
- (void)writeEntry:(Kdb3Entry *)entry withOutputStream:(OutputStream *)outputStream;
- (void)writeExtData:(OutputStream *)outputStream;
- (void)appendField:(uint16_t)type size:(uint32_t)size bytes:(const void *)buffer withOutputStream:(OutputStream *)outputStream;
@end

@implementation Kdb3Writer

- init {
  self = [super init];
  if (self) {
    masterSeed = [NSData dataWithRandomBytes:16];
    encryptionIv = [NSData dataWithRandomBytes:16];
    transformSeed = [NSData dataWithRandomBytes:32];
    firstGroup = YES;
  }
  return self;
}

/**
 * Get the number of groups in the KDB tree
 */
- (NSUInteger)numOfGroups:(Kdb3Group *)root {
  int num = 0;
  for (Kdb3Group *g in root.groups) {
    num += [self numOfGroups:g];
  }
  return num+1;
}

/**
 * Get the number of entries and meta entries in the KDB tree
 */
- (NSUInteger)numOfEntries:(Kdb3Group *)root {
  NSUInteger num = [root.entries count] + [root.metaEntries count];
  for (Kdb3Group *g in root.groups) {
    num += [self numOfEntries:g];
  }
  return num;
}

/**
 * Persist a tree into a file, using the specified password
 */
- (BOOL)persist:(Kdb3Tree *)tree fileURL:(NSURL *)fileURL withPassword:(KdbPassword *)kdbPassword error:(NSError **)error {
  FileOutputStream *fileOutputStream = [[FileOutputStream alloc] initWithFilename:[fileURL path] flags:(O_WRONLY | O_CREAT | O_TRUNC) mode:0644];
  
  // Write the header
  [self writeHeader:fileOutputStream withTree:tree];
  
  // Create the encryption output stream
  NSData *key = [kdbPassword createFinalKeyForVersion:3 masterSeed:masterSeed transformSeed:transformSeed rounds:tree.rounds];
  AesOutputStream *aesOutputStream = [[AesOutputStream alloc] initWithOutputStream:fileOutputStream key:key iv:encryptionIv];
  
  // Wrap the AES output stream in a SHA256 output stream to calculate the content hash
  Sha256OutputStream *shaOutputStream = [[Sha256OutputStream alloc] initWithOutputStream:aesOutputStream];
  
  @try {
    // Persist the database
    Kdb3Group *root = (Kdb3Group*)tree.root;
    
    // Write the groups
    [self writeGroups:root withOutputStream:shaOutputStream];
    
    // Write the entries
    [self writeEntries:root withOutputStream:shaOutputStream];
    
    // Write the meta entries
    [self writeMetaEntries:root withOutputStream:shaOutputStream];
    
    // Closing the output stream computes the hash and encrypts the last block
    [shaOutputStream close];
    
    // Reopen the file back up and write the content hash
    fileOutputStream = [[FileOutputStream alloc] initWithFilename:[fileURL path] flags:O_WRONLY mode:0644];
    [fileOutputStream seek:56];
    [fileOutputStream write:[shaOutputStream getHash] length:32];
    [fileOutputStream close];
    
    // Turn on file protection
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey: NSFileProtectionComplete}
                                     ofItemAtPath:filename
                                            error:nil];
#endif
  } @finally {
    shaOutputStream = nil;
    aesOutputStream = nil;
    fileOutputStream = nil;
  }
}

/**
 * Write the KDB3 header
 */
- (void)writeHeader:(OutputStream *)outputStream withTree:(Kdb3Tree *)tree {
  Kdb3Group *root = (Kdb3Group*)tree.root;
  
  // Signature, flags, and version
  header.signature1 = CFSwapInt32HostToLittle(KDB3_SIG1);
  header.signature2 = CFSwapInt32HostToLittle(KDB3_SIG2);
  header.flags = CFSwapInt32HostToLittle(FLAG_SHA2 | FLAG_RIJNDAEL);
  header.version = CFSwapInt32HostToLittle(KDB3_VER);
  
  // Master seed and encryption iv
  [masterSeed getBytes:header.masterSeed length:sizeof(header.masterSeed)];
  [encryptionIv getBytes:header.encryptionIv length:sizeof(header.encryptionIv)];
  
  // Number of groups (minus the root)
  header.groups = CFSwapInt32HostToLittle((uint32_t)[self numOfGroups:root] - 1);
  
  // Number of entries
  header.entries = CFSwapInt32HostToLittle((uint32_t)[self numOfEntries:root]);
  
  // Skip the content hash for now, it will get filled in after the content is written
  
  // Master seed #2
  [transformSeed getBytes:header.masterSeed2 length:sizeof(header.masterSeed2)];
  
  // Number of key encryption rounds
  header.keyEncRounds = CFSwapInt32HostToLittle(tree.rounds);
  
  // Write out the header
  [outputStream write:&header length:sizeof(header)];
}

- (void)writeGroups:(Kdb3Group *)root withOutputStream:(OutputStream *)outputStream {
  for (Kdb3Group *group in root.groups) {
    [self writeGroup:group withOutputStream:outputStream];
    [self writeGroups:group withOutputStream:outputStream];
  }
}

- (void)writeEntries:(Kdb3Group *)root withOutputStream:(OutputStream *)outputStream {
  for (Kdb3Entry *entry in root.entries) {
    [self writeEntry:entry withOutputStream:outputStream];
  }
  
  for (Kdb3Group *group in root.groups) {
    [self writeEntries:group withOutputStream:outputStream];
  }
}

- (void)writeMetaEntries:(Kdb3Group *)root withOutputStream:(OutputStream *)outputStream {
  for (Kdb3Entry *entry in root.metaEntries) {
    [self writeEntry:entry withOutputStream:outputStream];
  }
  
  for (Kdb3Group *group in root.groups) {
    [self writeMetaEntries:group withOutputStream:outputStream];
  }
}

- (void)writeGroup:(Kdb3Group *)group withOutputStream:(OutputStream *)outputStream {
  uint8_t packedDate[5];
  uint32_t tmp32;
  
  if (firstGroup) {
    // Write the extra data to a memory buffer
    DataOutputStream *dataOutputStream = [[DataOutputStream alloc] init];
    [self writeExtData:dataOutputStream];
    [dataOutputStream close];
    
    // Write the extra data to a field with id 0
    [self appendField:0 size:(uint32_t)dataOutputStream.data.length bytes:dataOutputStream.data.bytes withOutputStream:outputStream];
    
    firstGroup = NO;
  }
  
  tmp32 = CFSwapInt32HostToLittle(group.groupId);
  [self appendField:1 size:4 bytes:&tmp32 withOutputStream:outputStream];
  
  if (![NSString isEmptyString:group.name]){
    const char * title = [group.name cStringUsingEncoding:NSUTF8StringEncoding];
    [self appendField:2 size:(uint32_t)(strlen(title)+1) bytes:(void *)title withOutputStream:outputStream];
  }
  
  [NSDate getPackedBytes:packedDate fromDate:group.creationTime];
  [self appendField:3 size:5 bytes:packedDate withOutputStream:outputStream];
  
  [NSDate getPackedBytes:packedDate fromDate:group.lastModificationTime];
  [self appendField:4 size:5 bytes:packedDate withOutputStream:outputStream];
  
  [NSDate getPackedBytes:packedDate fromDate:group.lastAccessTime];
  [self appendField:5 size:5 bytes:packedDate withOutputStream:outputStream];
  
  [NSDate getPackedBytes:packedDate fromDate:group.expiryTime];
  [self appendField:6 size:5 bytes:packedDate withOutputStream:outputStream];
  
  tmp32 = CFSwapInt32HostToLittle((uint32_t)group.image);
  [self appendField:7 size:4 bytes:&tmp32 withOutputStream:outputStream];
  
  // Get the level of the group
  uint16_t level = -1;
  for (KdbGroup *g = group; g.parent != nil; g = g.parent) {
    level++;
  }
  
  level = CFSwapInt16HostToLittle(level);
  [self appendField:8 size:2 bytes:&level withOutputStream:outputStream];
  
  tmp32 = CFSwapInt32HostToLittle(group.flags);
  [self appendField:9 size:4 bytes:&tmp32 withOutputStream:outputStream];
  
  // End of the group
  [self appendField:0xFFFF size:0 bytes:nil withOutputStream:outputStream];
}

- (void)writeEntry:(Kdb3Entry *)entry withOutputStream:(OutputStream *)outputStream {
  uint8_t buffer[16];
  uint32_t tmp32;
  const char *tmpStr;
  
  [entry.uuid getBytes:buffer length:16];
  [self appendField:1 size:16 bytes:buffer withOutputStream:outputStream];
  
  tmp32 = CFSwapInt32HostToLittle(((Kdb3Group*)entry.parent).groupId);
  [self appendField:2 size:4 bytes:&tmp32 withOutputStream:outputStream];
  
  tmp32 = CFSwapInt32HostToLittle((uint32_t)entry.image);
  [self appendField:3 size:4 bytes:&tmp32 withOutputStream:outputStream];
  
  tmpStr = "";
  if (![NSString isEmptyString:entry.title]) {
    tmpStr = [entry.title cStringUsingEncoding:NSUTF8StringEncoding];
  }
  [self appendField:4 size:(uint32_t)(strlen(tmpStr) + 1) bytes:tmpStr withOutputStream:outputStream];
  
  tmpStr = "";
  if (![NSString isEmptyString:entry.url]) {
    tmpStr = [entry.url cStringUsingEncoding:NSUTF8StringEncoding];
  }
  [self appendField:5 size:(uint32_t)(strlen(tmpStr) + 1) bytes:tmpStr withOutputStream:outputStream];
  
  tmpStr = "";
  if (![NSString isEmptyString:entry.username]) {
    tmpStr = [entry.username cStringUsingEncoding:NSUTF8StringEncoding];
  }
  [self appendField:6 size:(uint32_t)(strlen(tmpStr) + 1) bytes:tmpStr withOutputStream:outputStream];
  
  tmpStr = "";
  if (![NSString isEmptyString:entry.password]) {
    tmpStr = [entry.password cStringUsingEncoding:NSUTF8StringEncoding];
  }
  [self appendField:7 size:(uint32_t)(strlen(tmpStr) + 1) bytes:tmpStr withOutputStream:outputStream];
  
  tmpStr = "";
  if (![NSString isEmptyString:entry.notes]) {
    tmpStr = [entry.notes cStringUsingEncoding:NSUTF8StringEncoding];
  }
  [self appendField:8 size:(uint32_t)(strlen(tmpStr) + 1) bytes:tmpStr withOutputStream:outputStream];
  
  [NSDate getPackedBytes:buffer fromDate:entry.creationTime];
  [self appendField:9 size:5 bytes:buffer withOutputStream:outputStream];
  
  [NSDate getPackedBytes:buffer fromDate:entry.lastModificationTime];
  [self appendField:10 size:5 bytes:buffer withOutputStream:outputStream];
  
  [NSDate getPackedBytes:buffer fromDate:entry.lastAccessTime];
  [self appendField:11 size:5 bytes:buffer withOutputStream:outputStream];
  
  [NSDate getPackedBytes:buffer fromDate:entry.expiryTime];
  [self appendField:12 size:5 bytes:buffer withOutputStream:outputStream];
  
  tmpStr = "";
  if (![NSString isEmptyString:entry.binaryDesc]) {
    tmpStr = [entry.binaryDesc cStringUsingEncoding:NSUTF8StringEncoding];
  }
  [self appendField:13 size:(uint32_t)(strlen(tmpStr) + 1) bytes:tmpStr withOutputStream:outputStream];
  
  if (entry.binary && entry.binary.length) {
    [self appendField:14 size:(uint32_t)entry.binary.length bytes:entry.binary.bytes withOutputStream:outputStream];
  } else {
    [self appendField:14 size:0 bytes:nil withOutputStream:outputStream];
  }
  
  [self appendField:0xFFFF size:0 bytes:nil withOutputStream:outputStream];
}

- (void)writeExtData:(OutputStream *)outputStream {
  // Compute a sha256 hash of the header up to but not including the contentsHash
  NSData *headerHash = [Kdb3Utils hashHeader:&header];
  [self appendField:1 size:32 bytes:headerHash.bytes withOutputStream:outputStream];
  
  // Generate some random data to prevent guessing attacks that use the content hash
  NSData *randomData = [NSData dataWithRandomBytes:32];
  [self appendField:2 size:32 bytes:randomData.bytes withOutputStream:outputStream];
  
  [self appendField:0xFFFF size:0 bytes:nil withOutputStream:outputStream];
}

- (void)appendField:(uint16_t)type size:(uint32_t)size bytes:(const void *)buffer withOutputStream:(OutputStream *)outputStream {
  [outputStream writeInt16:CFSwapInt16HostToLittle(type)];
  [outputStream writeInt32:CFSwapInt32HostToLittle(size)];
  if (size > 0) {
    [outputStream write:buffer length:size];
  }
}

- (BOOL)newFile:(NSURL *)fileURL withPassword:(KdbPassword *)kdbPassword error:(NSError **)error {
  Kdb3Tree *tree = [[Kdb3Tree alloc] init];
  
  Kdb3Group *rootGroup = [[Kdb3Group alloc] init];
  rootGroup.name = @"%ROOT%";
  tree.root = rootGroup;
  
  KdbGroup *parentGroup = [tree createGroup:rootGroup];
  parentGroup.name = @"General";
  parentGroup.image = 48;
  [rootGroup addGroup:parentGroup];
  
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
  
  return ok;
}

@end
