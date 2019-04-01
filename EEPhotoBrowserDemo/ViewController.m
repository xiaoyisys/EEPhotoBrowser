//
//  ViewController.m
//  EEPhotoBrowserDemo
//
//  Created by fengyi on 2018/9/5.
//  Copyright © 2018年 fengyi. All rights reserved.
//

#import "ViewController.h"
#import "STPhotoBrowserController.h"
@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIStackView *stackView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    int i = 0;
    for (UIImageView *view in _stackView.subviews) {
        
        view.tag = 100 + i;
        view.userInteractionEnabled = 1;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
        [view addGestureRecognizer:tap];
        i++;
    }
}

- (void)tap:(UITapGestureRecognizer *)tap
{
    UIImageView *view = (UIImageView *)tap.view;
    [STPhotoBrowserController showFromSourceImagesContainerView:_stackView imageCount:4 currentIndex:view.tag-100 imageURLForIndex:^NSURL * _Nullable(NSInteger index) {
        return nil;
    } placeholderImageForIndex:^UIImage * _Nullable(NSInteger index) {
        return view.image;
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
