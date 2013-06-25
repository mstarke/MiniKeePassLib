//
//  KdbReader.h
//  KeePass2
//
//  Created by Qiang Yu on 3/6/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Kdb.h"
#import "KdbPassword.h"
#import "InputStream.h"

@protocol KdbReader<NSObject>

@required
- (KdbTree*)load:(InputStream*)inputStream withPassword:(KdbPassword*)kdbPassword;

@optional
- (KdbTree *)load:(NSURL *)fileURL withPassword:(KdbPassword *)password error:(NSError **)error;

@end
