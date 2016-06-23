//
//  LHPlayer.h
//  LHPlayerDown
//
//  Created by 刘虎 on 16/6/16.
//  Copyright © 2016年 liuhu. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString *const kLHPlayerStateChangedNotification;
FOUNDATION_EXPORT NSString *const kLHPlayerProgressChangedNotification;
FOUNDATION_EXPORT NSString *const kLHPlayerLoadProgressChangedNotification;

//播放器的几种状态
typedef NS_ENUM(NSInteger, LHPlayerState) {
    
    LHPlayerStateBuffering = 1,
    LHPlayerStatePlaying,
    LHPlayerStateStopped,
    LHPlayerStatePause
};

@interface LHPlayer : NSObject

@property (nonatomic, readonly) LHPlayerState state;
@property (nonatomic, readonly) CGFloat loadedProgress;                 //缓冲进度
@property (nonatomic, readonly) CGFloat duration;                       //视频总时间
@property (nonatomic, readonly) CGFloat current;                        //当前播放时间
@property (nonatomic, readonly) CGFloat progress;                       //播放进度 0~1
@property (nonatomic, assign) BOOL stopWhenAppDidEnterBackground;       //默认YES

+ (instancetype)sharedInstance;
- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView;
- (void)seekToTime:(CGFloat)seconds;

- (void)resume;
- (void)pause;
- (void)stop;

- (void)fullScreen;         //全屏
- (void)halfScreen;         //半屏

@end
