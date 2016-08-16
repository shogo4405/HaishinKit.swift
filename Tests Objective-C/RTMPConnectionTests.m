#import <XCTest/XCTest.h>
#import <lf/lf-Swift.h>

@interface RTMPConnectionTests : XCTestCase

@end

@implementation RTMPConnectionTests

- (void)testConnect {
    RTMPConnection *conn = [[RTMPConnection alloc] init];
    [conn connect: @"rtmp://localhost:8080"];
}

@end
