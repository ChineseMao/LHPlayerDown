//
//  LHLoaderURLConnection.h
//  LHPlayerDown
//
//  Created by 刘虎 on 16/6/16.
//  Copyright © 2016年 liuhu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class LHVideoRequestTask;

@protocol LHLoaderURLConnectionDelegate <NSObject>

- (void)didFinishLoadingWithTask:(LHVideoRequestTask *)task;
- (void)didFailLoadingWithTask:(LHVideoRequestTask *)task withError:(NSInteger)erroeCode;

@end

/*
 本类主要完成的功能是将LHVideoRequestTask缓存在本地的临时数根据播放器的需要（offset和length）返回给播放器
 如果播放视频文件比较小，就没有必要缓存在本地，直接使用一个变量存储
 */

@interface LHLoaderURLConnection : NSURLConnection<AVAssetResourceLoaderDelegate>

@property (nonatomic, strong) LHVideoRequestTask *task;
@property (nonatomic, weak) id<LHLoaderURLConnectionDelegate> delegate;
- (NSURL *)getSchemeVideoURL:(NSURL *)url;

@end












































