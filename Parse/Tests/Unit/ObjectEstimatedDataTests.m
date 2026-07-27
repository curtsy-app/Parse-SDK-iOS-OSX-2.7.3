/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFFieldOperation.h"
#import "PFObjectEstimatedData.h"
#import "PFOperationSet.h"
#import "PFTestCase.h"

@interface PFEnumerationTrackingDictionary : NSDictionary

@property (nonatomic, strong) NSDictionary *backingDictionary;
@property (nonatomic, assign) BOOL enumerationCalled;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end

@implementation PFEnumerationTrackingDictionary

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (!self) return nil;

    _backingDictionary = dictionary;

    return self;
}

- (NSUInteger)count {
    return self.backingDictionary.count;
}

- (NSEnumerator *)keyEnumerator {
    return self.backingDictionary.keyEnumerator;
}

- (id)objectForKey:(id)key {
    return self.backingDictionary[key];
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block {
    self.enumerationCalled = YES;
    [self.backingDictionary enumerateKeysAndObjectsUsingBlock:block];
}

@end

@interface ObjectEstimatedDataTests : PFTestCase

@end

@implementation ObjectEstimatedDataTests

- (void)testConstructors {
    PFObjectEstimatedData *data = [[PFObjectEstimatedData alloc] init];
    XCTAssertNotNil(data);
    XCTAssertNotNil([data allKeys]);
    XCTAssertEqualObjects([data allKeys], @[]);

    data = [[PFObjectEstimatedData alloc] initWithServerData:nil operationSetQueue:nil];
    XCTAssertNotNil(data);
    XCTAssertNotNil([data allKeys]);
    XCTAssertEqualObjects([data allKeys], @[]);

    data = [[PFObjectEstimatedData alloc] initWithServerData:@{ @"a" : @"b" } operationSetQueue:nil];
    XCTAssertNotNil(data);
    XCTAssertNotNil([data allKeys]);
    XCTAssertEqualObjects([data allKeys], @[ @"a" ]);
    XCTAssertEqualObjects(data[@"a"], @"b");

    data = [PFObjectEstimatedData estimatedDataFromServerData:@{ @"a" : @"b" } operationSetQueue:nil];
    XCTAssertNotNil(data);
    XCTAssertNotNil([data allKeys]);
    XCTAssertEqualObjects([data allKeys], @[ @"a" ]);
    XCTAssertEqualObjects(data[@"a"], @"b");

    PFOperationSet *operationSet = [[PFOperationSet alloc] init];
    operationSet[@"c"] = [PFSetOperation setWithValue:@"d"];

    data = [PFObjectEstimatedData estimatedDataFromServerData:@{ @"a" : @"b" }
                                            operationSetQueue:@[ operationSet ]];
    XCTAssertNotNil(data);
    XCTAssertNotNil([data allKeys]);
    XCTAssertEqualObjects([data allKeys], (@[ @"a", @"c" ]));
    XCTAssertEqualObjects(data[@"a"], @"b");
    XCTAssertEqualObjects(data[@"c"], @"d");
}

- (void)testObjectForKey {
    PFObjectEstimatedData *data = [PFObjectEstimatedData estimatedDataFromServerData:@{ @"a" : @"b" }
                                                                   operationSetQueue:nil];
    XCTAssertEqualObjects([data objectForKey:@"a"], @"b");
    XCTAssertEqualObjects(data[@"a"], @"b");
}

- (void)testEnumeration {
    PFOperationSet *operationSet = [[PFOperationSet alloc] init];
    operationSet[@"c"] = [PFSetOperation setWithValue:@"d"];
    PFObjectEstimatedData *data = [PFObjectEstimatedData estimatedDataFromServerData:@{ @"a" : @"b" }
                                                                   operationSetQueue:@[ operationSet ]];

    __block NSUInteger counter = 0;
    [data enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (counter == 0) {
            XCTAssertEqualObjects(key, @"a");
            XCTAssertEqualObjects(obj, @"b");
        } else if (counter == 1) {
            XCTAssertEqualObjects(key, @"c");
            XCTAssertEqualObjects(obj, @"d");
        } else {
            XCTFail();
        }
        counter++;
    }];
}

- (void)testAllKeys {
    PFObjectEstimatedData *data = [PFObjectEstimatedData estimatedDataFromServerData:@{ @"a" : @"b" }
                                                                   operationSetQueue:nil];
    XCTAssertEqualObjects([data allKeys], @[ @"a" ]);
}

- (void)testDictionaryRepresentation {
    PFOperationSet *operationSet = [[PFOperationSet alloc] init];
    operationSet[@"c"] = [PFSetOperation setWithValue:@"d"];
    PFObjectEstimatedData *data = [PFObjectEstimatedData estimatedDataFromServerData:@{ @"a" : @"b" }
                                                                   operationSetQueue:@[ operationSet ]];
    NSDictionary *dictionary = data.dictionaryRepresentation;
    XCTAssertEqualObjects(dictionary, (@{ @"a" : @"b", @"c" : @"d" }));
    XCTAssertNotEqual(dictionary, data.dictionaryRepresentation);
}

- (void)testDictionaryRepresentationDoesNotShareMutableStorage {
    PFObjectEstimatedData *data = [PFObjectEstimatedData estimatedDataFromServerData:@{ @"a" : @"b" }
                                                                   operationSetQueue:nil];
    NSDictionary *snapshot = data.dictionaryRepresentation;

    [data applyFieldOperation:[PFSetOperation setWithValue:@"updated"] forKey:@"a"];
    [data applyFieldOperation:[PFSetOperation setWithValue:@"new"] forKey:@"c"];

    XCTAssertEqualObjects(snapshot, (@{ @"a" : @"b" }));
    XCTAssertEqualObjects(data.dictionaryRepresentation, (@{ @"a" : @"updated", @"c" : @"new" }));
}

- (void)testInitializationCopiesServerDataByEnumeratingEntries {
    PFEnumerationTrackingDictionary *serverData =
    [[PFEnumerationTrackingDictionary alloc] initWithDictionary:@{ @"a" : @"b" }];

    PFObjectEstimatedData *data = [PFObjectEstimatedData estimatedDataFromServerData:serverData
                                                                   operationSetQueue:nil];

    XCTAssertTrue(serverData.enumerationCalled);
    XCTAssertEqualObjects(data.dictionaryRepresentation, (@{ @"a" : @"b" }));
}

- (void)testInitialMutationDoesNotChangeServerData {
    NSMutableDictionary *serverData = [@{ @"a" : @"original", @"nested" : @[ @"same-object" ] } mutableCopy];
    id nestedValue = serverData[@"nested"];
    PFObjectEstimatedData *data = [PFObjectEstimatedData estimatedDataFromServerData:serverData
                                                                   operationSetQueue:nil];

    [data applyFieldOperation:[PFSetOperation setWithValue:@"updated"] forKey:@"a"];

    XCTAssertEqualObjects(serverData[@"a"], @"original");
    XCTAssertEqualObjects(data[@"a"], @"updated");
    XCTAssertEqual(data[@"nested"], nestedValue);
}

@end
