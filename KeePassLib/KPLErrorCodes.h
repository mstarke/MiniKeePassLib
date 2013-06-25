//
//  KPLErrorCodes.h
//  MacPass
//
//  Created by Michael Starke on 25.06.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//

#ifndef MacPass_KPLErrorCodes_h
#define MacPass_KPLErrorCodes_h

FOUNDATION_EXPORT NSString *const KPLErrorDomain;

typedef NS_ENUM( NSUInteger, KPLErrorCode ) {
  KPLErrorUnknownFileFormat = -1000,
  KPLErrorFileCorrupted,
  KPLErrorWriteFailed,
  KPLErrorParsingFailed
};

#endif
