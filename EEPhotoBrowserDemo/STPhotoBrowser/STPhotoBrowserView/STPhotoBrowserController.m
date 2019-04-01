//
//  STPhotoBrowserController.m
//  STPhotoBrowser
//
//  Created by https://github.com/STShenZhaoliang/STPhotoBrowser.git on 16/1/15.
//  Copyright © 2016年 ST. All rights reserved.
//

#import "STPhotoBrowserController.h"
#import "STPhotoBrowserView.h"
#import "STConfig.h"
#import "STIndicatorView.h"
#import "STAlertView.h"

@interface STPhotoBrowserController ()<UIScrollViewDelegate>
/** 1.内部容器视图 注意x不是0 */
@property (nonatomic, strong, nullable)UIScrollView *scrollView;
/** 2.上方分页Label */
@property (nonatomic, strong, nullable)UILabel *labelIndex;
/** 3.下方保存按钮 */
@property (nonatomic, strong, nullable)UIButton *buttonSave;
/** 4.保存时候的指示器 */
@property (nonatomic, strong, nullable)UIActivityIndicatorView *indicatorView;
/** 5.图片视图数组 */
@property (nonatomic, strong, nullable)NSMutableArray *photoBrowserViewList;

@property (nonatomic,assign) BOOL hasShowedPhotoBrowser;
@property (assign, nonatomic) BOOL shouldHideStatusBar;
@property (strong, nonatomic) UIImageView *blurBGView;
@property (assign, nonatomic) NSInteger currentPage;

@end

#define Width           [UIScreen mainScreen].bounds.size.width
#define Height          [UIScreen mainScreen].bounds.size.height

@implementation STPhotoBrowserController

#pragma mark - --- lift cycle 生命周期 ---

#pragma mark show方法
+ (STPhotoBrowserController *)showFromSourceImageView:(UIImageView *)imageView imageCount:(NSInteger)imageCount currentIndex:(NSInteger)currentIndex imageURLForIndex:(ImageURLForIndex)imageURLBlock placeholderImageForIndex:(PlaceholderImageForIndex)placeholderImageBlock
{
    STPhotoBrowserController *browserVC = [[STPhotoBrowserController alloc] init];
    browserVC.sourceImageView = imageView;
    browserVC.imageCount = imageCount;
    browserVC.currentIndex = currentIndex;
    browserVC.placeholderImageBlock = placeholderImageBlock;
    browserVC.imageURLBlock = imageURLBlock;

    [browserVC show];
    return browserVC;
}

+ (STPhotoBrowserController *)showFromSourceImagesContainerView:(UIView *)sourceImagesContainerView imageCount:(NSInteger)imageCount currentIndex:(NSInteger)currentIndex imageURLForIndex:(ImageURLForIndex)imageURLBlock placeholderImageForIndex:(PlaceholderImageForIndex)placeholderImageBlock
{
    STPhotoBrowserController *browserVC = [[STPhotoBrowserController alloc] init];
    browserVC.sourceImagesContainerView = sourceImagesContainerView;
    browserVC.imageCount = imageCount;
    browserVC.currentIndex = currentIndex;
    browserVC.placeholderImageBlock = placeholderImageBlock;
    browserVC.imageURLBlock = imageURLBlock;
    
    [browserVC show];
    return browserVC;
}

//UIWindow *window;
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    // 1.设置背景色
    [self.view setBackgroundColor:[UIColor clearColor]];
    
    self.hasShowedPhotoBrowser = NO;
    
    // 2.添加图片
    [self.photoBrowserViewList removeAllObjects];
    for (int i = 0; i < self.imageCount; i++) {
        STPhotoBrowserView *photoBrowserView = [STPhotoBrowserView new];
        [self.photoBrowserViewList addObject:photoBrowserView];
        
        //处理单击
        __weak __typeof(self)weakSelf = self;
        photoBrowserView.singleTapBlock = ^(UITapGestureRecognizer *recognizer){
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf hidePhotoBrowser:recognizer];
        };
        
        [self.scrollView addSubview:photoBrowserView];
    }
    // 2.1 透明度变化的view
    _blurBGView = [UIImageView new];
    _blurBGView.frame = self.view.frame;
    _blurBGView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_blurBGView];
    
    [self.view addSubview:self.scrollView];
    
    // 3.添加上方标题
    if (self.imageCount > 1) {
        self.labelIndex.text = [NSString stringWithFormat:@"1/%ld", (long)self.imageCount];
        [self.labelIndex setHidden:NO];
        [_blurBGView addSubview:self.labelIndex];
    } else {
        [self.labelIndex setHidden:YES];
    }
    
    // 4.添加保存按钮
    [_blurBGView addSubview:self.buttonSave];
    
    
    [self setupImageOfImageViewForIndex:self.currentIndex];
    
    // 5.添加pan手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self.view addGestureRecognizer:pan];
    
}

UITabBarController *tabbarVC;
/** 记录进入VC时tabbar的显示状态 */
BOOL tabbarShowing;
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // 同步状态栏的显示或隐藏
    _shouldHideStatusBar = [[UIApplication sharedApplication] isStatusBarHidden];
    
    // tabBar也需要控制显示隐藏
    id vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    if ([vc isKindOfClass:[UITabBarController class]])
    {
        tabbarVC = (UITabBarController *)vc;
        tabbarShowing = !tabbarVC.tabBar.hidden;
        // 如果tababr是显示的，则隐藏
        if (tabbarShowing) {
            tabbarVC.tabBar.hidden = 1;
        }
        
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!_hasShowedPhotoBrowser) {
        [self showPhotoBrowser];
    }
    
    // viewWillAppear自动同步状态栏，此处正式隐藏状态栏
    _shouldHideStatusBar = 1;
    [self setNeedsStatusBarAppearanceUpdate];
}


- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    // 如果原本tababr是显示的，则显示
    if (tabbarShowing) {
        tabbarVC.tabBar.hidden = 0;
    }
    
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self setupFrame];
}

#pragma mark - --- Delegate 视图委托  ---

#pragma mark - 1.scrollview代理方法
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // 1.获取当前页数
    _currentPage = scrollView.contentOffset.x / scrollView.width + 0.5;
    
    if (_currentPage ==  self.imageCount || _currentPage < 0) {
        return;
    }
    
    // 2.设置标题
    self.labelIndex.text = [NSString stringWithFormat:@"%ld/%ld", (long)(_currentPage + 1), (long)self.imageCount];
    
    // 3.还原其他图片的尺寸
    if (_currentPage != self.currentIndex) {
        self.currentIndex = _currentPage;
        for (STPhotoBrowserView *photoBrowserView in scrollView.subviews) {
            if (photoBrowserView != self.photoBrowserViewList[self.currentIndex]) {
                
                photoBrowserView.scrollView.zoomScale = 1.0;
                if (ScreenWidth > ScreenHeight) {
                    photoBrowserView.imageView.origin = CGPointMake(0, 0);
                }else {
                photoBrowserView.imageView.center = photoBrowserView.scrollView.center;
                } 
            }else {
                if (ScreenWidth > ScreenHeight) {
                    photoBrowserView.imageView.origin = CGPointMake(0, 0);
                }else {
                    photoBrowserView.imageView.center = photoBrowserView.scrollView.center;
                }

                if (photoBrowserView.isLoadedImage) {
                    [self.buttonSave setTitleColor:[UIColor whiteColor]
                                          forState:UIControlStateNormal];
                    [self.buttonSave setEnabled:YES];
                }else {
                    [self.buttonSave setTitleColor:[UIColor redColor]
                                          forState:UIControlStateNormal];
                    [self.buttonSave setEnabled:NO];
                }
            }
        }
    }
    
    // 4.预加载图片数据
    NSInteger left = _currentPage - 2;
    NSInteger right = _currentPage + 2;
    left = left > 0 ? left : 0;
    right = right > self.imageCount ? self.imageCount : right;
    
    for (NSInteger i =  left; i < right; i++) {
        [self setupImageOfImageViewForIndex:i];
    }
    
}

#pragma mark - --- event response 事件相应 ---
#pragma mark - 1.保存图片
- (void)saveImage:(UIButton *)button
{
    STPhotoBrowserView *currentView = self.scrollView.subviews[self.currentIndex];

    UIImageWriteToSavedPhotosAlbum(currentView.imageView.image,
                                   self,
                                   @selector(savedPhotosAlbumWithImage:didFinishSavingWithError:contextInfo:),
                                   NULL);
    [[UIApplication sharedApplication].keyWindow addSubview:self.indicatorView];
    [self.indicatorView startAnimating];
}

- (void)changeButtonStatus
{
    [self.buttonSave setEnabled:YES];
}

#pragma mark - 2.保存到相册
- (void)savedPhotosAlbumWithImage:(UIImage *)image
         didFinishSavingWithError:(NSError *)error
                      contextInfo:(void *)contextInfo
{
    
    [self.indicatorView removeFromSuperview];
    
    STAlertView *alert = [[STAlertView alloc]init];
    if (error) {
        [alert setStyle:STAlertViewStyleError];
    }else {
        [alert setStyle:STAlertViewStyleSuccess];
    }
    [alert show];
}

//#pragma mark 启动图片浏览器【接口】
//+ (STPhotoBrowserController *_Nullable)showPhotoBrowserWithSourceImagesContainerView:(UIView *_Nullable)sourceImagesContainerView imageCount:(NSInteger)imageCount currentPage:(NSInteger)currentPage delegate:(id _Nullable )delegate
//{
//    //启动图片浏览器
//    STPhotoBrowserController *browserVC = [[STPhotoBrowserController alloc] init];
//    browserVC.sourceImagesContainerView = sourceImagesContainerView; // 原图的父控件
//    browserVC.imageCount = imageCount; // 图片总数
//    browserVC.currentIndex = currentPage;
////    browserVC.delegate = delegate;
//    [browserVC show];
//    return browserVC;
//}

#pragma mark - 3.显示图片浏览器
- (void)showPhotoBrowser
{
    NSArray *subviews = _sourceImagesContainerView.subviews;
    UIImageView *sourceView;
    
    BOOL animationEnable = 0;// 判断是否使用动画
    if (_sourceImagesContainerView) {
        if (_currentIndex < subviews.count) {
            sourceView = subviews[_currentIndex];
            animationEnable = 1;
        }
    }
    // 新增允许单图也有动画
    else if (_sourceImageView)
    {
        sourceView = _sourceImageView;
        animationEnable = 1;
    }
    
    // 使用动画
    if (animationEnable)
    {

        CGRect rect = [sourceView.superview convertRect:sourceView.frame toView:self.view.window];
        
        UIImageView *tempImageView = [[UIImageView alloc] init];
        tempImageView.frame = rect;
        // 动画的一开始，优先选用原imageView的图片，如果没有才选用代理中设置的占位图
        tempImageView.image = sourceView.image ? sourceView.image : _placeholderImageBlock(_currentPage);
        
        [self.view addSubview:tempImageView];
        tempImageView.contentMode = UIViewContentModeScaleAspectFit;
        
        CGFloat placeImageSizeW = tempImageView.image ? tempImageView.image.size.width : 100;
        CGFloat placeImageSizeH = tempImageView.image ? tempImageView.image.size.height : 100;
        CGRect targetTemp;
        
        if (!STFullWidthForLandScape) {
            if (ScreenWidth < ScreenHeight) {
                CGFloat placeHolderH = (placeImageSizeH * ScreenWidth)/placeImageSizeW;
                if (placeHolderH <= ScreenHeight) {
                    targetTemp = CGRectMake(0, (ScreenHeight - placeHolderH) * 0.5 , ScreenWidth, placeHolderH);
                } else {
                    targetTemp = CGRectMake(0, 0, ScreenWidth, placeHolderH);
                }
            } else {
                CGFloat placeHolderW = (placeImageSizeW * ScreenHeight)/placeImageSizeH;
                if (placeHolderW < ScreenWidth) {
                    targetTemp = CGRectMake((ScreenWidth - placeHolderW)*0.5, 0, placeHolderW, ScreenHeight);
                } else {
                    targetTemp = CGRectMake(0, 0, placeHolderW, ScreenHeight);
                }
            }
            
        } else {
            CGFloat placeHolderH = (placeImageSizeH * ScreenWidth)/placeImageSizeW;
            if (placeHolderH <= ScreenHeight) {
                targetTemp = CGRectMake(0, (ScreenHeight - placeHolderH) * 0.5 , ScreenWidth, placeHolderH);
            } else {
                targetTemp = CGRectMake(0, 0, ScreenWidth, placeHolderH);
            }
        }
        
        self.scrollView.hidden = YES;
        self.labelIndex.hidden = YES;
        self.buttonSave.hidden = YES;

        [UIView animateWithDuration:0.3 animations:^{
            tempImageView.frame = targetTemp;
        } completion:^(BOOL finished) {
            [tempImageView removeFromSuperview];
            self.hasShowedPhotoBrowser = YES;
            self.scrollView.hidden = NO;
            self.labelIndex.hidden = NO;
            self.buttonSave.hidden = NO;
        }];
    }
    // 取不到就不用动画
    else
    {
        self.hasShowedPhotoBrowser = YES;
        self.scrollView.hidden = NO;
        self.labelIndex.hidden = NO;
        self.buttonSave.hidden = NO;
    }
    
}

#pragma mark - 单击事件 - dismiss
- (void)hidePhotoBrowser:(UITapGestureRecognizer *)recognizer
{
    STPhotoBrowserView *photoBrowserView = (STPhotoBrowserView *)recognizer.view;
    [self dismissPhotoBrowserWithPhotoView:photoBrowserView];
    
}

#pragma mark 隐藏图片浏览器
- (void)dismissPhotoBrowserWithPhotoView:(STPhotoBrowserView *)photoBrowserView
{
    UIImageView *currentImageView = photoBrowserView.imageView;
    NSArray *subviews = self.sourceImagesContainerView.subviews;
    UIView *sourceView;
    
    // 需要使用动画时，判断是否确实满足使用动画的条件
    BOOL animationEnable = 0;
    
        if (_sourceImagesContainerView) {
            if (_currentIndex < subviews.count) {
                sourceView = subviews[_currentIndex];
                animationEnable = 1;
            }
        }
        // 新增允许单图也有动画
        else if (_sourceImageView)
        {
            sourceView = _sourceImageView;
            animationEnable = 1;
        }
    
    
    // 动画
    if (animationEnable)
    {
        CGRect targetRect = [sourceView.superview convertRect:sourceView.frame toView:self.view.window];

        /** 替身 */
        UIImageView *tempImageView = [[UIImageView alloc] init];
        tempImageView.image = currentImageView.image;
        
        if (tempImageView.image)
        {
            
        }
        else
        {
            tempImageView.backgroundColor = [UIColor clearColor];
        }
        
        tempImageView.frame = [currentImageView.superview convertRect:currentImageView.frame toView:self.view.window];
        
        // 隐藏动画优化
        tempImageView.contentMode = UIViewContentModeScaleAspectFill;
        tempImageView.clipsToBounds = 1;
        [self.view.window addSubview:tempImageView];
        
        // 真身撤 替身上
        [self.scrollView removeFromSuperview];
        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
                             
                             tempImageView.frame = targetRect;
                             self.blurBGView.alpha = 0;
                             
                         } completion:^(BOOL finished) {
                             
                             [tempImageView removeFromSuperview];
                             [self dismissViewControllerAnimated:NO completion:nil];
                         }];
    }
    else
    {
        [self dismissViewControllerAnimated:0 completion:nil];
    }
}

#pragma mark - --- private methods 私有方法 ---

#pragma mark - 1.显示视图
- (void)show
{
    self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    UIViewController *oldVC = [STPhotoBrowserController theTopVC];
    
    [oldVC.view endEditing:1];// 隐藏键盘
    oldVC.definesPresentationContext = YES;
    [oldVC presentViewController:self animated:0 completion:nil];
}

#pragma mark - 2.屏幕方向
- (BOOL)shouldAutorotate
{
    return STSupportLandscape;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (STSupportLandscape) {
        return UIInterfaceOrientationMaskAll;
    }else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

#pragma mark - 3.隐藏状态栏
- (BOOL)prefersStatusBarHidden
{
    return _shouldHideStatusBar;
}

#pragma mark - 4.设置视图的框架
- (void)setupFrame
{
    CGRect rectSelf = self.view.bounds;
    rectSelf.size.width += STMargin * 2;
    // 为了做出间距，scrollView其实比view大一点
    self.scrollView.bounds = rectSelf;
    self.scrollView.center = CGPointMake(ScreenWidth / 2, ScreenHeight / 2);
    
    
    __block CGFloat photoX = 0;
    __block CGFloat photoY = 0;
    __block CGFloat photoW = ScreenWidth;
    __block CGFloat photoH = ScreenHeight;
    [self.scrollView.subviews enumerateObjectsUsingBlock:^(__kindof STPhotoBrowserView * _Nonnull obj,
                                                           NSUInteger idx,
                                                           BOOL * _Nonnull stop) {
        photoX = STMargin + idx * (STMargin * 2 + photoW);
        [obj setFrame:CGRectMake(photoX, photoY, photoW, photoH)];
        
    }];
    
    self.scrollView.contentSize = CGSizeMake(self.scrollView.subviews.count * self.scrollView.width,
                                             ScreenHeight);
    self.scrollView.contentOffset = CGPointMake(self.currentIndex * self.scrollView.width, 0);
    
    
    CGFloat indexW = 66;
    CGFloat indexH = 28;
    CGFloat indexCenterX = ScreenWidth / 2;
    CGFloat indexCenterY = indexH / 2 + STMarginBig;
    
    self.labelIndex.bounds = CGRectMake(0, 0, indexW, indexH);
    self.labelIndex.center = CGPointMake(indexCenterX, indexCenterY);
    [self.labelIndex.layer setCornerRadius:indexH/2];
    
    CGFloat saveW = 40;
    CGFloat saveH = 28;
    CGFloat saveX = STMarginBig;
    CGFloat saveY = ScreenHeight - saveH - STMarginBig;
    self.buttonSave.frame = CGRectMake(saveX, saveY, saveW, saveH);
}

#pragma mark - 5.加载视图的图片
- (void)setupImageOfImageViewForIndex:(NSInteger)index
{
    NSArray *subviews = self.scrollView.subviews;
    STPhotoBrowserView *photoBrowserView = subviews[index];
    if (photoBrowserView.beginLoadingImage) return;
    // 未传入URL 则使用本地图片
    if (_imageURLBlock(index)) {
        [photoBrowserView setImageWithURL:_imageURLBlock(index)
                         placeholderImage:_placeholderImageBlock(index)];
    } else {
        photoBrowserView.imageView.image = _placeholderImageBlock(index);
    }
    photoBrowserView.beginLoadingImage = YES;
}

//#pragma mark - 6.获取低分辨率（占位）图片
//- (UIImage *)placeholderImageForIndex:(NSInteger)index
//{
//    if ([self.delegate respondsToSelector:@selector(photoBrowser:placeholderImageForIndex:)]) {
//        return [self.delegate photoBrowser:self placeholderImageForIndex:index];
//    }
//    return nil;
//}

//#pragma mark - 7.获取高分辨率图片url
//- (NSURL *)highQualityImageURLForIndex:(NSInteger)index
//{
//    //    self.currentPage = index;
//    if ([self.delegate respondsToSelector:@selector(photoBrowser:highQualityImageURLForIndex:)]) {
//        return [self.delegate photoBrowser:self highQualityImageURLForIndex:index];
//    }
//    return nil;
//}

#pragma mark - --- getters and setters 属性 ---

#pragma mark - 1.内部容器视图
- (UIScrollView *)scrollView
{
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc]initWithFrame:self.view.bounds];
        [_scrollView setDelegate:self];
        [_scrollView setShowsHorizontalScrollIndicator:NO];
        [_scrollView setShowsVerticalScrollIndicator:NO];
        [_scrollView setPagingEnabled:YES];
        [_scrollView setHidden:YES];
    }
    return _scrollView;
}

#pragma mark - 2.上方分页Label
- (UILabel *)labelIndex
{
    if (!_labelIndex) {
        _labelIndex = [[UILabel alloc]init];
        [_labelIndex setBackgroundColor:RGBA(0, 0, 0, 50.0/255)];
        [_labelIndex setTextAlignment:NSTextAlignmentCenter];
        [_labelIndex setTextColor:[UIColor whiteColor]];
        [_labelIndex setFont:[UIFont boldSystemFontOfSize:17]];
        
        [_labelIndex setClipsToBounds:YES];
        [_labelIndex setShadowOffset:CGSizeMake(0, -0.5)];
        [_labelIndex setShadowColor:RGBA(0, 0, 0, 110.0/255)];
    }
    return _labelIndex;
}

#pragma mark - 3.下方保存按钮
- (UIButton *)buttonSave
{
    if (!_buttonSave) {
        _buttonSave = [[UIButton alloc]init];
        [_buttonSave setBackgroundColor:RGBA(0, 0, 0, 50.0/255)];
        [_buttonSave setTitle:@"保存" forState:UIControlStateNormal];
        [_buttonSave setTitleColor:[UIColor whiteColor]
                          forState:UIControlStateNormal];
        [_buttonSave.titleLabel setFont:[UIFont systemFontOfSize:14]];
        
        [_buttonSave setClipsToBounds:YES];
        [_buttonSave.layer setCornerRadius:2];
        [_buttonSave.layer setBorderWidth:0.5];
        [_buttonSave.layer setBorderColor:RGBA(255, 255, 255, 60.0/255).CGColor];
        [_buttonSave addTarget:self
                        action:@selector(saveImage:)
              forControlEvents:UIControlEventTouchUpInside];
    }
    return _buttonSave;
}

#pragma mark - 4.保存时候的指示器
- (UIActivityIndicatorView *)indicatorView
{
    if (!_indicatorView) {
        _indicatorView = [[UIActivityIndicatorView alloc]init];
        [_indicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [_indicatorView setCenter:self.view.center];
        [_indicatorView setBackgroundColor:[UIColor redColor]];
    }
    return _indicatorView;
}

#pragma mark - 5.图片视图数组
- (NSMutableArray *)photoBrowserViewList
{
    if (!_photoBrowserViewList) {
        _photoBrowserViewList = [NSMutableArray array];
    }
    return _photoBrowserViewList;
}

//_______________________________________________________________________________________________________________
CGPoint     _panGestureBeginPoint;
CGRect      _panGestureBeginBounds;

#pragma mark - ......::::::: pan手势 :::::::......
- (void)pan:(UIPanGestureRecognizer *)gesture {
    
    UIView *theView = self.view;
    STPhotoBrowserView *photoBrowserView = _scrollView.subviews[_currentIndex];
    // 计算alpha
    CGPoint p = [gesture locationInView:theView];
    CGFloat changeY = p.y - _panGestureBeginPoint.y;
    CGFloat changeX = p.x - _panGestureBeginPoint.x;
    CGFloat alphaDelta = 160;
    CGFloat alpha = (alphaDelta - fabs(changeY) + 50) / alphaDelta;
    CGFloat minAlpha = 0.4;
    alpha = alpha > minAlpha ? alpha : minAlpha;
    
    CGFloat scale = 1 - fabs(changeY / Height);

    switch (gesture.state) {
            
        // pan开始
        case UIGestureRecognizerStateBegan:{
            
            _panGestureBeginPoint = [gesture locationInView:theView];
            _panGestureBeginBounds = _scrollView.bounds;
            
        } break;
            
        // pan变化
        case UIGestureRecognizerStateChanged: {
            
            // 修改缩放程度和位移
            photoBrowserView.scrollView.minimumZoomScale = 0;// 改为0才可以减小缩放等级
            [photoBrowserView.scrollView setZoomScale:scale animated:1];
            
            _blurBGView.alpha = alpha;
            _scrollView.top = changeY;
            // y轴变化到一定值以后才能产生x轴位移
            if (fabs(changeY) > 10)
            {
                _scrollView.centerX = Width/2 + changeX;
            }
            
        } break;
            
        // pan结束
        case UIGestureRecognizerStateEnded: {
            
            // 达到关闭的临界值
            if (alpha <= minAlpha)
            {
                // 判断使用哪个过渡隐藏动画
                if (_sourceImagesContainerView || _sourceImageView)
                {
                    [self dismissPhotoBrowserWithPhotoView:_photoBrowserViewList[_currentPage]];
                }
                else
                {
                    // 向上或向下隐藏的动画
                    [UIView animateWithDuration:0.2 animations:^{
                        
                        // 向上隐藏
                        if (self.scrollView.top < 0)
                        {
                            self.scrollView.bottom = 0;
                        }
                        // 向下隐藏
                        else
                        {
                            self.scrollView.top = self.scrollView.height;
                        }
                        self.blurBGView.alpha = 0;// 黑色渐变透明
                        
                        
                    } completion:^(BOOL finished) {
                        
                        [self dismissPhotoBrowserWithPhotoView:self.photoBrowserViewList[self.currentPage]];
                    }];
                }
            }
            // 还原
            else
            {
                [UIView animateWithDuration:0.4 animations:^{
                    self.scrollView.center = CGPointMake(ScreenWidth / 2, ScreenHeight / 2);
                    [photoBrowserView.scrollView setZoomScale:1 animated:1];
                    self.blurBGView.alpha = 1;
                }];
            }
        } break;
            
        // pan取消
        case UIGestureRecognizerStateCancelled : {
            
        } break;
        default:break;
    }
}


- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;// 黑色状态栏
}

#pragma mark 当前VC
+ (UIViewController *)theTopVC
{
    UIViewController* viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    return [self findTopViewController:viewController];
}

+ (UIViewController*)findTopViewController:(UIViewController*)vc {
    
    if (vc.presentedViewController) {
        
        // Return presented view controller
        return [self findTopViewController:vc.presentedViewController];
        
    } else if ([vc isKindOfClass:[UISplitViewController class]]) {
        
        // Return right hand side
        UISplitViewController* svc = (UISplitViewController*) vc;
        if (svc.viewControllers.count > 0)
            return [self findTopViewController:svc.viewControllers.lastObject];
        else
            return vc;
        
    } else if ([vc isKindOfClass:[UINavigationController class]]) {
        
        // Return top view
        UINavigationController* svc = (UINavigationController*) vc;
        if (svc.viewControllers.count > 0)
            return [self findTopViewController:svc.topViewController];
        else
            return vc;
        
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        
        // Return visible view
        UITabBarController* svc = (UITabBarController*) vc;
        if (svc.viewControllers.count > 0)
            return [self findTopViewController:svc.selectedViewController];
        else
            return vc;
        
    } else {
        
        // Unknown view controller type, return last child view controller
        return vc;
        
    }
    
}


@end

