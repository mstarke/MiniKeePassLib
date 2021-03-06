/*
 * Copyright 2011-2012 Jason Rush and John Flanagan. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "DataInputStream.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation DataInputStream

- (id)initWithData:(NSData*)d {
    self = [super init];
    if (self) {
        data = d;
        dataOffset = 0;
    }
    return self;
}

- (NSUInteger)read:(void*)bytes length:(NSUInteger)bytesLength {
    NSRange range;
    range.location = dataOffset;
    range.length = MIN([data length] - dataOffset, bytesLength);
    
    [data getBytes:bytes range:range];
    
    dataOffset += range.length;
    
    return range.length;
}

@end
