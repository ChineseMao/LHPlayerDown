//
//  LHPlayer.m
//  LHPlayerDown
//
//  Created by 刘虎 on 16/6/16.
//  Copyright © 2016年 liuhu. All rights reserved.
//

#import "LHPlayer.h"
#import "LHloaderURLConnection.h"
#import "LHVideoRequestTask.h"
#import "LHHudHelper.h"


#define kScreenHeight ([UIScreen mainScreen].bounds.size.height)
#define kScreenWidth ([UIScreen mainScreen].bounds.size.width)
#define IOS_VERSION  ([[[UIDevice currentDevice] systemVersion] floatValue])


NSString *const kLHPlayerStateChangedNotification    = @"LHPlayerStateChangedNotification";
NSString *const kLHPlayerProgressChangedNotification = @"LHPlayerProgressChangedNotification";
NSString *const kLHPlayerLoadProgressChangedNotification = @"LHPlayerLoadProgressChangedNotification";


@interface LHPlayer ()<LHLoaderURLConnectionDelegate>

@property (nonatomic, assign) LHPlayerState state;
@property (nonatomic, assign) CGFloat loadedProgress;                       //缓冲进度
@property (nonatomic, assign) CGFloat duration;                             //视频总时间
@property (nonatomic, assign) CGFloat current;                              //当前播放时间

@property (nonatomic, strong) AVURLAsset *videoURLAsset;
@property (nonatomic, strong) AVAsset *videoAsset;
@property (nonatomic, strong) LHLoaderURLConnection *resouerLoader;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *currentPlayerItem;
@property (nonatomic, strong) AVPlayerLayer *currentPlayerLayer;
@property (nonatomic, strong) NSObject *playbackTimeObserver;
@property (nonatomic, strong) UIView *showView;
@property (nonatomic, strong) UIView *navBar;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *totolTimeLabel;
@property (nonatomic, strong) UIProgressView *videoProgressView;            //缓冲进度条
@property (nonatomic, strong) UISlider *playSlider;                         //滑竿
@property (nonatomic, strong) UIButton *stopButton;                         //播放暂停按钮
@property (nonatomic, strong) UIButton *screenBUtton;                       //全屏按钮

@property (nonatomic, assign) BOOL isFullScreen;
@property (nonatomic, assign) BOOL isPauseByUser;                           //是否被用户暂停
@property (nonatomic, assign) BOOL isLocalVideo;                            //是否播放本地文件
@property (nonatomic, assign) BOOL isFinishLoad;                            //是否下载完毕

@end

@implementation LHPlayer

+ (instancetype)sharedInstance {
    
    static dispatch_once_t onceToken;
    static id handel = nil;
    dispatch_once(&onceToken, ^{
        
        handel = [[self alloc] init];
    });
    return handel;
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
    
        _isPauseByUser = YES;
        _loadedProgress = 0;
        _duration = 0;
        _current  = 0;
        _state = LHPlayerStateStopped;
        _stopWhenAppDidEnterBackground = YES;
    }
    return self;
}

- (void)dealloc {
    
    [self releasePlayer];
}
//清空播放器监听属性
- (void)releasePlayer {
    
    if (!self.currentPlayerItem) {
     
        return;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.currentPlayerItem removeObserver:self forKeyPath:@"status"];
    [self.currentPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.currentPlayerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.currentPlayerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self.player removeTimeObserver:self.playbackTimeObserver];
    self.playbackTimeObserver = nil;
    self.currentPlayerItem = nil;
}

- (void)addObserver {
    
    [self.currentPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [self.currentPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [self.currentPlayerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [self.currentPlayerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.currentPlayerItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemPlaybackStalled:) name:AVPlayerItemPlaybackStalledNotification object:self.currentPlayerItem];
}


- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView {
    
    [self.player pause];
    [self releasePlayer];
    self.isPauseByUser = NO;
    self.loadedProgress = 0;
    self.duration = 0;
    self.current = 0;
    self.showView = showView;
    NSString *str = [url absoluteString];
    if (IOS_VERSION < 7.0 || ![str hasPrefix:@"http"]) {//如果是ios  < 7 或者是本地资源，直接播放
        
        self.videoAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:self.videoAsset];
        if (!self.player) {
            
            self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
        } else {
            
            [self.player replaceCurrentItemWithPlayerItem:self.currentPlayerItem];
        }
        self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.currentPlayerLayer.frame = CGRectMake(0, 44, showView.bounds.size.width, showView.bounds.size.height-44);
        self.isLocalVideo = YES;
    } else {//ios7以上采用resourceLoader给播放器补充数据
        
        self.resouerLoader = [[LHLoaderURLConnection alloc] init];
        self.resouerLoader.delegate = self;
        NSURL *playUrl = [self.resouerLoader getSchemeVideoURL:url];
        self.videoURLAsset = [AVURLAsset URLAssetWithURL:playUrl options:nil];
        [self.videoURLAsset.resourceLoader setDelegate:self.resouerLoader queue:dispatch_get_main_queue()];
        self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:self.videoURLAsset];
        if (!self.player) {
            
            self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
        } else {
            
            [self.player replaceCurrentItemWithPlayerItem:self.currentPlayerItem];
        }
        self.currentPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.currentPlayerLayer.frame = CGRectMake(0, 44, showView.bounds.size.width, showView.bounds.size.height-44);
        self.isLocalVideo = NO;
    }
    [showView.layer addSublayer:self.currentPlayerLayer];
    [self addObserver];
    if ([url.scheme isEqualToString:@"file"]) {// 本地文件不设置LHPlayerStateBuffering状态
        
        if (self.state == LHPlayerStatePlaying) {//如果已经在LHPlayerStatePlaying，则直接发通知，否则设置状态
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kLHPlayerStateChangedNotification object:nil];
        } else {
            
            self.state = LHPlayerStatePlaying;
        }
    } else {
    
        if (self.state == LHPlayerStateBuffering) {//如果已经在LHPlayerStateBuffering，则直接发通知，否则设置状态
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kLHPlayerStateChangedNotification object:nil];
        } else {
          
            self.state = LHPlayerStateBuffering;
        }
    }
    if (!_navBar) {
        
        _navBar = [[UIView alloc] init];
        [showView addSubview:_navBar];
    }
    [self buildVideoNavBar];
    [[LHHudHelper sharedInstance] showHudOnView:_showView caption:nil image:nil acitivity:YES autoHideTime:0];
    [[NSNotificationCenter defaultCenter] postNotificationName:kLHPlayerProgressChangedNotification object:nil];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(halfScreen)];
    [showView addGestureRecognizer:tap];
}

- (void)fullScreen {
    
    self.navBar.hidden = YES;
    self.currentPlayerLayer.transform = CATransform3DMakeRotation(M_PI/2, 0, 0, 1);
    self.currentPlayerLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
}

- (void)halfScreen {
    
    self.navBar.hidden = NO;
    self.currentPlayerLayer.transform = CATransform3DIdentity;
    self.currentPlayerLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
}

- (void)seekToTime:(CGFloat)seconds {
    
    if (self.state == LHPlayerStateStopped) {
    
        return;
    }
    seconds = MAX(0, seconds);
    seconds = MIN(seconds, self.duration);
    [self.player pause];
    [self.player seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
        
        self.isPauseByUser = NO;
        [self.player play];
        if (!self.currentPlayerItem.isPlaybackLikelyToKeepUp) {
            
            self.state = LHPlayerStateBuffering;
            [[LHHudHelper sharedInstance] showHudOnView:_showView caption:nil image:nil acitivity:YES autoHideTime:0];
        }
    }];
}

- (void)resumeOrPause {
    
    if (!self.currentPlayerItem) {
    
        return;
    }
    if (self.state == LHPlayerStatePlaying) {
        
        [self.player pause];
        self.state = LHPlayerStatePause;
    } else if (self.state == LHPlayerStatePause) {
        
        [self.player play];
        self.state = LHPlayerStatePlaying;
    }
    [self setStopBtnImage];
    self.isPauseByUser = YES;
}

- (void)resume {
    
    if (!self.currentPlayerItem) {
    
        return;
    }
    [self setStopBtnImage];
    self.isPauseByUser = NO;
    [self.player play];
}

- (void)pause {
    
    if (!self.currentPlayerItem) {
    
        return;
    }
    [self setStopBtnImage];
    self.isPauseByUser = YES;
    self.state = LHPlayerStatePause;
    [self.player pause];
}

- (void)setStopBtnImage {
    
    [_stopButton setImage:[UIImage imageNamed:@"icon_play"] forState:UIControlStateNormal];
    [_stopButton setImage:[UIImage imageNamed:@"icon_play_hl"] forState:UIControlStateHighlighted];
}


- (void)stop {
    
    self.isPauseByUser = YES;
    self.loadedProgress = 0;
    self.duration = 0;
    self.current  = 0;
    self.state = LHPlayerStateStopped;
    [self.player pause];
    [self releasePlayer];
    [[NSNotificationCenter defaultCenter] postNotificationName:kLHPlayerProgressChangedNotification object:nil];
}


- (CGFloat)progress {
    
    if (self.duration > 0) {
        
        return self.current / self.duration;
    }
    return 0;
}


#pragma mark - 观察者回调

- (void)appDidEnterBackground {
    
    if (self.stopWhenAppDidEnterBackground) {
    
        [self pause];
        self.state = LHPlayerStatePause;
        self.isPauseByUser = NO;
    }
}

- (void)appDidEnterPlayGround {
    
    if (!self.isPauseByUser) {
    
        [self resume];
        self.state = LHPlayerStatePlaying;
    }
}

- (void)playerItemDidPlayToEnd:(NSNotification *)notification {
    
    [self stop];
}

//在监听播放器状态中处理比较准确
- (void)playerItemPlaybackStalled:(NSNotification *)notification {
    
    // 这里网络不好的时候，就会进入，不做处理，会在playbackBufferEmpty里面缓存之后重新播放
    NSLog(@"buffing-----buffing");
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:@"status"]) {
        
        if ([playerItem status] == AVPlayerStatusReadyToPlay) {
            
            [self monitoringPlayback:playerItem];// 给播放器添加计时器
            
        } else if ([playerItem status] == AVPlayerStatusFailed || [playerItem status] == AVPlayerStatusUnknown) {
            
            [self stop];
        }
        
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {  //监听播放器的下载进度
        
        [self calculateDownloadProgress:playerItem];
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) { //监听播放器在缓冲数据的状态
        
        [[LHHudHelper sharedInstance] showHudOnView:_showView caption:nil image:nil acitivity:YES autoHideTime:0];
        if (playerItem.isPlaybackBufferEmpty) {
            
            self.state = LHPlayerStateBuffering;
            [self bufferingSomeSecond];
        }
    }
}

- (void)monitoringPlayback:(AVPlayerItem *)playerItem {
    
    self.duration = playerItem.duration.value / playerItem.duration.timescale; //视频总时间
    [self.player play];
    [self updateTotolTime:self.duration];
    [self setPlaySliderValue:self.duration];
    
    __weak __typeof(self)weakSelf = self;
    self.playbackTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        CGFloat current = playerItem.currentTime.value / playerItem.currentTime.timescale;
        [strongSelf updateCurrentTime:current];
        [strongSelf updateVideoSlider:current];
        if (strongSelf.isPauseByUser == NO) {
            
            strongSelf.state = LHPlayerStatePlaying;
        }
        
        // 不相等的时候才更新，并发通知，否则seek时会继续跳动
        if (strongSelf.current != current) {
            
            strongSelf.current = current;
            if (strongSelf.current > strongSelf.duration) {
                
                strongSelf.duration = strongSelf.current;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kLHPlayerProgressChangedNotification object:nil];
        }
        
    }];
    
}

- (void)calculateDownloadProgress:(AVPlayerItem *)playerItem {
    
    NSArray *loadedTimeRanges = [playerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval timeInterval = startSeconds + durationSeconds;// 计算缓冲总进度
    CMTime duration = playerItem.duration;
    CGFloat totalDuration = CMTimeGetSeconds(duration);
    self.loadedProgress = timeInterval / totalDuration;
    [self.videoProgressView setProgress:timeInterval / totalDuration animated:YES];
}

- (void)bufferingSomeSecond {
    
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
    static BOOL isBuffering = NO;
    if (isBuffering) {
        
        return;
    }
    isBuffering = YES;
    // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
    [self.player pause];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 如果此时用户已经暂停了，则不再需要开启播放了
        if (self.isPauseByUser) {
            
            isBuffering = NO;
            return;
        }
        
        [self.player play];
        // 如果执行了play还是没有播放则说明还没有缓存好，则再次缓存一段时间
        isBuffering = NO;
        if (!self.currentPlayerItem.isPlaybackLikelyToKeepUp) {
            
            [self bufferingSomeSecond];
        }
    });
}

- (void)setLoadedProgress:(CGFloat)loadedProgress {
    
    if (_loadedProgress == loadedProgress) {
        return;
    }
    
    _loadedProgress = loadedProgress;
    [[NSNotificationCenter defaultCenter] postNotificationName:kLHPlayerLoadProgressChangedNotification object:nil];
}

- (void)setState:(LHPlayerState)state {
    
    if (state != LHPlayerStateBuffering) {
    
        [[LHHudHelper sharedInstance] hideHud];
    }
    if (_state == state) {
        
        return;
    }
    _state = state;
    [[NSNotificationCenter defaultCenter] postNotificationName:kLHPlayerStateChangedNotification object:nil];
    
}


#pragma mark - UI界面
- (void)buildVideoNavBar {
    
    self.navBar.backgroundColor = [self colorWithHex:0x000000 alpha:0.5];
    self.navBar.frame = CGRectMake(0, 0, kScreenWidth, 44);
    if (!self.currentTimeLabel) {
        
        self.currentTimeLabel = [[UILabel alloc] init];
        self.currentTimeLabel.textColor = [self colorWithHex:0xffffff alpha:1.0];
        self.currentTimeLabel.font = [UIFont systemFontOfSize:10.0];
        self.currentTimeLabel.frame = CGRectMake(30, 0, 52, 44);
        self.currentTimeLabel.textAlignment = NSTextAlignmentRight;
        [self.navBar addSubview:self.currentTimeLabel];
    }
    if (!self.totolTimeLabel) {
        
        self.totolTimeLabel = [[UILabel alloc] init];
        self.totolTimeLabel.textColor = [self colorWithHex:0xffffff alpha:1.0];
        self.totolTimeLabel.font = [UIFont systemFontOfSize:10.0];
        self.totolTimeLabel.frame = CGRectMake(kScreenWidth-52-15, 0, 52, 44);
        self.totolTimeLabel.textAlignment = NSTextAlignmentLeft;
        [self.navBar addSubview:self.totolTimeLabel];
    }
    if (!self.videoProgressView) {
        
        self.videoProgressView = [[UIProgressView alloc] init];
        self.videoProgressView.progressTintColor = [self colorWithHex:0xffffff alpha:1.0];  //填充部分颜色
        self.videoProgressView.trackTintColor = [self colorWithHex:0xffffff alpha:0.18];   // 未填充部分颜色
        self.videoProgressView.frame = CGRectMake(62+30, 21, kScreenWidth-124-44, 20);
        self.videoProgressView.layer.cornerRadius = 1.5;
        self.videoProgressView.layer.masksToBounds = YES;
        CGAffineTransform transform = CGAffineTransformMakeScale(1.0, 1.5);
        self.videoProgressView.transform = transform;
        [self.navBar addSubview:self.videoProgressView];
    }
    if (!self.playSlider) {
        
        self.playSlider = [[UISlider alloc] init];
        self.playSlider.frame = CGRectMake(62+30, 0, kScreenWidth-124-44, 44);
        [self.playSlider setThumbImage:[UIImage imageNamed:@"icon_progress"] forState:UIControlStateNormal];
        self.playSlider.minimumTrackTintColor = [UIColor clearColor];
        self.playSlider.maximumTrackTintColor = [UIColor clearColor];
        [self.playSlider addTarget:self action:@selector(playSliderChange:) forControlEvents:UIControlEventValueChanged]; //拖动滑竿更新时间
        [self.playSlider addTarget:self action:@selector(playSliderChangeEnd:) forControlEvents:UIControlEventTouchUpInside];  //松手,滑块拖动停止
        [self.playSlider addTarget:self action:@selector(playSliderChangeEnd:) forControlEvents:UIControlEventTouchUpOutside];
        [self.playSlider addTarget:self action:@selector(playSliderChangeEnd:) forControlEvents:UIControlEventTouchCancel];
        [self.navBar addSubview:self.playSlider];
    }
    if (!self.stopButton) {
        
        self.stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.stopButton.frame = CGRectMake(0, 0, 44, 44);
        [self.stopButton addTarget:self action:@selector(resumeOrPause) forControlEvents:UIControlEventTouchUpInside];
        [self.stopButton setImage:[UIImage imageNamed:@"icon_pause"] forState:UIControlStateNormal];
        [self.stopButton setImage:[UIImage imageNamed:@"icon_pause_hl"] forState:UIControlStateHighlighted];
        [self.navBar addSubview:self.stopButton];
    }
    if (!self.screenBUtton) {
     
        self.screenBUtton = [[UIButton alloc] init];
        self.screenBUtton.frame = CGRectMake(kScreenWidth - 40, 0, 44, 44);
        [self.screenBUtton addTarget:self action:@selector(fullScreen) forControlEvents:UIControlEventTouchUpInside];
        [self.screenBUtton setImage:[UIImage imageNamed:@"quanping"] forState:UIControlStateNormal];
        [self.screenBUtton setImage:[UIImage imageNamed:@"quanping"] forState:UIControlStateHighlighted];
        [self.navBar addSubview:self.screenBUtton];
    }
    
}
//手指结束拖动，播放器从当前点开始播放，开启滑竿的时间走动
- (void)playSliderChangeEnd:(UISlider *)slider {
    
    [self seekToTime:slider.value];
    [self updateCurrentTime:slider.value];
    [self setStopBtnImage];
}

//手指正在拖动，播放器继续播放，但是停止滑竿的时间走动
- (void)playSliderChange:(UISlider *)slider {
    
    [self updateCurrentTime:slider.value];
}

#pragma mark - 控件拖动
- (void)setPlaySliderValue:(CGFloat)time {
    
    self.playSlider.minimumValue = 0.0;
    self.playSlider.maximumValue = (NSInteger)time;
}

- (void)updateCurrentTime:(CGFloat)time {
    
    long videocurrent = ceil(time);
    NSString *str = nil;
    if (videocurrent < 3600) {
        
        str =  [NSString stringWithFormat:@"%02li:%02li",lround(floor(videocurrent/60.f)),lround(floor(videocurrent/1.f))%60];
    } else {
        
        str =  [NSString stringWithFormat:@"%02li:%02li:%02li",lround(floor(videocurrent/3600.f)),lround(floor(videocurrent%3600)/60.f),lround(floor(videocurrent/1.f))%60];
    }
    self.currentTimeLabel.text = str;
}

- (void)updateTotolTime:(CGFloat)time {
    
    long videoLenth = ceil(time);
    NSString *strtotol = nil;
    if (videoLenth < 3600) {
    
        strtotol =  [NSString stringWithFormat:@"%02li:%02li",lround(floor(videoLenth/60.f)),lround(floor(videoLenth/1.f))%60];
    } else {
        
        strtotol =  [NSString stringWithFormat:@"%02li:%02li:%02li",lround(floor(videoLenth/3600.f)),lround(floor(videoLenth%3600)/60.f),lround(floor(videoLenth/1.f))%60];
    }
    self.totolTimeLabel.text = strtotol;
}

- (void)updateVideoSlider:(CGFloat)currentSecond {

    [self.playSlider setValue:currentSecond animated:YES];
}


#pragma mark - LHloaderURLConnectionDelegate

- (void)didFinishLoadingWithTask:(LHVideoRequestTask *)task {
    
    self.isFinishLoad = task.isFinishLoad;
}

//网络中断：-1005
//无网络连接：-1009
//请求超时：-1001
//服务器内部错误：-1004
//找不到服务器：-1003
- (void)didFailLoadingWithTask:(LHVideoRequestTask *)task withError:(NSInteger)errorCode {
    
    NSString *str = nil;
    switch (errorCode) {
        case -1001:
            str = @"请求超时";
            break;
        case -1003:
        case -1004:
            str = @"服务器错误";
            break;
        case -1005:
            str = @"网络中断";
            break;
        case -1009:
            str = @"无网络连接";
            break;
            
        default:
            str = [NSString stringWithFormat:@"%@", @"(_errorCode)"];
            break;
    }
    [LHHudHelper showMessage:str];
}

#pragma mark - color
- (UIColor*)colorWithHex:(NSInteger)hexValue alpha:(CGFloat)alphaValue {
    
    return [UIColor colorWithRed:((float)((hexValue & 0xFF0000) >> 16))/255.0
                           green:((float)((hexValue & 0xFF00) >> 8))/255.0
                            blue:((float)(hexValue & 0xFF))/255.0
                           alpha:alphaValue];
}

@end

