//
//  Password.m
//  KeePass2
//
//  Created by Qiang Yu on 1/5/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

#import "KdbPassword.h"
#import "DDXML.h"
#import "DDXMLElementAdditions.h"
#import "NSMutableData+Base64.h"

@interface KdbPassword ()

@property (copy) NSURL *keyFileURL;
@property (copy) NSString *password;
@property (assign) NSStringEncoding passwordEncoding;

- (void)createMasterKeyV3:(uint8_t *)masterKey;
- (void)createMasterKeyV4:(uint8_t *)masterKey;

- (NSData*)loadKeyFileV3:(NSURL *)fileURL;
- (NSData*)loadKeyFileV4:(NSURL *)fileURL;

- (NSData*)loadXmlKeyFile:(NSURL *)fileURL;
@end

int hex2dec(char c);

@implementation KdbPassword

- (id)initWithPassword:(NSString*)inPassword
      passwordEncoding:(NSStringEncoding)inPasswordEncoding
            keyFileURL:(NSURL *)inKeyFile {
  self = [super init];
  if (self) {
    _password = [inPassword copy];
    _passwordEncoding = inPasswordEncoding;
    _keyFileURL = [inKeyFile copy];
  }
  return self;
}

- (void)dealloc {
  [_password release];
  [_keyFileURL release];
  [super dealloc];
}

- (NSData*)createFinalKeyForVersion:(uint8_t)version
                         masterSeed:(NSData*)masterSeed
                      transformSeed:(NSData*)transformSeed
                             rounds:(uint64_t)rounds {
  // Generate the master key from the credentials
  uint8_t masterKey[32];
  if (version == 3) {
    [self createMasterKeyV3:masterKey];
  } else {
    [self createMasterKeyV4:masterKey];
  }
  
  // Transform the key
  CCCryptorRef cryptorRef;
  CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128, kCCOptionECBMode, transformSeed.bytes, kCCKeySizeAES256, nil, &cryptorRef);
  
  size_t tmp;
  for (int i = 0; i < rounds; i++) {
    CCCryptorUpdate(cryptorRef, masterKey, 32, masterKey, 32, &tmp);
  }
  
  CCCryptorRelease(cryptorRef);
  
  uint8_t transformedKey[32];
  CC_SHA256(masterKey, 32, transformedKey);
  
  // Hash the master seed with the transformed key into the final key
  uint8_t finalKey[32];
  CC_SHA256_CTX ctx;
  CC_SHA256_Init(&ctx);
  CC_SHA256_Update(&ctx, masterSeed.bytes, (CC_LONG)masterSeed.length);
  CC_SHA256_Update(&ctx, transformedKey, 32);
  CC_SHA256_Final(finalKey, &ctx);
  
  return [NSData dataWithBytes:finalKey length:32];
}

- (void)createMasterKeyV3:(uint8_t *)masterKey {
  if (_password != nil && _keyFileURL == nil) {
    // Hash the password into the master key
    NSData *passwordData = [_password dataUsingEncoding:_passwordEncoding];
    CC_SHA256(passwordData.bytes, (CC_LONG)passwordData.length, masterKey);
  } else if (_password == nil && _keyFileURL != nil) {
    // Get the bytes from the keyfile
    NSData *keyFileData = [self loadKeyFileV3:_keyFileURL];
    if (keyFileData == nil) {
      @throw [NSException exceptionWithName:@"IOException" reason:@"Failed to load keyfile" userInfo:nil];
    }
    
    [keyFileData getBytes:masterKey length:32];
  } else {
    // Hash the password
    uint8_t passwordHash[32];
    NSData *passwordData = [_password dataUsingEncoding:_passwordEncoding];
    CC_SHA256(passwordData.bytes, (CC_LONG)passwordData.length, passwordHash);
    
    // Get the bytes from the keyfile
    NSData *keyFileData = [self loadKeyFileV3:_keyFileURL];
    if (keyFileData == nil) {
      @throw [NSException exceptionWithName:@"IOException" reason:@"Failed to load keyfile" userInfo:nil];
    }
    
    // Hash the password and keyfile into the master key
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    CC_SHA256_Update(&ctx, passwordHash, 32);
    CC_SHA256_Update(&ctx, keyFileData.bytes, 32);
    CC_SHA256_Final(masterKey, &ctx);
  }
}

- (void)createMasterKeyV4:(uint8_t *)masterKey {
  // Initialize the master hash
  CC_SHA256_CTX ctx;
  CC_SHA256_Init(&ctx);
  
  // Add the password to the master key if it was supplied
  if (_password != nil) {
    // Get the bytes from the password using the supplied encoding
    NSData *passwordData = [_password dataUsingEncoding:_passwordEncoding];
    
    // Hash the password
    uint8_t hash[32];
    CC_SHA256(passwordData.bytes, (CC_LONG)passwordData.length, hash);
    
    // Add the password hash to the master hash
    CC_SHA256_Update(&ctx, hash, 32);
  }
  
  // Add the keyfile to the master key if it was supplied
  if (_keyFileURL != nil) {
    // Get the bytes from the keyfile
    NSData *keyFileData = [self loadKeyFileV4:_keyFileURL];
    if (keyFileData == nil) {
      @throw [NSException exceptionWithName:@"IOException" reason:@"Failed to load keyfile" userInfo:nil];
    }
    
    // Add the keyfile hash to the master hash
    CC_SHA256_Update(&ctx, keyFileData.bytes, (CC_LONG)keyFileData.length);
  }
  
  // Finish the hash into the master key
  CC_SHA256_Final(masterKey, &ctx);
}

- (NSData*)loadKeyFileV3:(NSURL *)fileURL {
  // Open the keyfile
  NSError *error = nil;
  NSData *fileData = [NSData dataWithContentsOfURL:fileURL
                                           options:(NSDataReadingUncached|NSDataReadingMappedIfSafe)
                                             error:&error];
  if(error) {
    NSLog(@"%@", [error localizedDescription]);
    return nil;
  }
  
  if(!fileData) {
    return nil;
  }
  if([fileData length] == 32) {
    return fileData; // Loading of a 32 bit binary file succeded;
  }
  NSData *decordedData = nil;
  if ([fileData length] == 64) {
    error = nil;
    NSString *hexstring = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    if(!error && hexstring != nil) {
      decordedData = [self keyDataWithHexString:hexstring];
    }
    [hexstring release];
  }
  if(!decordedData) {
    // The hex encoded file failed to load, so try and hash the file
    decordedData = [self keyDataFromHash:fileData];
  }
  return decordedData;
}

- (NSData *)loadKeyFileV4:(NSURL *)fileURL {
  // Try and load a 2.x XML keyfile first
  @try {
    return [self loadXmlKeyFile:fileURL];
  } @catch (NSException *e) {
    // Ignore the exception and try and load the file through a different mechanism    NSData *data = nil;
  }
  
  return [self loadKeyFileV3:fileURL];
}

- (NSData *)loadXmlKeyFile:(NSURL *)fileURL {
  NSString *xmlString = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:nil];
  if (xmlString == nil) {
    @throw [NSException exceptionWithName:@"IOException" reason:@"Failed to open keyfile" userInfo:nil];
  }
  
  DDXMLDocument *document = [[DDXMLDocument alloc] initWithXMLString:xmlString options:0 error:nil];
  if (document == nil) {
    @throw [NSException exceptionWithName:@"ParseError" reason:@"Failed to parse keyfile" userInfo:nil];
  }
  
  // Get the root document element
  DDXMLElement *rootElement = [document rootElement];
  
  DDXMLElement *keyElement = [rootElement elementForName:@"Key"];
  if (keyElement == nil) {
    [document release];
    @throw [NSException exceptionWithName:@"ParseError" reason:@"Failed to parse keyfile" userInfo:nil];
  }
  
  DDXMLElement *dataElement = [keyElement elementForName:@"Data"];
  if (dataElement == nil) {
    [document release];
    @throw [NSException exceptionWithName:@"ParseError" reason:@"Failed to parse keyfile" userInfo:nil];
  }
  
  NSString *dataString = [dataElement stringValue];
  if (dataString == nil) {
    [document release];
    @throw [NSException exceptionWithName:@"ParseError" reason:@"Failed to parse keyfile" userInfo:nil];
  }
  
  [document release];
  
  return [NSMutableData mutableDataWithDecodedData:[dataString dataUsingEncoding:NSASCIIStringEncoding]];
}

- (NSData *)keyDataWithHexString:(NSString *)hexString {
  uint8_t buffer[32];
  
  if(hexString == nil) {
    return nil;
  }
  if([hexString length] != 64) {
    return nil; // No valid lenght found
  }
  BOOL scanOk = YES;
  @autoreleasepool {
    for(NSUInteger iIndex = 0; iIndex < 32; iIndex++) {
      NSString *split = [hexString substringWithRange:NSMakeRange(iIndex * 2, 2)];
      NSScanner * scanner = [NSScanner scannerWithString:split];
      uint32_t integer = 0;
      if(![scanner scanHexInt:&integer]) {
        scanOk = NO;
        break;
      }
      buffer[iIndex] = (uint8_t)integer;
    }
  }
  if(!scanOk) {
    return nil; // Hex scanning failed
  }
  return [NSData dataWithBytes:buffer length:32];
}

- (NSData *)keyDataFromHash:(NSData *)fileData {
  uint8_t buffer[32];
  NSData *chunk;
  
  CC_SHA256_CTX ctx;
  CC_SHA256_Init(&ctx);
  @autoreleasepool {
    const NSUInteger chunkSize = 2048;
    for(NSUInteger iIndex = 0; iIndex < [fileData length]; iIndex += chunkSize) {
      NSUInteger maxChunkLenght = MIN(fileData.length - iIndex, chunkSize);
      chunk = [fileData subdataWithRange:NSMakeRange(iIndex, maxChunkLenght)];
      CC_SHA256_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
    }
  }
  CC_SHA256_Final(buffer, &ctx);
  
  return [NSData dataWithBytes:buffer length:32];
}

@end
