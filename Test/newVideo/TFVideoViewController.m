//
//  TFVideoViewController.m
//  newVideo
//
//  Created by moRui on 2024/12/3.
//

#import "TFVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "TFVideoViewTool.h"
@import TFSRT;
@interface TFVideoViewController ()
@property (nonatomic, strong) TFDisplays *view2;
@property (nonatomic, strong) TFIngest *ingest;
@property (nonatomic, strong) UISlider *zoomSlider;
@property (nonatomic, strong)UIImageView *focusCursorImageView;
@property (nonatomic, strong)UIButton *focusBoxPoint;
@property (nonatomic, strong)UIButton *streamBtn;
@property (nonatomic, strong)NSString *pushUrl;

@property (nonatomic, assign)CGSize videoSizeMak;
@property (nonatomic) CVPixelBufferRef cameraPicture;
@property (nonatomic,strong) NSTimer *cameraTimer;
@end

@implementation TFVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    //符合 HKStreamOutput 协议的视图
    self.view2 = [[TFDisplays alloc]init];
    self.view2.frame = self.view.frame;
    [self.view addSubview:self.view2];
    
    CGFloat rightX = self.view.frame.size.width-100;
    
    [self view:self.view addButton:CGRectMake(rightX, 50, 100, 30) title:@"退出" action:@selector(exitBtnClick:) selected:false];
    self.streamBtn = [self view:self.view addButton:CGRectMake(0, 50, 100, 30) title:@"SRT推流" action:@selector(streamClick:) selected:1];
    self.streamBtn.selected = true;
    
    [self view:self.view addButton:CGRectMake(0, 100, 100, 30) title:@"开始推流" action:@selector(srtClick:) selected:false];
    
    [self view:self.view addButton:CGRectMake(rightX, 150, 100, 30) title:@"前摄像头" action:@selector(attachVideoClick:) selected:true];
    
    [self view:self.view addButton:CGRectMake(0, 200, 100, 30) title:@"镜像开" action:@selector(mirrorClick:) selected:true];
    
    if ([self cameraAvailable:AVCaptureDeviceTypeBuiltInUltraWideCamera position:AVCaptureDevicePositionBack]) {
        [self view:self.view addButton:CGRectMake(0, 240, 100, 30) title:@"近摄像头" action:@selector(switchToStandardCamera) selected:false];
    }
    if ([self cameraAvailable:AVCaptureDeviceTypeBuiltInWideAngleCamera position:AVCaptureDevicePositionBack]) {
        [self view:self.view addButton:CGRectMake((self.view.frame.size.width-100)/2, 240, 100, 30) title:@"中摄像头" action:@selector(switchToWideAngleCamera) selected:1];
    }
    if ([self cameraAvailable:AVCaptureDeviceTypeBuiltInTelephotoCamera position:AVCaptureDevicePositionBack]) {
        [self view:self.view addButton:CGRectMake(rightX, 240, 100, 30) title:@"远摄像头" action:@selector(switchToTelephotoCamera) selected:false];
    }
    
    [self view:self.view addButton:CGRectMake(0, 290, 100, 30) title:@"开始录制" action:@selector(recordingClick:) selected:false];

    [self view:self.view addButton:CGRectMake(rightX, 340, 100, 30) title:@"添加水印" action:@selector(addWatermarkClick:) selected:false];
    
    //---------------
    [self view:self.view addButton:CGRectMake(0, 390, 100, 30) title:@"倍放" action:@selector(zoomScaleClick:) selected:false];
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
 
    self.focusBoxPoint = [self view:self.view addButton:CGRectMake(0, 440, 100, 30) title:@"自动焦点" action:@selector(focusBoxPointClick:) selected:1];
    self.focusBoxPoint.selected = true;
    

    [self view:self.view addButton:CGRectMake(rightX, 490, 100, 30) title:@"有音" action:@selector(mutedClick:) selected:0];
    [self view:self.view addButton:CGRectMake(0, 490, 100, 30) title:@"摄像头 开" action:@selector(cameraClick:) selected:1];

    [self view:self.view addButton:CGRectMake(0, 540, 200, 30) title:@"CGSizeMake(240, 320)" action:@selector(sizeMakeClick:) selected:1];
    self.videoSizeMak = CGSizeMake(240, 320);
    
    self.ingest = [[TFIngest alloc]init];
    //前置摄像头的本地预览锁定为水平翻转  默认 true
    self.ingest.frontCameraPreviewLockedToFlipHorizontally = false;
    [self.ingest setSDKWithPreview:self.view2
                      videoSize:self.videoSizeMak
                 videoFrameRate:24
                   videoBitRate:600*1024
                     streamMode:TFStreamModeSrt mirror:true
                     cameraType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                       position:AVCaptureDevicePositionFront];
    
    //设置URL
    self.pushUrl = [self SRT_URL];

}
- (void)sizeMakeClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    
    if (btn.selected) {
        self.videoSizeMak = CGSizeMake(540, 960);
        [btn setTitle:@"CGSizeMake(540, 960)" forState:UIControlStateNormal];
        [_ingest setVideoMixerSettingsWithVideoSize:CGSizeMake(540, 960)
                                         videoFrameRate:30
                                           videoBitRate:900*1024];
    }else{
        self.videoSizeMak = CGSizeMake(240, 320);
        [btn setTitle:@"CGSizeMake(240, 320)" forState:UIControlStateNormal];
     
        [_ingest setVideoMixerSettingsWithVideoSize:CGSizeMake(240, 320)
                                         videoFrameRate:24
                                           videoBitRate:600*1024];
    }
    
    NSLog(@"当前分辨率%@",NSStringFromCGSize(self.videoSizeMak));
}
//摄像头开关
- (void)cameraClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    [self.ingest setCamera:btn.selected];

    if (btn.selected) {
        [btn setTitle:@"摄像头 开" forState:UIControlStateNormal];
        NSLog(@"摄像头 开");
//        [self stopCameraPictureTimer];
    }else{
        [btn setTitle:@"摄像头 关" forState:UIControlStateNormal];
        NSLog(@"摄像头 关");
//        [self startCameraPicutreTimer];
    }
    
}
- (void)stopCameraPictureTimer {
    if(_cameraTimer){
        [_cameraTimer invalidate];
        _cameraTimer = nil;
    }
}
- (void)startCameraPicutreTimer {
    if(!_cameraTimer){
        //推送背景图
        _cameraTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(cameraPictureHandler) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_cameraTimer forMode:NSRunLoopCommonModes];
    }
}
- (void)cameraPictureHandler
{
//    [self.ingest pushVideo:[self cameraPicture] ];
}
- (CVPixelBufferRef)cameraPicture {
    if(_cameraPicture == nil){
        NSString *pictureFile = [NSString stringWithFormat:@"TalkfunLive.bundle/camera_%ldx%ld.png",(long)self.videoSizeMak.width,(long)self.videoSizeMak.height];
        
        if(![[NSFileManager defaultManager]fileExistsAtPath:pictureFile]){
            pictureFile = [NSString stringWithFormat:@"TalkfunLive.bundle/camera_%dx%d.png",320,240];
        }
        
        UIImage* myImage = [UIImage imageNamed:pictureFile];
        
        if(myImage ==nil){
        
            NSString *pictureFile = [NSString stringWithFormat:@"CloudLiveSDKFramework.bundle/camera_%ldx%ld.png",(long)self.videoSizeMak.width,(long)self.videoSizeMak.height];
            
            if(![[NSFileManager defaultManager]fileExistsAtPath:pictureFile]){
                pictureFile = [NSString stringWithFormat:@"CloudLiveSDKFramework.bundle/camera_%dx%d.png",320,240];
                myImage = [UIImage imageNamed:pictureFile];
                
    
            }

        }
        if (myImage) {
            CGImageRef imageRef = [myImage CGImage];
            _cameraPicture = [TFVideoViewTool pixelBufferFromCGImage:imageRef];
        }
       
    }
    return _cameraPicture;
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
    

    if (btn.selected==false) {
       
        [self.ingest recording:true completion:^(BOOL success, NSURL * _Nullable url , NSError * _Nullable error) {
            if (success==true) {
                NSLog(@"srt设置录制的视频路径=======>%@", url);
                [btn setTitle:@"停止录制" forState:UIControlStateNormal];
                btn.selected = true;
            }else{
                NSLog(@"srt设置录制失败=======>%@", error);
            }
        }];
    }else{
        [self.ingest recording:false completion:^(BOOL success, NSURL * _Nullable url, NSError * _Nullable error) {
            if (success==true) {
                NSLog(@"srt停止视频录制路径=======>%@", url);
                [btn setTitle:@"开始录制" forState:UIControlStateNormal];
                btn.selected = false;
            }else{
                NSLog(@"srt停止视频录制失败=====>%@", error);
            }
        }];
        
        
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
- (UIButton*)view:(UIView*)view addButton:(CGRect)rect title:(NSString*)title action:(SEL)action selected:(BOOL)selected
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
    
    [self.cameraTimer invalidate];
    self.cameraTimer = nil;

    [self dismissViewControllerAnimated:YES completion:nil];
}

//TODO: 前后摄像头切换
- (void)attachVideoClick:(UIButton*)btn
{
    btn.selected = !btn.selected;
    if (btn.selected==false) {
//        [self.ingest attachVideoWithPosition:AVCaptureDevicePositionBack];
        
        [self.ingest switchCameraToTypeWithCameraType:AVCaptureDeviceTypeBuiltInWideAngleCamera position:AVCaptureDevicePositionBack];
        
        
        [btn setTitle:@"后摄像头" forState:UIControlStateNormal];
    }else
    {
//        [self.ingest attachVideoWithPosition:AVCaptureDevicePositionFront];
        
        [self.ingest switchCameraToTypeWithCameraType:AVCaptureDeviceTypeBuiltInWideAngleCamera position:AVCaptureDevicePositionFront];
        
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
    [self.ingest configurationWithIsVideoMirrored:btn.selected];
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
        self.pushUrl = [self RTMP_URL];
    }else{
        
        [self.streamBtn setTitle:@"SRT推流" forState:UIControlStateNormal];
        self.pushUrl = [self SRT_URL];
    }
    [self.ingest renewWithStreamMode:model pushUrl:self.pushUrl callback:^(NSInteger code, NSString * _Nonnull msg) {
        
    }];
}
//TODO: 开始推流-------------------
- (void)srtClick:(UIButton*)btn
{
    if (btn.selected == false ) {
        NSLog(@"开始推流self.pushUrl=====>%@",self.pushUrl);
        [self.ingest startLiveWithUrl:self.pushUrl callback:^(NSInteger code, NSString * msg) {

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
    return @"rtmp://live-push-15.talk-fun.com/live/24827_JCMnJSAnSCshLCgoKSdAEA?txSecret=c648aab450dd620f549751f423e7a933&txTime=676F7236";
}
- (NSString*)SRT_URL
{
    return @"srt://live-push-15.talk-fun.com:9000?streamid=#!::h=live-push-15.talk-fun.com,r=live/24827_JCMnJSAnSCshLC8vKStAEA,txSecret=eac9aeb761ca718469cdaa0d29ce060d,txTime=6770B018";
}
- (void)dealloc{
    NSLog(@"控制器销毁==========>");
}
@end
