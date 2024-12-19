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
    
    [self view:self.view addButton:CGRectMake(rightX, 50, 100, 30) title:@"退出" action:@selector(exitBtnClick:) selected:0];
    
    [self view:self.view addButton:CGRectMake(0, 100, 100, 30) title:@"开始推流" action:@selector(srtClick:) selected:0];
    
    [self view:self.view addButton:CGRectMake(rightX, 150, 100, 30) title:@"前摄像头" action:@selector(attachVideoClick:) selected:1];
    
    [self view:self.view addButton:CGRectMake(0, 200, 100, 30) title:@"镜像开" action:@selector(mirrorClick:) selected:1];
    
    if ([self cameraAvailable:AVCaptureDeviceTypeBuiltInUltraWideCamera position:AVCaptureDevicePositionBack]) {
        [self view:self.view addButton:CGRectMake(0, 240, 100, 30) title:@"近摄像头" action:@selector(switchToStandardCamera) selected:0];
    }
    if ([self cameraAvailable:AVCaptureDeviceTypeBuiltInWideAngleCamera position:AVCaptureDevicePositionBack]) {
        [self view:self.view addButton:CGRectMake((self.view.frame.size.width-100)/2, 240, 100, 30) title:@"中摄像头" action:@selector(switchToWideAngleCamera) selected:1];
    }
    if ([self cameraAvailable:AVCaptureDeviceTypeBuiltInTelephotoCamera position:AVCaptureDevicePositionBack]) {
        [self view:self.view addButton:CGRectMake(rightX, 240, 100, 30) title:@"远摄像头" action:@selector(switchToTelephotoCamera) selected:0];
    }
    
    [self view:self.view addButton:CGRectMake(0, 290, 100, 30) title:@"开始录制" action:@selector(recordingClick:) selected:0];

    [self view:self.view addButton:CGRectMake(rightX, 340, 100, 30) title:@"添加水印" action:@selector(addWatermarkClick:) selected:0];
    
    //---------------
    [self view:self.view addButton:CGRectMake(0, 390, 100, 30) title:@"倍放" action:@selector(zoomScaleClick:) selected:0];
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
    [self view:self.view addButton:CGRectMake(rightX, 440, 100, 30) title:@"美颜 关" action:@selector(videoEffectClick:) selected:0];
 
    self.focusBoxPoint = [self view:self.view addButton:CGRectMake(0, 490, 100, 30) title:@"自动焦点" action:@selector(focusBoxPointClick:) selected:1];
    self.focusBoxPoint.selected = true;
    

    [self view:self.view addButton:CGRectMake(rightX, 540, 100, 30) title:@"有音" action:@selector(mutedClick:) selected:0];
    [self view:self.view addButton:CGRectMake(0, 590, 100, 30) title:@"摄像头 开" action:@selector(cameraClick:) selected:1];

    
    self.streamBtn = [self view:self.view addButton:CGRectMake(rightX, 630, 100, 30) title:@"SRT推流" action:@selector(streamClick:) selected:1];
    self.streamBtn.selected = true;
    
    
    self.ingest = [[TFIngest alloc]init];
    [self.ingest setSDKWithView:self.view2
                      videoSize:CGSizeMake(540, 960)
                 videoFrameRate:30
                   videoBitRate:600*1024
                     streamMode:TFStreamModeSrt
                         mirror:true
    ];
    
    //设置URL
    [self setStreamMode:TFStreamModeSrt];
}
//摄像头开关
- (void)cameraClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    [self.ingest setCamera:btn.selected];

    if (btn.selected) {
        [btn setTitle:@"摄像头 开" forState:UIControlStateNormal];
        NSLog(@"摄像头 开");
    }else{
        [btn setTitle:@"摄像头 关" forState:UIControlStateNormal];
        NSLog(@"摄像头 关");
    }
    
}
- (void)mutedClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    //静音
    [self.ingest setMuted:btn.selected];

    if (btn.selected) {
        [btn setTitle:@"静音" forState:UIControlStateNormal];
        NSLog(@"静音");
    }else{
        [btn setTitle:@"有音" forState:UIControlStateNormal];
        NSLog(@"有音");
    }
}

//RTMP推流  SRT推流
- (void)streamClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    if(btn.selected==false)
    {
        [self setStreamMode:TFStreamModeRtmp];
    }else{
        
        [self setStreamMode:TFStreamModeSrt];
    }

}
- (void)zoomScaleClick:(UIButton *)sender {
}
//TODO: 倍放
- (void)zoomSliderChanged:(UISlider *)sender {
    CGFloat scale = sender.value;
    [self.ingest zoomScale:scale];
//    NSLog(@"倍放====>%f",scale);
}
//TODO: 添加水印
- (void)addWatermarkClick:(UIButton*)btn {
    btn.selected = !btn.selected;
    if (btn.selected) {
        UIImageView *imageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"66"] ];
        imageView.backgroundColor = [UIColor blackColor];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.frame = CGRectMake(0, 50, self.view.frame.size.width/2, 100);
        
        [self.ingest addWatermark: [self highQualitySnapshot:imageView] frame:CGRectMake(0, 50, self.view.frame.size.width/2, 100)];
    }else
    {
        [self.ingest clearWatermark];
        //删除水印
    }
  
    if (btn.selected==0) {
        [btn setTitle:@"添加水印" forState:UIControlStateNormal];
    }else{
        [btn setTitle:@"删除水印" forState:UIControlStateNormal];
    }
   
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

//TODO: 美颜开关
- (void)videoEffectClick:(UIButton*)btn {
    btn.selected = !btn.selected;
    if (btn.selected) {
        [btn setTitle:@"美颜 开" forState:UIControlStateNormal];
    }else{
        [btn setTitle:@"美颜 关" forState:UIControlStateNormal];
    }
    self.ingest.beauty = btn.selected;

    NSLog(@"美颜开关====>%ld",(long)btn.tag);
}
- (void)recordingClick:(UIButton*)btn {
    btn.selected = !btn.selected;
    if (btn.selected) {
        [self.ingest recording:true];
    }else{
        [self.ingest recording:false];
    }
   
    if (btn.selected) {
        [btn setTitle:@"开始录制" forState:UIControlStateNormal];
    }else{
        [btn setTitle:@"停止录制" forState:UIControlStateNormal];
    }
}
//TODO: 超广角摄像头  近距离
- (void)switchToStandardCamera {
    [self.ingest switchCameraToTypeWithCameraType:AVCaptureDeviceTypeBuiltInUltraWideCamera position:AVCaptureDevicePositionBack ];
}
//TODO: 主摄像头（广角镜头）中距离 这是大多数摄影和视频应用中使用的默认摄像头。
- (void)switchToWideAngleCamera {
    [self.ingest switchCameraToTypeWithCameraType:AVCaptureDeviceTypeBuiltInWideAngleCamera position:AVCaptureDevicePositionBack];
}
//TODO: 长焦摄像头（远摄摄像头）
- (void)switchToTelephotoCamera {
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
- (UIButton*)view:(UIView*)view addButton:(CGRect)rect title:(NSString*)title action:(SEL)action selected:(NSInteger)selected
{
    UIButton *btn = [[UIButton alloc]init];
    btn.backgroundColor = [UIColor blackColor];
    btn.frame = rect;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.selected = selected;
    [view addSubview:btn];
    btn.alpha = 0.5;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}
- (void)exitBtnClick:(UIButton*)btn
{
    [self.ingest shutdown];

    [self dismissViewControllerAnimated:YES completion:nil];
}

//TODO: 前后摄像头切换
- (void)attachVideoClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    if (btn.selected==false) {
        [self.ingest attachVideoWithPosition:AVCaptureDevicePositionBack];
        [btn setTitle:@"后摄像头" forState:UIControlStateNormal];
    }else
    {
        [self.ingest attachVideoWithPosition:AVCaptureDevicePositionFront];
        [btn setTitle:@"前摄像头" forState:UIControlStateNormal];
    }
}
//TODO: 镜像开关
- (void)mirrorClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    
    if(btn.selected==false)
    {
        [btn setTitle:@"镜像关" forState:UIControlStateNormal];
    }else{
        [btn setTitle:@"镜像开" forState:UIControlStateNormal];
    }

    //镜像开关
    [self.ingest isVideoMirrored:btn.selected];
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

        CGSize size = self.view2.bounds.size;
        CGPoint focusPoint = CGPointMake( point.y /size.height ,1-point.x/size.width );
        
        //手动
        [self.ingest setFocusBoxPoint:focusPoint focusMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose];
    }

}
//TODO: 默认自动对焦
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
- (void)setStreamMode:(TFStreamMode)model
{
    if(model==TFStreamModeRtmp)
    {
        [self.streamBtn setTitle:@"RTMP推流" forState:UIControlStateNormal];
        [self.ingest setSrtUrlWithUrl:[self RTMP_URL] streamMode:model];

    }else{
        
        [self.streamBtn setTitle:@"SRT推流" forState:UIControlStateNormal];
        [self.ingest setSrtUrlWithUrl:[self SRT_URL] streamMode:model];

    }
    
}
//TODO: 开始推流-------------------
- (void)srtClick:(UIButton*)btn
{
    if (btn.selected == false ) {
        [self.ingest startLiveWithCallback:^(NSInteger code, NSString * msg) {
            
            if (code==0) {
                [btn setTitle:@"停止推流" forState:UIControlStateNormal];
                btn.selected = true;
                NSLog(@"推流成功=======>");
            }else{
                NSLog(@"推流失败=======>");
            }
        }];
    } else {
    //停止推流
        [self.ingest stopLive];
        [btn setTitle:@"开始推流" forState:UIControlStateNormal];
        btn.selected = false;
        NSLog(@"停止推流=======>");
   }
    
}
- (NSString*)RTMP_URL
{
    return @"rtmp://live-push-15.talk-fun.com/live/11306_IyIhLCEnSCshLy8sKytAEA?txSecret=3cdf27dbbd5bfa8a6f1258adc00896da&txTime=676271F5";
}
- (NSString*)SRT_URL
{
    return @"srt://live-push-15.talk-fun.com:9000?streamid=#!::h=live-push-15.talk-fun.com,r=live/11306_IiYiISNKJS8tLykuLUIu,txSecret=45f54f68fbc9d2a264e13858b54ae1b7,txTime=676504A2";
}
- (void)dealloc{
    NSLog(@"控制器销毁==========>");
}
@end
