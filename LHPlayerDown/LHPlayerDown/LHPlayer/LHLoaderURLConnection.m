//
//  LHLoaderURLConnection.m
//  LHPlayerDown
//
//  Created by 刘虎 on 16/6/16.
//  Copyright © 2016年 liuhu. All rights reserved.
//

#import "LHloaderURLConnection.h"
#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "LHVideoRequestTask.h"

@interface LHLoaderURLConnection ()<LHVideoRequestTaskDelegate>

@property (nonatomic, strong) NSMutableArray *pendingRequests;
@property (nonatomic, copy  ) NSString       *videoPath;

@end

@implementation LHLoaderURLConnection

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
        _pendingRequests = [NSMutableArray array];
        NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
        _videoPath = [document stringByAppendingPathComponent:@"temp.mp4"];
    }
    return self;
}

- (void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest {
    
    NSString *mimeType = self.task.mimeType;
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = self.task.videoLength;
}

#pragma mark - 下载方法
/**
 *  将已经完成的请求从数组中移除移除
 */
- (void)processPendingRequests {
    
    NSMutableArray *requestsCompleted = [NSMutableArray array];
    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests) {
        
        [self fillInContentInformation:loadingRequest.contentInformationRequest];
        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest];
        if (didRespondCompletely) {
            
            [requestsCompleted addObject:loadingRequest];
            [loadingRequest finishLoading];
        }
    }
    [self.pendingRequests removeObjectsInArray:requestsCompleted];
}

/**
 *  判断当前任务下载是否完成
 *  @param dataRequest      需要判断的任务（总任务中的一个子任务）
 *  requestedOffset         当前任务最开始的偏移量
 *  currentOffset           当前任务所需完成的偏移量
 *  task.offset             总任务已经完成的偏移量
 *  task.downLoadingOffset  总任务中未完成的子任务需要完成的偏移量
 */
- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest {
    
    long long startOffset = dataRequest.requestedOffset;
    if (dataRequest.currentOffset != 0) {
        
        startOffset = dataRequest.currentOffset;
    }
    if ((self.task.offset + self.task.downLoadingOffset) < startOffset) {
        
        return NO;
    }
    if (startOffset < self.task.offset) {
        
        return NO;
    }
    NSData *filedata = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:_videoPath] options:NSDataReadingMappedIfSafe error:nil];
    NSUInteger unreadBytes = self.task.downLoadingOffset - ((NSInteger)startOffset - self.task.offset);
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
    [dataRequest respondWithData:[filedata subdataWithRange:NSMakeRange((NSUInteger)startOffset- self.task.offset, (NSUInteger)numberOfBytesToRespondWith)]];
    long long endOffset = startOffset + dataRequest.requestedLength;
    BOOL didRespondFully = (self.task.offset + self.task.downLoadingOffset) >= endOffset;
    return didRespondFully;
}


/**
 *  必须返回Yes，如果返回NO，则resourceLoader将会加载出现故障的数据
 *  这里会出现很多个loadingRequest请求， 需要为每一次请求作出处理
 *  @param resourceLoader 资源管理器
 *  @param loadingRequest 每一小块数据的请求
 *
 */
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    
    [self.pendingRequests addObject:loadingRequest];
    [self dealWithLoadingRequest:loadingRequest];
    NSLog(@"----%@", loadingRequest);
    return YES;
}


- (void)dealWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    
    NSURL *interceptedURL = [loadingRequest.request URL];
    NSRange range = NSMakeRange((NSUInteger)loadingRequest.dataRequest.currentOffset, NSUIntegerMax);
    if (self.task.downLoadingOffset > 0) {
     
        [self processPendingRequests];
    }
    if (!self.task) {
        
        self.task = [[LHVideoRequestTask alloc] init];
        self.task.delegate = self;
        [self.task setUrl:interceptedURL offset:0];
    } else {// 如果新的rang的起始位置比当前缓存的位置还大300k，则重新按照range请求数据
        
        if (self.task.offset + self.task.downLoadingOffset + 1024 * 300 < range.location ||
            range.location < self.task.offset) {// 如果往回拖也重新请求
            [self.task setUrl:interceptedURL offset:range.location];
        }
    }
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    
    [self.pendingRequests removeObject:loadingRequest];
    
}

- (NSURL *)getSchemeVideoURL:(NSURL *)url {
    
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    return [components URL];
}

#pragma mark - LHVideoRequestTaskDelegate

- (void)task:(LHVideoRequestTask *)task didReceiveVideoLength:(NSUInteger)ideoLength mimeType:(NSString *)mimeType {
    
}

- (void)didReceiveVideoDataWithTask:(LHVideoRequestTask *)task {
    
    [self processPendingRequests];
    
}

- (void)didFinishLoadingWithTask:(LHVideoRequestTask *)task {
    
    if ([self.delegate respondsToSelector:@selector(didFinishLoadingWithTask:)]) {
        
        [self.delegate didFinishLoadingWithTask:task];
    }
}

- (void)didFailLoadingWithTask:(LHVideoRequestTask *)task withError:(NSInteger)errorCode {
    
    if ([self.delegate respondsToSelector:@selector(didFailLoadingWithTask:withError:)]) {
    
        [self.delegate didFailLoadingWithTask:task withError:errorCode];
    }
    
}
@end









































