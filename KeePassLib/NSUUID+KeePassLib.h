//
//  NSUUID+KeePassLib.h
//  MacPass
//
//  Created by Michael Starke on 25.06.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSUUID (KeePassLib)

+(NSUUID *)nullUUID;
+(NSUUID *)AESUUID;

@end
