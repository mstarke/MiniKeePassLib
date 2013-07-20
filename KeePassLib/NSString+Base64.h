//
//  NSString+Base64.h
//  MacPass
//
//  Created by Michael Starke on 20.07.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Base64)

- (NSString *)base64EncodedString;
- (NSString *)base64DecodedString;

@end
