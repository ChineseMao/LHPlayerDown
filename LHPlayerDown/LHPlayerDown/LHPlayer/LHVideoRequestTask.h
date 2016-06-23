//
//  LHVideoRequestTask.h
//  LHPlayerDown
//
//  Created by 刘虎 on 16/6/16.
//  Copyright © 2016年 liuhu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class LHVideoRequestTask;
@protocol LHVideoRequestTaskDelegate <NSObject>

- (void)task:(LHVideoRequestTask *)task didReceiveVideoLength:(NSUInteger)videoLength mimeType:(NSString *)mimeType;
- (void)didReceiveVideoDataWithTask:(LHVideoRequestTask *)task;
- (void)didFinishLoadingWithTask:(LHVideoRequestTask *)task;
- (void)didFailLoadingWithTask:(LHVideoRequestTask *)task withError:(NSInteger)errorCode;

@end

/*
 LHVideoRequestTask的主要功能是从网络请求数据，并把数据保存到本地的一个临时文件
 网络请求结束的时候，判断这个数据是否完整
 如果数据完整，则把数据存到指定的路径
 如果数据不完成，删除这个临时文件
 */
@interface LHVideoRequestTask : NSObject

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, assign, readonly) NSUInteger offset;
@property (nonatomic, assign, readonly) NSUInteger videoLength;
@property (nonatomic, assign, readonly) NSUInteger downLoadingOffset;
@property (nonatomic, strong, readonly) NSString *mimeType;
@property (nonatomic, assign) BOOL isFinishLoad;                            
@property (nonatomic, weak) id<LHVideoRequestTaskDelegate> delegate;



- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset;
- (void)cancel;
- (void)continueLoading;
- (void)clearData;






@end
