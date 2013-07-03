//
//  NSMutableData+Base64.m
//  MacPass
//
//  Created by Michael Starke on 25.06.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//
//  Based on the answer
//  http://stackoverflow.com/questions/11386876/how-to-encode-and-decode-files-as-base64-in-cocoa-objective-c
//  by user http://stackoverflow.com/users/200321/denis2342
//

#import "NSMutableData+Base64.h"
#include <Security/Security.h>

static NSData *base64helper(NSData *input, SecTransformRef transform)
{
  NSData *output = nil;
  
  if (!transform)
    return nil;
  
  if (SecTransformSetAttribute(transform, kSecTransformInputAttributeName, (__bridge CFTypeRef)(input), NULL))
    output = (NSData *)CFBridgingRelease(SecTransformExecute(transform, NULL));
  
  CFRelease(transform);
  
  return output;
}

@implementation NSMutableData (Base64)


+ (NSMutableData *)mutableDataWithEncodedData:(NSData *)inputData {
  SecTransformRef transform = SecEncodeTransformCreate(kSecBase64Encoding, NULL);

  return [[NSMutableData alloc] initWithData:base64helper(inputData, transform)];
}

+ (NSMutableData *)mutableDataWithDecodedData:(NSData *)inputData {
  SecTransformRef transform = SecDecodeTransformCreate(kSecBase64Encoding, NULL);
  return [[NSMutableData  alloc] initWithData:base64helper(inputData, transform)];
}

@end
