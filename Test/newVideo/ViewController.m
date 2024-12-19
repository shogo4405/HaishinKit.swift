
#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "TFVideoViewController.h"

@interface ViewController ()

@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;


@end

@implementation ViewController

-(void)pushClick:(UIButton*)btn
{
    
    TFVideoViewController *vc = [[TFVideoViewController alloc]init];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:vc animated:YES completion:nil];
    
}
- (void)viewDidLoad {
    [super viewDidLoad];
 
    UIButton *push = [[UIButton alloc]init];
    push.backgroundColor = [UIColor blackColor];
    push.frame = CGRectMake(0, 100, 100, 100);
    [push setTitle:@"跳转视频" forState:UIControlStateNormal];
    [self.view addSubview:push];
    
    [push addTarget:self action:@selector(pushClick:) forControlEvents:UIControlEventTouchUpInside];

//    // 1. 创建捕获会话
//    self.session = [[AVCaptureSession alloc] init];
//
//    // 2. 选择输入设备（后置摄像头）
//    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
//    
//    NSError *error = nil;
//    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
//    if (!input) {
//        // 错误处理
//        NSLog(@"错误: %@", [error localizedDescription]);
//        return;
//    }
//
//    // 3. 将输入添加到会话
//    if ([self.session canAddInput:input]) {
//        [self.session addInput:input];
//    }
//
//    // 4. 创建预览层
//    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
//    self.previewLayer.frame = self.view.bounds; // 设置预览层的大小
//    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill; // 设置视频显示方式
//
//    // 5. 将预览层添加到视图层级
//    [self.view.layer addSublayer:self.previewLayer];
//
//    // 6. 开始会话
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        [self.session startRunning];
//    });

//    // 创建切换到短焦摄像头的按钮
//    UIButton *switchToStandardButton = [UIButton buttonWithType:UIButtonTypeSystem];
//    [switchToStandardButton setTitle:@"近摄摄像头" forState:UIControlStateNormal];
//    [switchToStandardButton addTarget:self action:@selector(switchToStandardCamera) forControlEvents:UIControlEventTouchUpInside];
//    switchToStandardButton.frame = CGRectMake(50, 150, 150, 40);
//    [self.view addSubview:switchToStandardButton];
//    
//    // 创建切换到超广角摄像头的按钮
//      UIButton *switchToWideAngleButton = [UIButton buttonWithType:UIButtonTypeSystem];
//      [switchToWideAngleButton setTitle:@"中摄摄像头" forState:UIControlStateNormal];
//      [switchToWideAngleButton addTarget:self action:@selector(switchToWideAngleCamera) forControlEvents:UIControlEventTouchUpInside];
//      switchToWideAngleButton.frame = CGRectMake(50, 250, 150, 40);
//      [self.view addSubview:switchToWideAngleButton];
//    
//    
//    // 创建切换到长焦摄像头的按钮
//    UIButton *switchToTelephotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
//    [switchToTelephotoButton setTitle:@"远摄摄像头" forState:UIControlStateNormal];
//    [switchToTelephotoButton addTarget:self action:@selector(switchToTelephotoCamera) forControlEvents:UIControlEventTouchUpInside];
//    switchToTelephotoButton.frame = CGRectMake(50,350, 150, 40);
//    [self.view addSubview:switchToTelephotoButton];

}

- (void)switchToStandardCamera {
    //超广角摄像头  近距离
    [self switchCameraToType:AVCaptureDeviceTypeBuiltInUltraWideCamera];
}
- (void)switchToWideAngleCamera {
    // 主摄像头（广角镜头）中距离 这是大多数摄影和视频应用中使用的默认摄像头。
    [self switchCameraToType:AVCaptureDeviceTypeBuiltInWideAngleCamera];
}

- (void)switchToTelephotoCamera {
    //长焦摄像头（远摄摄像头）
    [self switchCameraToType:AVCaptureDeviceTypeBuiltInTelephotoCamera];
}
- (void)switchCameraToType:(AVCaptureDeviceType)cameraType {
    NSArray *devices = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[cameraType]
                                                                                mediaType:AVMediaTypeVideo
                                                                                 position:AVCaptureDevicePositionUnspecified].devices;
    for (AVCaptureDevice *device in devices) {
        if ([device position] == AVCaptureDevicePositionBack) {
            NSError *error = nil;
            AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
            if (newInput) {
                // 开始配置会话
                [self.session beginConfiguration];
                // 移除旧的输入
                AVCaptureInput *currentInput = self.session.inputs.firstObject;
                if (currentInput) {
                    [self.session removeInput:currentInput];
                }
                // 添加新的输入
                if ([self.session canAddInput:newInput]) {
                    [self.session addInput:newInput];
                }
                // 提交配置
                [self.session commitConfiguration];
                break;
            } else {
                NSLog(@"切换摄像头错误: %@", error.localizedDescription);
            }
        }
    }
}
@end
