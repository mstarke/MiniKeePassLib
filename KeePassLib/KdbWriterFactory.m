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

#import "KdbWriterFactory.h"
#import "Kdb3Writer.h"
#import "Kdb4Writer.h"
#import "KPLErrorCodes.h"

@implementation KdbWriterFactory

+ (BOOL)persist:(KdbTree *)tree fileURL:(NSURL *)fileURL withPassword:(KdbPassword *)kdbPassword error:(NSError **)error {
  id<KdbWriter> writer;
  
  if([tree isKindOfClass:[Kdb3Tree class]]) {
    writer = [[Kdb3Writer alloc] init];
  }
  else if([tree isKindOfClass:[Kdb4Tree class]]) {
    writer = [[Kdb4Writer alloc] init];
  }
  else {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedStringFromTable( @"ERROR_TREE_CLASS_NOT_RECOGNIZED", @"Errors", @"Database is of unknown type" ) };
    *error = [NSError errorWithDomain:NSCocoaErrorDomain code:KPLErrorUnknownFileFormat userInfo:userInfo];
    return NO;
  }
  @try {
    [writer persist:tree fileURL:fileURL withPassword:kdbPassword error:error];
  }
  @catch (NSException *exception) {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"ERROR_PERSIST_FAILED", @"Errors", @"Failed to write the database") };
    *error = [NSError errorWithDomain:0 code:KPLErrorWriteFailed userInfo:userInfo];
  }
  @finally {
    [writer release];
    return (error != nil);
  }
}

@end
