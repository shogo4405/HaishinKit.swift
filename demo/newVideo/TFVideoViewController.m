//
//  TFVideoViewController.m
//  newVideo
//
//  Created by moRui on 2024/12/3.
//

#import "TFVideoViewController.h"
#import <AVFoundation/AVFoundation.h>

@import TFSRT;
@interface TFVideoViewController ()
@property (nonatomic, strong) MTHKView *view2;
@property (nonatomic, strong) TFIngest *ingest;
@property (nonatomic, strong) UISlider *zoomSlider;
@property (nonatomic, strong)UIImageView *focusCursorImageView;
@property (nonatomic, strong)UIButton *focusBoxPoint;
@property (nonatomic, strong)UIButton *streamBtn;
@end

@implementation TFVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    //符合 HKStreamOutput 协议的视图
    self.view2 = [[MTHKView alloc]init];
    self.view2.frame = self.view.frame;
    [self.view addSubview:self.view2];
    
    CGFloat rightX = self.view.frame.size.width-100;
    
    [self view:self.view addButton:CGRectMake(0, 50, 100, 30) title:@"退出" action:@selector(exitBtnClick:) tag:0];
    
    [self view:self.view addButton:CGRectMake(0, 100, 100, 30) title:@"开始推流" action:@selector(srtClick:) tag:0];
    [self view:self.view addButton:CGRectMake(rightX, 100, 100, 30) title:@"停止推流" action:@selector(srtClick:) tag:1];
    
    [self view:self.view addButton:CGRectMake(0, 150, 100, 30) title:@"后摄像头" action:@selector(attachVideoClick:) tag:0];
    [self view:self.view addButton:CGRectMake(rightX, 150, 100, 30) title:@"前摄像头" action:@selector(attachVideoClick:) tag:1];
    
    [self view:self.view addButton:CGRectMake(0, 200, 100, 30) title:@"镜像关" action:@selector(mirrorClick:) tag:0];
    [self view:self.view addButton:CGRectMake(rightX, 200, 100, 30) title:@"镜像开" action:@selector(mirrorClick:) tag:1];
    
    if ([self cameraAvailable:AVCaptureDeviceTypeBuiltInUltraWideCamera position:AVCaptureDevicePositionBack]) {
        [self view:self.view addButton:CGRectMake(0, 240, 100, 30) title:@"近摄像头" action:@selector(switchToStandardCamera) tag:0];
    }
    if ([self cameraAvailable:AVCaptureDeviceTypeBuiltInWideAngleCamera position:AVCaptureDevicePositionBack]) {
        [self view:self.view addButton:CGRectMake((self.view.frame.size.width-100)/2, 240, 100, 30) title:@"中摄像头" action:@selector(switchToWideAngleCamera) tag:1];
    }
    if ([self cameraAvailable:AVCaptureDeviceTypeBuiltInTelephotoCamera position:AVCaptureDevicePositionBack]) {
        [self view:self.view addButton:CGRectMake(rightX, 240, 100, 30) title:@"远摄像头" action:@selector(switchToTelephotoCamera) tag:0];
    }
    
    [self view:self.view addButton:CGRectMake(0, 290, 100, 30) title:@"开始录制" action:@selector(recordingClick:) tag:1];
    [self view:self.view addButton:CGRectMake(rightX, 290, 100, 30) title:@"停止录制" action:@selector(recordingClick:) tag:0];
    
    [self view:self.view addButton:CGRectMake(0, 340, 100, 30) title:@"删除水印" action:@selector(clearWatermark:) tag:0];
    [self view:self.view addButton:CGRectMake(rightX, 340, 100, 30) title:@"添加水印" action:@selector(addWatermark:) tag:0];
    
    //---------------
    [self view:self.view addButton:CGRectMake(0, 390, 100, 30) title:@"倍放" action:@selector(clearWatermark:) tag:0];
    // 创建 Slider
    self.zoomSlider = [[UISlider alloc] init];
    self.zoomSlider.minimumValue = 1.0; // 最小缩放倍数
    self.zoomSlider.maximumValue = 3.0; // 最大缩放倍数
    self.zoomSlider.value = 1.0;        // 初始缩放倍数
    self.zoomSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.zoomSlider];
    self.zoomSlider.backgroundColor = [UIColor blackColor];
    self.zoomSlider.frame = CGRectMake(110, 390, self.view.frame.size.width-110, 30);
    [self.zoomSlider addTarget:self action:@selector(zoomSliderChanged:) forControlEvents:UIControlEventValueChanged];
    self.zoomSlider.alpha = 0.5;
    //---------------
    [self view:self.view addButton:CGRectMake(0, 440, 100, 30) title:@"关 美颜" action:@selector(videoEffectClick:) tag:0];
    [self view:self.view addButton:CGRectMake(self.view.frame.size.width-100, 440, 100, 30) title:@"开 美颜" action:@selector(videoEffectClick:) tag:1];

    self.focusBoxPoint = [self view:self.view addButton:CGRectMake(0, 490, 100, 30) title:@"自动焦点" action:@selector(focusBoxPointClick:) tag:1];
    self.focusBoxPoint.selected = true;
    
    
     self.ingest = [[TFIngest alloc]init];
    [self.ingest setSDKWithView:self.view2
                      videoSize:CGSizeMake(720, 1280)
                 videoFrameRate:30
                   videoBitRate:600*1024
                     streamMode:TFStreamModeRtmp];
    
    self.streamBtn = [self view:self.view addButton:CGRectMake(self.view.frame.size.width-90, 490, 100, 30) title:@"RTMP推流" action:@selector(streamClick:) tag:1];
    self.streamBtn.selected = true;
    //设置URL
    [self setStreamMode:TFStreamModeRtmp];
}

- (void)setStreamMode:(TFStreamMode)model
{
    if(model==TFStreamModeRtmp)
    {
        [self.streamBtn setTitle:@"RTMP推流" forState:UIControlStateNormal];
        [self.ingest setSrtUrlWithUrl:[self RTMP_URL]];
    }else{
     
        [self.streamBtn setTitle:@"SRT推流" forState:UIControlStateNormal];
        [self.ingest setSrtUrlWithUrl:[self SRT_URL]];
    }
    
}

- (NSString*)RTMP_URL
{
 return @"rtmp://live-push-15.talk-fun.com/live/11306_IyIhLCEnSCshLyslJClAEA?txSecret=6780bf0a91cb99a650f25cf3e132db98&txTime=675D3070";
}
- (NSString*)SRT_URL
{
    return @"srt://live-push-15.talk-fun.com:9000?streamid=#!::h=live-push-15.talk-fun.com,r=live/11306_IyIhLCEnSCshLyslJClAEA,txSecret=2e7543ede6135728b431a56cb2ebdd32,txTime=675CFAB4";
}
- (void)streamClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    if(btn.selected==true)
    {
        [self setStreamMode:TFStreamModeRtmp];
    }else{
     
        [self setStreamMode:TFStreamModeSrt];
    }
    
}
- (void)zoomSliderChanged:(UISlider *)sender {
    CGFloat scale = sender.value;
    [self.ingest zoomScale:scale];
//    NSLog(@"缩放====>%f",scale);
}
//添加水印
- (void)addWatermark:(UIButton*)recording {
    
    UIImageView *imageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"66"] ];
    imageView.backgroundColor = [UIColor blackColor];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.frame = CGRectMake(0, 50, self.view.frame.size.width/2, 100);
    
    [self.ingest addWatermark: [self highQualitySnapshot:imageView] frame:CGRectMake(0, 50, self.view.frame.size.width/2, 100)];
}

- (UIImage *)highQualitySnapshot:(UIImageView *)view {
    // 确保传入的 view 不为 nil
    if (!view) {
        return [[UIImage alloc]init];
    }

    // 确保视图已经布局完成
    [view layoutIfNeeded];

    // 获取视图的内容尺寸和比例尺
    CGSize viewSize = view.bounds.size;
    CGFloat scale = [UIScreen mainScreen].scale;

    // 创建一个与视图大小相同且具有相同比例尺的图像上下文
    UIGraphicsBeginImageContextWithOptions(viewSize, NO, scale);
    if (UIGraphicsGetCurrentContext() != nil) {
        // 将视图的内容绘制到上下文中
        [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];

        // 从上下文中获取图像
        UIImage *snapshotImage = UIGraphicsGetImageFromCurrentImageContext();

        // 结束图像上下文
        UIGraphicsEndImageContext();

        return snapshotImage;
    } else {
        // 如果无法创建上下文，则返回 nil
        return [[UIImage alloc]init];
    }
}
//删除水印
- (void)clearWatermark:(UIButton*)recording {
    [self.ingest clearWatermark];
}

//美颜开关
- (void)videoEffectClick:(UIButton*)recording {
    self.ingest.beauty = recording.tag;
}
- (void)recordingClick:(UIButton*)recording {
    
    if (recording.tag==1) {
        [self.ingest recording:true];
    }else{
        [self.ingest recording:false];
    }
    
}

- (void)switchToStandardCamera {
    //超广角摄像头  近距离
    [self.ingest switchCameraToTypeWithCameraType:AVCaptureDeviceTypeBuiltInUltraWideCamera position:AVCaptureDevicePositionBack ];
}
- (void)switchToWideAngleCamera {
    // 主摄像头（广角镜头）中距离 这是大多数摄影和视频应用中使用的默认摄像头。
    [self.ingest switchCameraToTypeWithCameraType:AVCaptureDeviceTypeBuiltInWideAngleCamera position:AVCaptureDevicePositionBack];
}

- (void)switchToTelephotoCamera {
    //长焦摄像头（远摄摄像头）
    [self.ingest switchCameraToTypeWithCameraType:AVCaptureDeviceTypeBuiltInTelephotoCamera position:AVCaptureDevicePositionBack];

}
/**
 AVCaptureDeviceTypeBuiltInUltraWideCamera  超广角摄像头  (近距离)
 AVCaptureDeviceTypeBuiltInWideAngleCamera 中距离 (这是大多数摄影和视频应用中使用的默认摄像头)
 AVCaptureDeviceTypeBuiltInTelephotoCamera  长焦摄像头（远摄摄像头）
 
 position:
    AVCaptureDevicePositionBack后摄像头
    AVCaptureDevicePositionFront前摄像头
 摄像头是否支持**/
- (BOOL)cameraAvailable:(AVCaptureDeviceType)cameraType position:(AVCaptureDevicePosition)position
{
    NSArray<AVCaptureDevice *> *devices = nil;

    if (@available(iOS 13.0, *)) {
        AVCaptureDeviceDiscoverySession *discoverySession =
            [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[cameraType]
                                                                  mediaType:AVMediaTypeVideo
                                                                   position:position];
        
        devices = discoverySession.devices;
    }
    return devices != nil && devices.count > 0;
}
- (UIButton*)view:(UIView*)view addButton:(CGRect)rect title:(NSString*)title action:(SEL)action tag:(NSInteger)tag
{
    UIButton *btn = [[UIButton alloc]init];
    btn.backgroundColor = [UIColor blackColor];
    btn.frame = rect;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.tag = tag;
    [view addSubview:btn];
    btn.alpha = 0.5;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}
- (void)exitBtnClick:(UIButton*)btn
{
    [self.ingest shutdown];
    self.ingest = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)srtClick:(UIButton*)btn
{
    //开始推流
    if (btn.tag ==0 ) {
        [self.ingest startLiveWithCallback:^(NSInteger code, NSString * msg) {
            
            if (code==0) {
                
                NSLog(@"推流成功=======>");
                
            }else{
                NSLog(@"推流失败=======>");
            }
        }];
    } else {
    //停止推流
        [self.ingest stopLive];
   }
    
}
//前后摄像开关
- (void)attachVideoClick:(UIButton*)btn
{
    if (btn.tag ==0 ) {
        [self.ingest attachVideoWithPosition:AVCaptureDevicePositionBack];
    }else
    {
        [self.ingest attachVideoWithPosition:AVCaptureDevicePositionFront];
    }
}
//镜像开关
- (void)mirrorClick:(UIButton*)btn
{
    if (btn.tag ==0 ) {
        
        [self.ingest isVideoMirrored:false];
        
    }else{
        [self.ingest isVideoMirrored:true];
    }
}
- (UIImageView *)focusCursorImageView {
    if (!_focusCursorImageView) {
        _focusCursorImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed: @"focus"]];
        [self.view addSubview:_focusCursorImageView];
    }
    return _focusCursorImageView;
}
// 设置聚集光标的位置
- (void)setFocusCursorWithPoint: (CGPoint)point {
   self.focusCursorImageView.center = point;
   self.focusCursorImageView.transform = CGAffineTransformMakeScale(1.5, 1.5);
   self.focusCursorImageView.alpha = 1.0f;
   [UIView animateWithDuration:1.0 animations:^{
       self.focusCursorImageView.transform = CGAffineTransformIdentity;
   } completion:^(BOOL finished) {
       self.focusCursorImageView.alpha = 0.0f;
   }];
}
#pragma mark - 聚集光标
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(self.focusBoxPoint.selected==false)
    {
        // 获取点击位置
        UITouch *touch= [touches anyObject];
        CGPoint point = [touch locationInView:self.view];
        // 设置聚集光标的位置
        [self setFocusCursorWithPoint:point];

        //手动
        [self.ingest setFocusBoxPoint:point focusMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose];
    }

}



//默认自动对焦
- (void)focusBoxPointClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    //自动对焦
    if(btn.selected==true)
    {
      
        CGPoint point = CGPointMake(0.5, 0.5);
        [self.ingest setFocusBoxPoint:point focusMode:AVCaptureFocusModeContinuousAutoFocus exposureMode:AVCaptureExposureModeContinuousAutoExposure];
        [btn setTitle:@"自动对焦" forState:UIControlStateNormal];
    }else{
        [btn setTitle:@"手动对焦" forState:UIControlStateNormal];
    }
  
}

- (void)dealloc{
    NSLog(@"控制器销毁==========>");
}
@end
