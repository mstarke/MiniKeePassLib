//
//  DDXMLNode+MKPAdditions.m
//  MiniKeePass
//
//  Created by Jason Rush on 9/15/12.
//  Copyright (c) 2012 Self. All rights reserved.
//

#import "DDXMLElement+MKPAdditions.h"

@implementation DDXMLElement (MKPAdditions)

- (void)removeChild:(DDXMLNode *)child {
  NSUInteger idx = [child index];
  NSAssert(idx >= 0, @"Index needs to be always positive");
  [self removeChildAtIndex:idx];
}

@end
