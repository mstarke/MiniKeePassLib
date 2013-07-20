//
//  NSString+Base64.m
//  MacPass
//
//  Created by Michael Starke on 20.07.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//

#import "NSString+Base64.h"
#import "NSMutableData+Base64.h"

@implementation NSString (Base64)

- (NSString *)base64EncodedString {
  NSMutableData *data = [[self dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
  [data encodeBase64];
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}


- (NSString *)base64DecodedString {
  NSMutableData *data = [[self dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
  [data decodeBase64];
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
@end
