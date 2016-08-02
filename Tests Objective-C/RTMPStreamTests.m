#import <XCTest/XCTest.h>
#import <lf/lf-Swift.h>

@interface RTMPStreamTests : XCTestCase

@end

@implementation RTMPStreamTests

- (void)testPublish {
    RTMPConnection *conn = [[RTMPConnection alloc] init];
    RTMPStream *stream = [[RTMPStream alloc]initWithRtmpConnection: conn];
    [stream publish:@"hoge" type: @"live" ];
}

@end
