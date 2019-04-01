//
//  STPhotoBrowserController.h
//  STPhotoBrowser
//
//  Created by https://github.com/STShenZhaoliang/STPhotoBrowser.git on 16/1/15.
//  Copyright © 2016年 ST. All rights reserved.
//

#import <UIKit/UIKit.h>

@class STPhotoBrowserController;

@interface STPhotoBrowserController : UIViewController

typedef UIImage* _Nullable (^PlaceholderImageForIndex)(NSInteger index);
typedef NSURL *_Nullable (^ImageURLForIndex)(NSInteger index);
@property (nonatomic, copy) PlaceholderImageForIndex _Nullable placeholderImageBlock;
@property (nonatomic, copy) ImageURLForIndex _Nullable imageURLBlock;



/** 1.原图片的容器，即图片来源的父视图（为nil将取消过渡动画） */
@property ( nonatomic, weak, nullable)UIView *sourceImagesContainerView;
/** 1.1 展示原图片ImageView（为nil将取消过渡动画） */
@property ( nonatomic, weak, nullable)UIImageView *sourceImageView;
/** 2.当前的标签 */
@property (nonatomic, assign)NSInteger currentIndex;
/** 3.图片的总数目 */
@property (nonatomic, assign)NSInteger imageCount;


/**
 启动并跳转到图片浏览器 - 适用于单imageView或多个imageView分散在不同父视图中（多图能使用，区别在于浏览到其他index的图时，隐藏动画只能回到最初index的imageView处）--fy

 @param imageView 图片所在imageView（可以不传入，没动画而已）
 @param imageCount 图片总数
 @param currentIndex 当前的图片序号
 @param imageURLBlock URL数据源（block必传，数据可以return nil）
 @param placeholderImageBlock UIImage数据源（block必传，数据可以return nil）
 @return STPhotoBrowserController
 */
+ (STPhotoBrowserController *_Nonnull)showFromSourceImageView:(UIImageView *_Nullable)imageView imageCount:(NSInteger)imageCount currentIndex:(NSInteger)currentIndex imageURLForIndex:(ImageURLForIndex _Nonnull )imageURLBlock placeholderImageForIndex:(PlaceholderImageForIndex _Nonnull)placeholderImageBlock;

/**
 启动并跳转到图片浏览器 - 适用于多图（父视图有多个imageView的情况）--fy

 @param sourceImagesContainerView 多个imageView共同的父视图
 @param imageCount 图片总数
 @param currentIndex 当前的图片序号
 @param imageURLBlock URL数据源（block必传，数据可以return nil）
 @param placeholderImageBlock UIImage数据源（block必传，数据可以return nil）
 @return STPhotoBrowserController
 */

+ (STPhotoBrowserController *_Nonnull)showFromSourceImagesContainerView:(UIView *_Nullable)sourceImagesContainerView imageCount:(NSInteger)imageCount currentIndex:(NSInteger)currentIndex imageURLForIndex:(ImageURLForIndex _Nonnull )imageURLBlock placeholderImageForIndex:(PlaceholderImageForIndex _Nonnull)placeholderImageBlock;


@end
