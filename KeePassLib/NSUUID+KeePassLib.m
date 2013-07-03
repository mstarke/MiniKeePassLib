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

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if(! [object isKindOfClass:[NSUUID class]]) {
    return NO;
  }
  return [[self getUUIDData] isEqualToData:[object getUUIDData]];
}

+ (NSUUID *)nullUUID {
  uint8_t bytes[16] = {0};
  return [[NSUUID alloc] initWithUUIDBytes:bytes];
}

+ (NSUUID *)AESUUID {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      uint8_t bytes[16];
      bytes[0]=0x31; bytes[1]=0xC1;
      bytes[2]=0xF2; bytes[3]=0xE6;
      bytes[4]=0xBF; bytes[5]=0x71;
      bytes[6]=0x43; bytes[7]=0x50;
      bytes[8]=0xBE; bytes[9]=0x58;
      bytes[10]=0x05; bytes[11]=0x21;
      bytes[12]=0x6A; bytes[13]=0xFC;
      bytes[14]=0x5A; bytes[15]=0xFF;

      aesUUID = [[NSUUID alloc] initWithUUIDBytes:bytes];
  });
  return aesUUID;
}

@end
