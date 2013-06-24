//
//  KDB.h
//  KeePass2
//
//  Created by Qiang Yu on 1/1/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DEFAULT_TRANSFORMATION_ROUNDS 6000

@class KdbEntry;

@interface KdbGroup : NSObject {
    KdbGroup *_parent;

    NSInteger _image;
    NSString *_name;
    NSMutableArray *_groups;
    NSMutableArray *_entries;

    NSDate *_creationTime;
    NSDate *_lastModificationTime;
    NSDate *_lastAccessTime;
    NSDate *_expiryTime;

    BOOL _canAddEntries;
}

@property(nonatomic, assign) KdbGroup *parent;

@property(nonatomic, assign) NSInteger image;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, readonly) NSArray *groups;
@property(nonatomic, readonly) NSArray *entries;

@property(nonatomic, retain) NSDate *creationTime;
@property(nonatomic, retain) NSDate *lastModificationTime;
@property(nonatomic, retain) NSDate *lastAccessTime;
@property(nonatomic, retain) NSDate *expiryTime;

@property(nonatomic, assign) BOOL canAddEntries;

- (void)addGroup:(KdbGroup *)group;
- (void)removeGroup:(KdbGroup *)group;
- (void)moveGroup:(KdbGroup *)group toGroup:(KdbGroup *)toGroup;

- (void)addEntry:(KdbEntry *)entry;
- (void)removeEntry:(KdbEntry *)entry;
- (void)moveEntry:(KdbEntry *)entry toGroup:(KdbGroup *)toGroup;

- (BOOL)containsGroup:(KdbGroup*)group;

@end

@interface KdbEntry : NSObject 
@property(nonatomic, assign) KdbGroup *parent;

@property(nonatomic, assign) NSInteger image;

- (NSString *)title;
- (void)setTitle:(NSString *)title;

- (NSString *)username;
- (void)setUsername:(NSString *)username;

- (NSString *)password;
- (void)setPassword:(NSString *)password;

- (NSString *)url;
- (void)setUrl:(NSString *)url;

- (NSString *)notes;
- (void)setNotes:(NSString *)notes;

@property(nonatomic, retain) NSDate *creationTime;
@property(nonatomic, retain) NSDate *lastModificationTime;
@property(nonatomic, retain) NSDate *lastAccessTime;
@property(nonatomic, retain) NSDate *expiryTime;

@end

@interface KdbTree : NSObject

@property(nonatomic, retain) KdbGroup *root;

- (KdbGroup*)createGroup:(KdbGroup*)parent;
- (KdbEntry*)createEntry:(KdbGroup*)parent;

@end
