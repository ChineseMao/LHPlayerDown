//
//  LHVideoRequestTask.m
//  LHPlayerDown
//
//  Created by 刘虎 on 16/6/16.
//  Copyright © 2016年 liuhu. All rights reserved.
//

#import "LHVideoRequestTask.h"

@interface LHVideoRequestTask ()<NSURLConnectionDataDelegate, AVAssetResourceLoaderDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) NSUInteger offset;
@property (nonatomic, assign) NSUInteger videoLength;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableArray *taskArr;
@property (nonatomic, assign) NSUInteger downLoadingOffset;
@property (nonatomic, assign) BOOL once;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSString *tempPath;

@end


@implementation LHVideoRequestTask

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
        self.taskArr = [[NSMutableArray alloc] init];
        NSString *document = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        self.tempPath = [document stringByAppendingPathComponent:@"temp.mp4"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.tempPath]) {
            
            [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
            [[NSFileManager defaultManager] createFileAtPath:self.tempPath contents:nil attributes:nil];
        } else {
            
            [[NSFileManager defaultManager] createFileAtPath:self.tempPath contents:nil attributes:nil];
        }
    }
    return self;
}

- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset {
    
    self.url = url;
    self.offset = offset;
    if (self.taskArr.count >= 1) {//如果是建立第二次请求，先移除原文件，在创建新的
        
        [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
        [[NSFileManager defaultManager] createFileAtPath:self.tempPath contents:nil attributes:nil];
    }
    self.downLoadingOffset = 0;
    NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    actualURLComponents.scheme = @"http";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[actualURLComponents URL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    if (offset > 0 && self.videoLength > 0) {
        
        [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld",(unsigned long)offset, (unsigned long)self.videoLength - 1] forHTTPHeaderField:@"Range"];
    }
    [self.connection cancel];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection setDelegateQueue:[NSOperationQueue mainQueue]];
    [self.connection start];
}


- (void)cancel {
    
    [self.connection cancel];
}


#pragma mark - NSURLConnection的代理方法
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    self.isFinishLoad = NO;
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *dic = (NSDictionary *)[httpResponse allHeaderFields];
    NSString *content = [dic valueForKey:@"Content-Range"];
    NSArray *array = [content componentsSeparatedByString:@"/"];
    NSString *length = array.lastObject;
    NSUInteger videoLength;
    if ([length integerValue] == 0) {
        
        videoLength = (NSUInteger)httpResponse.expectedContentLength;
    } else {
        
        videoLength = [length integerValue];
    }
    self.videoLength = videoLength;
    self.mimeType = @"video/mp4";
    if ([self.delegate respondsToSelector:@selector(task:didReceiveVideoLength:mimeType:)]) {
        
        [self.delegate task:self didReceiveVideoLength:self.videoLength mimeType:self.mimeType];
    }
    [self.taskArr addObject:connection];
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.tempPath];
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:data];
    self.downLoadingOffset += data.length;
    if ([self.delegate respondsToSelector:@selector(didReceiveVideoDataWithTask:)]) {
        
        [self.delegate didReceiveVideoDataWithTask:self];
    }
}



- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    if (self.taskArr.count < 2) {
        
        self.isFinishLoad = YES;
        //这里自己写需要保存数据的路径(建议使用数据库)
        NSString *movePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        movePath = [movePath stringByAppendingPathComponent:@"保存数据.mp4"];
        BOOL isSuccess = [[NSFileManager defaultManager] moveItemAtPath:self.tempPath toPath:movePath error:nil];
        if (isSuccess) {
            
            NSLog(@"rename success");
        } else {
            
            NSLog(@"rename fail");
        }
        NSLog(@"==========================================");
        NSLog(@"%@", movePath);
        NSLog(@"==========================================");
    }
    if ([self.delegate respondsToSelector:@selector(didFinishLoadingWithTask:)]) {
        
        [self.delegate didFinishLoadingWithTask:self];
    }
}


/*
 网络中断：-1005
 无网络连接：-1009
 请求超时：-1001
 服务器内部错误：-1004
 找不到服务器：-1003
 */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    if (error.code == -1001 && !_once) {//网络连接失败，重新连接一次
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [self continueLoading];
        });
    }
    if ([self.delegate respondsToSelector:@selector(didFailLoadingWithTask:withError:)]) {
        
        [self.delegate didFailLoadingWithTask:self withError:error.code];
    }
    if (error.code == -1009) {
        
        NSLog(@"无网络连接");
    }
}

- (void)continueLoading {
    
    self.once = YES;
    NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:self.url resolvingAgainstBaseURL:NO];
    actualURLComponents.scheme = @"http";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[actualURLComponents URL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];
    [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld", (unsigned long)self.downLoadingOffset, (unsigned long)self.videoLength - 1] forHTTPHeaderField:@"Range"];
    [self.connection cancel];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection setDelegateQueue:[NSOperationQueue mainQueue]];
    [self.connection start];
}

- (void)clearData {
    
    [self.connection cancel];
    //移除文件
    [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
}




@end