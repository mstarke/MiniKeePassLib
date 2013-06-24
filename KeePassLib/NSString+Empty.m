//
//  NSString+Empty.m
//  MacPass
//
//  Created by Michael Starke on 24.06.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//

#import "NSString+Empty.h"

@implementation NSString (Empty)

- (BOOL)isEmpty {
  if(!self) {
    return YES;
  }
  return ([self length] == 0);
}

@end
