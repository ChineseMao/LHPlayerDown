//
//  LHHudHelper.m
//  LHPlayerDown
//
//  Created by 刘虎 on 16/6/20.
//  Copyright © 2016年 liuhu. All rights reserved.
//

#import "LHHudHelper.h"

@implementation LHHudHelper

+ (instancetype)sharedInstance {
    
    static LHHudHelper *handle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        handle = [[LHHudHelper alloc] init];
    });
    return handle;
}

- (void)showHudAcitivityOnWindow {
    
    [self showHudOnWindow:nil image:nil acitivity:YES autoHideTime:0];
}

- (void)showHudOnWindow:(NSString *)caption image:(UIImage *)image acitivity:(BOOL)active autoHideTime:(NSTimeInterval)time1 {
    
    if (_hud) {
        [_hud hide:NO];
    }
    self.hud = [[MBProgressHUD alloc] initWithWindow:[[UIApplication sharedApplication] delegate].window];
    [[[UIApplication sharedApplication] delegate].window addSubview:self.hud];
    self.hud.labelText = caption;
    self.hud.customView = [[UIImageView alloc] initWithImage:image];
    self.hud.customView.bounds = CGRectMake(0, 0, 100, 100);
    self.hud.mode = image ? MBProgressHUDModeCustomView : MBProgressHUDModeIndeterminate;
    self.hud.animationType = MBProgressHUDAnimationFade;
    self.hud.removeFromSuperViewOnHide = YES;
    [self.hud show:YES];
    if (time1 > 0) {
        
        [self.hud hide:YES afterDelay:time1];
    }
}

- (void)showHudOnView:(UIView *)view caption:(NSString *)caption image:(UIImage *)image acitivity:(BOOL)active autoHideTime:(NSTimeInterval)time1 {
    
    if (_hud) {
        [_hud hide:NO];
    }
    self.hud = [[MBProgressHUD alloc] initWithView:view];
    [view addSubview:self.hud];
    self.hud.labelText = caption;
    self.hud.customView = [[UIImageView alloc] initWithImage:image];
    self.hud.customView.bounds = CGRectMake(0, 0, 100, 100);
    self.hud.mode = image ? MBProgressHUDModeCustomView : MBProgressHUDModeIndeterminate;
    self.hud.animationType = MBProgressHUDAnimationFade;
    [self.hud show:YES];
    if (time1 > 0) {
        
        [self.hud hide:YES afterDelay:time1];
    }
}

- (void)setCaption:(NSString *)caption {
    
    self.hud.labelText = caption;
}


- (void)hideHud {
    
    if (_hud) {
     
        [_hud hide:YES];
    }
}

- (void)hideHudAfter:(NSTimeInterval)time1 {
    
    if (_hud) {
        
        [_hud hide:YES afterDelay:time1];
    }
}


+ (void)showSuccess:(NSString *)success {
    
    [self showSuccess:success toView:nil];
}

+ (void)showError:(NSString *)error {
    
    [self showError:error toView:nil];
}

+ (void)showError:(NSString *)error toView:(UIView *)view{

    [self show:error icon:@"error.png" view:view];
}

+ (void)showSuccess:(NSString *)success toView:(UIView *)view {
    
    [self show:success icon:@"success.png" view:view];
}

#pragma mark 显示信息

+ (void)show:(NSString *)text icon:(NSString *)icon view:(UIView *)view {
    
    if (view == nil) view = [[UIApplication sharedApplication].windows lastObject];
    // 快速显示一个提示信息
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
    hud.labelText = text;
    // 设置图片
    hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:@"MBProgressHUD.bundle/%@", icon]]];
    // 再设置模式
    hud.mode = MBProgressHUDModeCustomView;
    // 隐藏时候从父控件中移除
    hud.removeFromSuperViewOnHide = YES;
    // 1.0秒之后再消失
    [hud hide:YES afterDelay:1.0];
}


+ (void)showMessage:(NSString *)message {
    
    [self show:message icon:@"" view:nil];
}

+ (void)showMessage:(NSString *)message toView:(UIView *)view {
    
    if (view == nil) view = [[UIApplication sharedApplication].windows lastObject];
    // 快速显示一个提示信息
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
    hud.labelText = message;
    // 隐藏时候从父控件中移除
    hud.removeFromSuperViewOnHide = YES;
    // 10秒之后再消失
    [hud hide:YES afterDelay:10.0];
}


+ (void)hideHUD {
    
    UIView *view = [[UIApplication sharedApplication].windows lastObject];
    [MBProgressHUD hideHUDForView:view animated:YES];
}



@end
