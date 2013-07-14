//
//  NSUUID+KeePassLib.m
//  MacPass
//
//  Created by Michael Starke on 25.06.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//

#import "NSUUID+KeePassLib.h"

static NSUUID *aesUUID = nil;

@implementation NSUUID (KeePassLib)

- (NSData *)getUUIDData {
  uint8_t *bytes = NULL;
  [self getUUIDBytes:bytes];
  
  return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

+ (NSUUID *)nullUUID {
  return [[NSUUID alloc] initWithUUIDString:@"00000000000000000000000000000000"];
}

+ (NSUUID *)AESUUID {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    aesUUID = [[NSUUID alloc] initWithUUIDString:@"31C1F2E6BF714350BE5805216AFC5AFF"];
  });
  return aesUUID;
}

@end
