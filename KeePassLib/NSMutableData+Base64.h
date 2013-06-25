//
//  NSMutableData+Base64.h
//  MacPass
//
//  Created by Michael Starke on 25.06.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//
//  Based on the answer
//  http://stackoverflow.com/questions/11386876/how-to-encode-and-decode-files-as-base64-in-cocoa-objective-c
//  by user http://stackoverflow.com/users/200321/denis2342
//

#import <Foundation/Foundation.h>

@interface NSMutableData (Base64)

+ (NSMutableData*)mutableDataWithEncodedData:(NSData*)inputData;
+ (NSMutableData*)mutableDataWithDecodedData:(NSData*)inputData;

@end
