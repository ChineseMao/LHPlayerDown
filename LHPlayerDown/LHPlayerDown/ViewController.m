//
//  ViewController.m
//  LHPlayerDown
//
//  Created by 刘虎 on 16/6/16.
//  Copyright © 2016年 liuhu. All rights reserved.
//

#import "ViewController.h"
#import "PlayViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    self.navigationItem.title = @"demo";
    UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    playBtn.frame = CGRectMake(0, 0, 60, 40);
    playBtn.center = self.view.center;
    [playBtn setTitle:@"Demo" forState:UIControlStateNormal];
    [playBtn setBackgroundColor:[UIColor blackColor]];
    [playBtn addTarget:self action:@selector(presentAVPlayerViewController) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playBtn];
}


- (void)presentAVPlayerViewController {
    
    PlayViewController *playerVC = [[PlayViewController alloc] init];
    [self presentViewController:playerVC animated:YES completion:^{
        nil;
    }];
//    [self.navigationController pushViewController:avPlayerVC animated:YES];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
