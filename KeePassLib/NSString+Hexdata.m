//
//  NSString+Hexdata.m
//  MacPass
//
//  Created by Michael Starke on 14.07.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//
//  Based on http://stackoverflow.com/questions/2501033/nsstring-hex-to-bytes
//  by http://stackoverflow.com/users/136819/zyphrax
//
#import "NSString+Hexdata.h"

@implementation NSString (Hexdata)

- (NSData *)dataFromHexString {
  NSCharacterSet *hexCharactes = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet];
  BOOL isValid = (NSNotFound == [self rangeOfCharacterFromSet:hexCharactes].location);
  if(!isValid) {
    return nil;
  }
  const char *chars = [self UTF8String];
  NSUInteger index = 0;
  NSUInteger length = self.length;
  
  NSMutableData *data = [NSMutableData dataWithCapacity:length / 2];
  char byteChars[3] = {'\0','\0','\0'};
  NSUInteger wholeByte;
  
  while (index < length) {
    byteChars[0] = chars[index++];
    byteChars[1] = chars[index++];
    
    wholeByte = strtoul(byteChars, NULL, 16);
    [data appendBytes:&wholeByte length:1];
  }
  
  return data;
}

@end
