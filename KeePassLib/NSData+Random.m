//
//  NSData+Random.m
//  MacPass
//
//  Created by Michael Starke on 24.06.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//

#import "NSData+Random.h"
#import <Security/SecRandom.h>

@implementation NSData (Random)

+ (NSData *)dataWithRandomBytes:(uint32_t)length {
  unsigned char *bytes = malloc(sizeof(unsigned char) * length);
  SecRandomCopyBytes(kSecRandomDefault, length, bytes);
  return [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:YES];
}

@end
