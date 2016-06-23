//
//  PlayViewController.m
//  LHPlayerDown
//
//  Created by 刘虎 on 16/6/21.
//  Copyright © 2016年 liuhu. All rights reserved.
//

#import "PlayViewController.h"
#import "LHPlayer.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

@interface PlayViewController ()

@property (nonatomic, strong) UIView *showView;

@end

@implementation PlayViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    self.showView = [[UIView alloc] init];
    self.showView.backgroundColor = [UIColor redColor];
    self.showView.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    [self.view addSubview:self.showView];
    
    
    //建议使用数据库
    NSString *movePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    movePath = [movePath stringByAppendingPathComponent:@"保存数据.mp4"];
    NSURL *url = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:movePath]) {
        
        url = [NSURL fileURLWithPath:movePath];
    } else {
        
        url = [NSURL URLWithString:@"http://220.181.61.212/?prot=1&new=/29/63/qjiHfnZBRvzn6Rga6EE0C3.mp4&key=IUsOvtYvRw8QUgf_WylcB2Su5bO1mZ7T&cateCode=121115&vid=22024299&ch=my&plat=17&mkey=GH_b1EL0N6Xsp3qSvQXihcVpBojvHx8d"];
    }
    [[LHPlayer sharedInstance] playWithUrl:url showView:self.showView];
}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
}



@end
