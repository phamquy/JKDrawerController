//
//  JKDrawerController.m
//  JKDrawerControllerDemo
//
//  Created by jack on 1/6/14.
//  Copyright (c) 2014 jkorp. All rights reserved.
//

#import "JKDrawerController.h"
#import <math.h>

#pragma mark - Define Default Constant

CGFloat const JKDrawerDefaultWidth                    = 280.f;
CGFloat const JKDrawerDefaultAnimationVelocity        = 840.f;
NSTimeInterval const JKDrawerMinimumAnimationDuration = 0.15f;
CGFloat const JKDrawerDefaultBounceDistance           = 50.0f;
CGFloat const JKDrawerOvershootPercentage             = 0.1f;
CGFloat const JKDrawerOvershootLinearRangePercentage  = 0.75f;
CGFloat const JKDrawerPanVelocityXAnimationThreshold  = 200.0f;
CGFloat const JKDrawerMaxShadowOpacity                = .5f;
CGFloat const JKDrawerMaxShadowRadius                 = 3.f;
CGFloat const JKDrawerMaxCenterMaskAlpha              = 0.5;
CGSize const JKDrawerLeftShadowOffset                 = (CGSize){1,0};
CGSize const JKDrawerRightShadowOffset                 = (CGSize){-1,0};
CGSize const JKDrawerDefaultSize                      = (CGSize){270.0f, 504.f};
//------------------------------------------------------------------------------
//static CAKeyframeAnimation * bounceKeyFrameAnimationForDistanceOnView(CGFloat distance, UIView * view) {
//	CGFloat factors[32] = {0, 32, 60, 83, 100, 114, 124, 128, 128, 124, 114, 100, 83, 60, 32,
//		0, 24, 42, 54, 62, 64, 62, 54, 42, 24, 0, 18, 28, 32, 28, 18, 0};
//    
//	NSMutableArray *values = [NSMutableArray array];
//    
//	for (int i=0; i<32; i++)
//	{
//		CGFloat positionOffset = factors[i]/128.0f * distance + CGRectGetMidX(view.bounds);
//		[values addObject:@(positionOffset)];
//	}
//    
//	CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
//	animation.repeatCount = 1;
//	animation.duration = .8;
//	animation.fillMode = kCAFillModeForwards;
//	animation.values = values;
//	animation.removedOnCompletion = YES;
//	animation.autoreverses = NO;
//    
//	return animation;
//}
//------------------------------------------------------------------------------
static inline CGFloat __sizeDistance(CGSize size1, CGSize size2)
{
    CGFloat dx = ABS(size1.width - size2.width);
    CGFloat dy = ABS(size1.height - size2.height);
    CGFloat distance = sqrtf(dx*dx + dy*dy);
    
    return distance;
}
//------------------------------------------------------------------------------
static inline CGFloat __originXForDrawerOriginAndTargetOriginOffset(CGFloat originX, CGFloat targetOffset, CGFloat maxOvershoot){
    CGFloat delta = ABS(originX - targetOffset);
    CGFloat maxLinearPercentage = JKDrawerOvershootLinearRangePercentage;
    CGFloat nonLinearRange = maxOvershoot * maxLinearPercentage;
    CGFloat nonLinearScalingDelta = (delta - nonLinearRange);
    CGFloat overshoot = nonLinearRange + nonLinearScalingDelta * nonLinearRange/sqrt(pow(nonLinearScalingDelta,2.f) + 15000);
    
    if (delta < nonLinearRange) {
        return originX;
    }
    else if (targetOffset < 0) {
        return targetOffset - round(overshoot);
    }
    else{
        return targetOffset + round(overshoot);
    }
}


//==============================================================================
/**
 This view will be container for center content, it will be used as a mask that 
 determine which area of the center view will be able to have user interaction
 */
@interface JKDrawerCenterContainerView : UIView
@property (nonatomic, assign) JKDrawerCenterInteractionMode centerInteractionMode;
@property (nonatomic, assign) JKDrawerSide openSide;


@end

@implementation JKDrawerCenterContainerView

-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    UIView *hitView = [super hitTest:point withEvent:event];
    if(hitView && (self.openSide != JKDrawerSideNone))
    {
        UINavigationBar * navBar = [self navigationBarContainedWithinSubviewsOfView:self];
        CGRect navBarFrame = [navBar convertRect:navBar.frame toView:self];
        if((self.centerInteractionMode == JKDrawerCenterInteractionModeNavigationBarOnly && CGRectContainsPoint(navBarFrame, point) == NO)
           || self.centerInteractionMode == JKDrawerCenterInteractionModeNone)
        {
            hitView = nil;
        }
    }
    return hitView;
}

-(UINavigationBar*)navigationBarContainedWithinSubviewsOfView:(UIView*)view{
    UINavigationBar * navBar = nil;
    for(UIView * subview in [view subviews]){
        if([view isKindOfClass:[UINavigationBar class]]){
            navBar = (UINavigationBar*)view;
            break;
        }
        else {
            navBar = [self navigationBarContainedWithinSubviewsOfView:subview];
        }
    }
    return navBar;
}
@end

//==============================================================================
/**
 This view class is used as container for side menu
 */
@interface JKDrawerSideContainerView : UIView
@property (nonatomic) JKDrawerSide side;
@property (nonatomic) BOOL showShadow;
@end

@implementation JKDrawerSideContainerView
- (void) setShowShadow:(BOOL)showShadow
{
    //TODO: Implement shadow effect depending on which side the view is
    // If view is at the left, show shadown on right edge
    // If view is at the right, show shadow on the left edge
}
@end
//==============================================================================
/**
  JKDrawerController extention and implementation
 */
@interface JKDrawerController () <UIGestureRecognizerDelegate>
//{
//	CGFloat _maxLeftDrawerWidth;
//	CGFloat _maxRightDrawerWidth;
//}

@property (nonatomic, strong) UIView                             *centerMaskView;
@property (nonatomic, strong) JKDrawerCenterContainerView        *centerContainerView;
@property (nonatomic, strong) JKDrawerSideContainerView          *leftContainerView;
@property (nonatomic, strong) JKDrawerSideContainerView          *rightContainerView;

@property (nonatomic, copy  ) JKDrawerControllerVisualStateBlock drawerVisualState;
@property (nonatomic, copy  ) JKDrawerGestureCompletionBlock     gestureCompletion;
@end

//==============================================================================
@implementation JKDrawerController


-(UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - Initialization
- (id)init {
    self = [super init];
    if (self) {
        [self initDefault];
    }
    return self;
}
//------------------------------------------------------------------------------
- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
        [self initDefault];
	}
	return self;
}

//------------------------------------------------------------------------------
- (id)initWithCenterViewController:(UIViewController *)centerViewController
                leftViewController:(UIViewController *)leftViewController
               rightViewController:(UIViewController *)rightViewController {
	NSParameterAssert(centerViewController);
	self = [self init];
	if (self) {
        
		[self setCenterViewController:centerViewController];
		[self setLeftViewController:leftViewController];
		[self setRightViewController:rightViewController];
	}
	return self;
}
//------------------------------------------------------------------------------
- (void)awakeFromNib
{
    [self initDefault];
}

//------------------------------------------------------------------------------
- (id)initWithCenterViewController:(UIViewController *)centerViewController
                leftViewController:(UIViewController *)leftViewController {
	return [self initWithCenterViewController:centerViewController
	                       leftViewController:leftViewController
	                      rightViewController:nil];
}

//------------------------------------------------------------------------------
- (id)initWithCenterViewController:(UIViewController *)centerViewController
               rightViewController:(UIViewController *)rightViewController {
	return [self initWithCenterViewController:centerViewController
	                       leftViewController:nil
	                      rightViewController:rightViewController];
}

//------------------------------------------------------------------------------
#pragma mark - Subclass Methods
- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
	return NO;
}

- (BOOL)shouldAutomaticallyForwardRotationMethods {
	return NO;
}

- (BOOL)automaticallyForwardAppearanceAndRotationMethodsToChildViewControllers {
	return NO;
}

//------------------------------------------------------------------------------
#pragma mark - View lifecycle
- (void)viewDidLoad {
	[super viewDidLoad];
	[self.view setBackgroundColor:[UIColor colorWithRed:0.432 green:0.221 blue:0.235 alpha:1.000]];
	[self setupGestureRecognizers];
    
    
    
    if (self.centerViewController) {
        [self replaceCenterController:self.centerViewController
                    oldViewController:nil
                             animated:NO
                           completion:nil];
        
    }

	if (self.leftViewController) {
        [self replaceSideDrawer:_leftViewController
                      oldDrawer:nil side:(JKDrawerSideLeft)
                       animated:NO
                     completion:nil];
        
	}
	if (self.rightViewController) {
		[self replaceSideDrawer:_rightViewController
                      oldDrawer:nil
                           side:(JKDrawerSideRight)
                       animated:NO
                     completion:nil];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.centerViewController beginAppearanceTransition:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	//[self updateShadowForCenterView];
	[self.centerViewController endAppearanceTransition];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.centerViewController beginAppearanceTransition:NO animated:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	[self.centerViewController endAppearanceTransition];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

//------------------------------------------------------------------------------
#pragma mark - Rotation *
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation
                                   duration:duration];
    
    for(UIGestureRecognizer * gesture in self.view.gestureRecognizers)
    {
        if(gesture.state == UIGestureRecognizerStateChanged){
            [gesture setEnabled:NO];
            [gesture setEnabled:YES];
            [self resetDrawerVisualStateForDrawerSide:self.openSide];
            break;
        }
    }
    
    for(UIViewController * childViewController in self.childViewControllers){
        [childViewController willRotateToInterfaceOrientation:toInterfaceOrientation
                                                     duration:duration];
    }
}
//------------------------------------------------------------------------------
- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                          duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    //???: Need shadow?
    //We need to support the shadow path rotation animation
    //Inspired from here: http://blog.radi.ws/post/8348898129/calayers-shadowpath-and-uiview-autoresizing
//    if(self.showsShadow){
//        CGPathRef oldShadowPath = self.centerContainerView.layer.shadowPath;
//        if(oldShadowPath){
//            CFRetain(oldShadowPath);
//        }
//        
//        [self updateShadowForCenterView];
//        
//        if (oldShadowPath) {
//            [self.centerContainerView.layer addAnimation:((^ {
//                CABasicAnimation *transition = [CABasicAnimation animationWithKeyPath:@"shadowPath"];
//                transition.fromValue = (__bridge id)oldShadowPath;
//                transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
//                transition.duration = duration;
//                return transition;
//            })()) forKey:@"transition"];
//            CFRelease(oldShadowPath);
//        }
//    }
    for(UIViewController * childViewController in self.childViewControllers){
        [childViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    }
}

//------------------------------------------------------------------------------
-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation{
    return YES;
}
//------------------------------------------------------------------------------
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    for(UIViewController * childViewController in self.childViewControllers){
        [childViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    }
}

//------------------------------------------------------------------------------
#pragma mark - Setters

//------------------------------------------------------------------------------
- (void)setCenterViewController:(UIViewController *)centerViewController {
    [self setCenterViewController:centerViewController animated:NO completion:NO];
}


//------------------------------------------------------------------------------
- (void)setCenterViewController:(UIViewController *)centerViewController
                       animated:(BOOL)animated
                     completion:(JKDrawerOpenCloseCompletionBlock)completion
{
    UIViewController *oldCenterViewController = self.centerViewController;
	_centerViewController = centerViewController;

    
    if (![self isViewLoaded]) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    
    [self replaceCenterController:_centerViewController
                oldViewController:oldCenterViewController
                         animated:animated
                       completion:completion];
    }
//------------------------------------------------------------------------------
- (void) replaceCenterController: (UIViewController*) newControlller
               oldViewController: (UIViewController*) oldController
                        animated: (BOOL) animated
                      completion: (JKDrawerOpenCloseCompletionBlock) completion
{

    if ((newControlller == nil) && (oldController == nil)) {
        return;
    }
    
    //  ----  Start replacement
	if (oldController) {
		[oldController beginAppearanceTransition:NO animated:animated];
	}
    if (newControlller) {
        [newControlller willMoveToParentViewController:self];
        [self addChildViewController:newControlller];
        [newControlller beginAppearanceTransition:YES animated:animated];
    }
    

    //TODO: Animate view transition here
    // ---------------------
    if (oldController) {
        [oldController.view removeFromSuperview];
    }
    
    if (newControlller) {
        [newControlller.view setFrame:self.view.bounds];
        [self.centerContainerView addSubview:newControlller.view];
        [self.view bringSubviewToFront:self.centerContainerView];
        [newControlller.view setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|
                                                             UIViewAutoresizingFlexibleHeight)];
    }
    // ---------------------
    
    // ----- End replacement
    if (newControlller) {
        [newControlller endAppearanceTransition];
        [newControlller didMoveToParentViewController:self];
    }
    
    if (oldController) {
        [oldController endAppearanceTransition];
        [oldController removeFromParentViewController];
    }
    
    [self updateMaskView];
}

#pragma mark
- (void)setRightViewController:(UIViewController *)rightViewController {
	[self setDrawerViewController:rightViewController forSide:JKDrawerSideRight];
}

//------------------------------------------------------------------------------
- (void)setLeftViewController:(UIViewController *)leftViewController {
	[self setDrawerViewController:leftViewController forSide:JKDrawerSideLeft];
}

//------------------------------------------------------------------------------
- (void)setDrawerViewController:(UIViewController *)viewController
                        forSide:(JKDrawerSide)drawerSide
{
	NSParameterAssert(drawerSide != JKDrawerSideNone);
	UIViewController *currentSideController = [self sideDrawerViewControllerForSide:drawerSide];
    
    // Set new drawer
	if (drawerSide == JKDrawerSideLeft) {
		_leftViewController = viewController;
	}
	else if (drawerSide == JKDrawerSideRight) {
		_rightViewController = viewController;
	}

    if (![self isViewLoaded]) {
        return;
    }
    
    [self replaceSideDrawer: [self sideDrawerViewControllerForSide:drawerSide]
                  oldDrawer: currentSideController
                       side: drawerSide
                   animated: NO
                 completion: nil];
    
}

//------------------------------------------------------------------------------
- (void) replaceSideDrawer: (UIViewController*) newDrawer
                 oldDrawer: (UIViewController*) oldDrawer
                      side:(JKDrawerSide) side
                  animated: (BOOL) animated
                completion: (JKDrawerOpenCloseCompletionBlock) completion
{
    NSParameterAssert(side != JKDrawerSideNone);
    if ((newDrawer == nil) && (oldDrawer == nil)) {
        return;
    }
    
    // Remove current drawer
	if (oldDrawer) {
		[oldDrawer beginAppearanceTransition:NO animated:NO];
	}
    
	// Add drawer as a child & adjust its frame
	if (newDrawer) {
        [newDrawer willMoveToParentViewController:self];
		[self addChildViewController:newDrawer];
        [newDrawer beginAppearanceTransition:YES animated:NO];
	}
    
    //TODO: Animate view transition here
    // ---------------------
    if (oldDrawer) {
        [oldDrawer.view removeFromSuperview];
    }
    
    if (newDrawer) {
        [newDrawer.view setAutoresizingMask: (UIViewAutoresizingFlexibleWidth |
                                              UIViewAutoresizingFlexibleHeight)];
        UIView* containerView = [self sideDrawerContainerViewForSide:side];
        [containerView addSubview:newDrawer.view];
        [newDrawer.view setFrame:containerView.bounds];
//        if (side == JKDrawerSideLeft) {
//            [self.leftContainnerView addSubview:newDrawer.view];
//            [newDrawer.view setFrame:self.leftContainnerView.bounds];
//        }else{
//            [self.rightContainerView addSubview:newDrawer.view];
//            [newDrawer.view setFrame:self.rightContainerView.bounds];
//        }
    }
    // ---------------------
    
    
    if (oldDrawer) {
        [oldDrawer endAppearanceTransition];
        [oldDrawer removeFromParentViewController];
    }
    
    if (newDrawer) {
        [newDrawer endAppearanceTransition];
        [newDrawer didMoveToParentViewController:self];
    }
}

#pragma mark
//------------------------------------------------------------------------------
//-(void)setShowsShadow:(BOOL)showsShadow{
//    _showsShadow = showsShadow;
//    [self updateShadowForCenterView];
//}
//------------------------------------------------------------------------------
- (void)setOpenSide:(JKDrawerSide)openSide {
	if (_openSide != openSide) {
		_openSide = openSide;
		[self.centerContainerView setOpenSide:openSide];
	}
}

//------------------------------------------------------------------------------
- (void)setCenterInteractionMode:(JKDrawerCenterInteractionMode)centerInteractionMode {
	if (_centerInteractionMode != centerInteractionMode) {
		_centerInteractionMode = centerInteractionMode;
		[self.centerContainerView setCenterInteractionMode:centerInteractionMode];
	}
}

#pragma mark -
//------------------------------------------------------------------------------
- (void)setLeftDrawerSize:(CGSize)leftDrawerSize{
    [self setDrawerSize:leftDrawerSize
                forSide:(JKDrawerSideLeft)
               animated:NO
             completion:nil];
}

- (void)setRightDrawerSize:(CGSize)rightDrawerSize
{
    [self setDrawerSize:rightDrawerSize
                forSide:(JKDrawerSideRight)
               animated:NO
             completion:nil];
}

//-------------------------------------------------------------------------------
- (void)setDrawerSize:(CGSize)drawerSize
              forSide:(JKDrawerSide) drawerSide
             animated:(BOOL)animated
           completion:(JKDrawerOpenCloseCompletionBlock) completion
{
    NSParameterAssert(drawerSide != JKDrawerSideNone);
    
    CGSize oldSize  = CGSizeZero;
    
    NSInteger drawerSideOriginCorrection = 1;
    
    if (drawerSide == JKDrawerSideLeft) {
        oldSize = _leftDrawerSize;
        _leftDrawerSize = drawerSize;
    }
    else if(drawerSide == JKDrawerSideRight){
        oldSize = _rightDrawerSize;
        _rightDrawerSize = drawerSize;
        drawerSideOriginCorrection = -1;
    }

    UIView* containerView = [self sideDrawerContainerViewForSide:drawerSide];
    if (!containerView) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    
    // If views are loaded, and sideViewController is set, then update UI
    CGFloat distance = __sizeDistance(oldSize, drawerSize);
    NSTimeInterval duration = [self animationDurationForAnimationDistance:distance];
    CGRect newDrawFrame = [self visibleDrawerFrameForSide:(JKDrawerSide)drawerSide];
    NSAssert(!CGRectIsEmpty(newDrawFrame), @"Invalid drawer frame");
    
    if(self.openSide == drawerSide){
        [UIView
         animateWithDuration:(animated ? duration:0)
         delay:0.0
         options:UIViewAnimationOptionCurveEaseInOut
         animations:^{
             [containerView setFrame:newDrawFrame];
         }
         completion:^(BOOL finished) {
             if(completion != nil){
                 completion(finished);
             }
         }];
    }
    else{
        [containerView setFrame:[self hiddenDrawerFrameForSide:drawerSide]];
        if(completion != nil){
            completion(YES);
        }
    }
}

#pragma mark -
//------------------------------------------------------------------------------
-(void)setDrawerVisualStateBlock:(JKDrawerControllerVisualStateBlock)drawerVisualStateBlock{
    [self setDrawerVisualState:drawerVisualStateBlock];
}
//------------------------------------------------------------------------------
-(void)setGestureCompletionBlock:(JKDrawerGestureCompletionBlock)gestureCompletionBlock{
    [self setGestureCompletion:gestureCompletionBlock];
}

- (void) setCenterMaskFrame:(CGRect)centerMaskFrame
{
    _centerMaskFrame = centerMaskFrame;
    [self updateMaskView];
}
//------------------------------------------------------------------------------
#pragma mark - Getters
- (CGFloat)maxLeftDrawerWidth {
	return _leftViewController ? _leftDrawerSize.width : 0;
}

//------------------------------------------------------------------------------
- (CGFloat)maxRightDrawerWidth {
	return _rightViewController ? _rightDrawerSize.width : 0;
}
//------------------------------------------------------------------------------
- (JKDrawerSideContainerView*) leftContainerView{
    if (!_leftContainerView) {
        _leftContainerView = [[JKDrawerSideContainerView alloc]
                               initWithFrame:[self hiddenDrawerFrameForSide:(JKDrawerSideLeft)]];
        [self.leftContainerView setAutoresizingMask:(UIViewAutoresizingFlexibleRightMargin |
                                                      UIViewAutoresizingFlexibleHeight)];
        [self.leftContainerView setBackgroundColor:[UIColor clearColor]];
        [self.leftContainerView setSide:(JKDrawerSideLeft)];
        
        if (_showsShadow) {
            _leftContainerView.layer.masksToBounds = NO;
            _leftContainerView.layer.shadowRadius = JKDrawerMaxShadowRadius;
            _leftContainerView.layer.shadowOpacity = .0f;
            _leftContainerView.layer.shadowOffset = JKDrawerLeftShadowOffset;
            //_leftContainerView.layer.shadowColor = [UIColor redColor].CGColor;
            NSLog(@"bOund %@", NSStringFromCGRect(_leftContainerView.bounds));
            //_leftContainerView.layer.shadowPath = [[UIBezierPath bezierPathWithRect:_leftContainerView.bounds] CGPath];
        }

        [self.view addSubview: _leftContainerView];
    }
    return _leftContainerView;
}
//------------------------------------------------------------------------------
- (JKDrawerSideContainerView*) rightContainerView{
    if (!_rightContainerView) {
        _rightContainerView = [[JKDrawerSideContainerView alloc]
                               initWithFrame:[self hiddenDrawerFrameForSide:(JKDrawerSideRight)]];
        [self.rightContainerView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin |
                                                      UIViewAutoresizingFlexibleHeight)];
        [self.rightContainerView setBackgroundColor:[UIColor clearColor]];
        [self.rightContainerView setSide:(JKDrawerSideRight)];
        
        
        if (_showsShadow) {
            _rightContainerView.layer.masksToBounds = NO;
            _rightContainerView.layer.shadowRadius = JKDrawerMaxShadowRadius;
            _rightContainerView.layer.shadowOpacity = .0f;
            //_rightContainerView.layer.shadowColor = [UIColor redColor].CGColor;
            _rightContainerView.layer.shadowOffset = JKDrawerRightShadowOffset;
            NSLog(@"bOund %@", NSStringFromCGRect(_rightContainerView.bounds));
            //_rightContainerView.layer.shadowPath = [[UIBezierPath bezierPathWithRect:_rightContainerView.bounds] CGPath];
        }
        
        [self.view addSubview: _rightContainerView];
    }
    return _rightContainerView;
}
//------------------------------------------------------------------------------
- (JKDrawerCenterContainerView*) centerContainerView{
    if (!_centerContainerView) {
        _centerContainerView = [[JKDrawerCenterContainerView alloc] initWithFrame:self.view.bounds];
        [self.centerContainerView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self.centerContainerView setBackgroundColor:[UIColor clearColor]];
        [self.centerContainerView setOpenSide:self.openSide];
        [self.centerContainerView setCenterInteractionMode:self.centerInteractionMode];
        [self.view addSubview:self.centerContainerView];
    }
    
    return _centerContainerView;
}
//------------------------------------------------------------------------------
- (UIView*)centerMaskView
{
    if (!_centerMaskView) {
        _centerMaskView = [[UIView alloc] init];
        [_centerMaskView setBackgroundColor:[UIColor blackColor]];
        [_centerMaskView setAlpha:0.0f];

        [_centerMaskView setUserInteractionEnabled:YES];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                       initWithTarget:self
                                       action:@selector(maskTapGesture:)];
        [tap setDelegate:self];
        tap.cancelsTouchesInView = NO;
        [_centerMaskView addGestureRecognizer:tap];
        [self.view addSubview:_centerMaskView];
        
    }
    return _centerMaskView;
}

//------------------------------------------------------------------------------
#pragma mark - Open/Close methods
- (void)toggleDrawerSide:(JKDrawerSide)drawerSide
                animated:(BOOL)animated
              completion:(JKDrawerOpenCloseCompletionBlock)completion
{
    NSParameterAssert(drawerSide!=JKDrawerSideNone);
    
    if (self.openSide != drawerSide) {
        [self openDrawerSide:drawerSide animated:animated completion:completion];
    }else{
        [self closeDrawerAnimated:animated completion:completion];
    }
}
//------------------------------------------------------------------------------
// OPEN
//------------------------------------------------------------------------------
- (void)openDrawerSide:(JKDrawerSide)drawerSide
              animated:(BOOL)animated
            completion:(JKDrawerOpenCloseCompletionBlock)completion
{
    NSParameterAssert(drawerSide != JKDrawerSideNone);
    
    [self openDrawerSide:drawerSide
                animated:animated
                velocity:self.animationVelocity
        animationOptions:UIViewAnimationOptionCurveEaseInOut
              completion:completion];
}

//------------------------------------------------------------------------------
-(void)openDrawerSide:(JKDrawerSide)drawerSide
             animated:(BOOL)animated
             velocity:(CGFloat)velocity
     animationOptions:(UIViewAnimationOptions)options
           completion:(JKDrawerOpenCloseCompletionBlock)completion
{
    NSParameterAssert(drawerSide != JKDrawerSideNone);
    
    //UIViewController * sideDrawerViewController = [self sideDrawerViewControllerForSide:drawerSide];
    UIView* containerView = [self sideDrawerContainerViewForSide:drawerSide];
    if(containerView)
    {
        CGFloat distance = ABS(CGRectGetMinX(containerView.frame)
                               - [self visibleDistanceForSide:drawerSide]);
        NSTimeInterval duration = MAX(distance/ABS(velocity),JKDrawerMinimumAnimationDuration);
        [self.view bringSubviewToFront:containerView];
        
        [UIView
         animateWithDuration:(animated ? duration:0.0)
         delay:0.0
         options:options
         animations:^{
             [self updateVisualStateForDrawerSide:drawerSide percentVisible:1.0];
             [self.centerMaskView setAlpha:JKDrawerMaxCenterMaskAlpha];
             if ((self.openSide != drawerSide)&&(self.openSide != JKDrawerSideNone)) {
                 [self updateVisualStateForDrawerSide:self.openSide percentVisible:0.0];
             }
             [self setOpenSide:drawerSide];
         }
         completion:^(BOOL finished)
         {
             if(completion){
                 completion(finished);
             }
         }];
    }
}

//------------------------------------------------------------------------------
// CLOSE
//------------------------------------------------------------------------------
- (void)closeDrawerAnimated:(BOOL)animated
                 completion:(JKDrawerOpenCloseCompletionBlock)completion
{
    [self closeDrawerAnimated:animated
                     velocity:self.animationVelocity
             animationOptions:UIViewAnimationOptionCurveEaseIn
                   completion:completion];
}

//------------------------------------------------------------------------------
-(void)closeDrawerAnimated:(BOOL)animated
                  velocity:(CGFloat)velocity
          animationOptions:(UIViewAnimationOptions)options
                completion:(void (^)(BOOL))completion
{
    JKDrawerSide visibleSide = [self visibleDrawerSide];
    if (visibleSide == JKDrawerSideNone) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    
    CGFloat distance = [self visibleDistanceForSide:visibleSide];
    NSTimeInterval duration = MAX(distance/ABS(velocity),JKDrawerMinimumAnimationDuration);
    
    [UIView
     animateWithDuration:(animated ? duration:0.0)
     delay:0.0
     options:options
     animations:^{
         [self.centerMaskView setAlpha:0.0f];
         [self updateVisualStateForDrawerSide:visibleSide
                               percentVisible:0.0];
         [self setOpenSide:JKDrawerSideNone];
     }
     completion:^(BOOL finished) {
         if(completion){
             completion(finished);
         }
     }];
}

//------------------------------------------------------------------------------
#pragma mark - Gesture handler

- (void)maskTapGesture:(UITapGestureRecognizer *)tapGesture {
	if(self.openSide != JKDrawerSideNone)
    {
        [self closeDrawerAnimated:YES completion:^(BOOL finished)
        {
            if(self.gestureCompletion){
                self.gestureCompletion(self, tapGesture);
            }
        }];
    }
}

//------------------------------------------------------------------------------
- (void)panGesture:(UIPanGestureRecognizer *)panGesture {
    
    if (panGesture.state == UIGestureRecognizerStateBegan) {
        
    }
    else if(panGesture.state == UIGestureRecognizerStateChanged)
    {
        CGPoint translatedPoint = [panGesture translationInView:self.centerContainerView];
        NSLog(@"Translation: %@", NSStringFromCGPoint(translatedPoint));
        [self updateViewForPanGestureWithTranslation:translatedPoint];
    }
    else if((panGesture.state==UIGestureRecognizerStateEnded) ||
             (panGesture.state == UIGestureRecognizerStateCancelled))
    {
        //        self.startingPanRect = CGRectNull;
        CGPoint velocity = [panGesture velocityInView:self.view];
        [self finishPanGestureWithXVelocity:velocity.x
                                 completion:^(BOOL finished)
         {
             if(self.gestureCompletion){
                 self.gestureCompletion(self, panGesture);
             }
         }];
    }
}

//------------------------------------------------------------------------------
#pragma mark - Helpers

- (void)initDefault
{
    [self setLeftDrawerSize:JKDrawerDefaultSize];
    [self setRightDrawerSize:JKDrawerDefaultSize];
    [self setAnimationVelocity:JKDrawerDefaultAnimationVelocity];
    [self setShouldStretchDrawer:YES];
    [self setOpenDrawerGestureMask:(JKDrawerOpenGestureModeNone)];
    [self setCloseDrawerGestureMask:(JKDrawerCloseGestureModeNone)];
    [self setCenterInteractionMode:(JKDrawerCenterInteractionModeFull)];
    [self setShowsShadow:NO];
}
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
- (void)setupGestureRecognizers {
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
	                               initWithTarget:self
                                   action:@selector(panGesture:)];
	[pan setDelegate:self];
	[self.view addGestureRecognizer:pan];
    
    //!!!: This tap gesture will cancel the touch event on drawer's view.
//	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
//	                               initWithTarget:self
//                                   action:@selector(tapGesture:)];
//	[tap setDelegate:self];
//    tap.cancelsTouchesInView = NO;
//	[self.view addGestureRecognizer:tap];
}

//------------------------------------------------------------------------------
- (UIViewController *)sideDrawerViewControllerForSide:(JKDrawerSide)drawerSide {
	UIViewController *sideDrawerViewController = nil;
	if (drawerSide == JKDrawerSideLeft) {
		sideDrawerViewController = self.leftViewController;
	}
	else if (drawerSide == JKDrawerSideRight) {
		sideDrawerViewController = self.rightViewController;
	}
	return sideDrawerViewController;
}

//------------------------------------------------------------------------------
-(UIView*) sideDrawerContainerViewForSide:(JKDrawerSide) drawerSide{
    UIView* containerView = nil;
    if (drawerSide == JKDrawerSideLeft) {
        containerView = self.leftContainerView;
    }else if (drawerSide == JKDrawerSideRight){
        containerView = self.rightContainerView;
    }
    return containerView;
}

//------------------------------------------------------------------------------
- (CGRect)visibleDrawerFrameForSide:(JKDrawerSide)drawerSide
{
    
    NSLog(@"Drawer root frame: %@", NSStringFromCGRect(self.view.frame));
    CGRect drawerFrame = CGRectZero;
    switch (drawerSide) {
        case JKDrawerSideLeft:
            drawerFrame = (CGRect) {
                .origin = {
                    .x = 0,
                    .y = (self.view.bounds.size.height
                          - _leftDrawerSize.height)
                },
                .size = _leftDrawerSize
            };
            break;
        case JKDrawerSideRight:
            drawerFrame = (CGRect) {
                .origin = {
                    .x = (self.view.bounds.size.width - _rightDrawerSize.width),
                    .y = (self.view.bounds.size.height - _rightDrawerSize.height)
                },
                .size = _rightDrawerSize
            };
            break;
        default:
            break;
    }
	return drawerFrame;
}

//------------------------------------------------------------------------------
- (CGRect) hiddenDrawerFrameForSide:(JKDrawerSide) drawerSide
{
    
    CGRect drawerFrame = CGRectZero;
    switch (drawerSide) {
        case JKDrawerSideLeft:
            drawerFrame = (CGRect) {
                .origin = {
                    .x = - _leftDrawerSize.width,
                    .y = (self.view.bounds.size.height
                          - _leftDrawerSize.height)
                },
                .size = _leftDrawerSize
            };
            break;
        case JKDrawerSideRight:
            drawerFrame = (CGRect) {
                .origin = {
                    .x = (self.view.bounds.size.width),
                    .y = (self.view.bounds.size.height - _rightDrawerSize.height)
                },
                .size = _rightDrawerSize
            };
            break;
        default:
            break;
    }
	return drawerFrame;
}

//------------------------------------------------------------------------------
-(NSTimeInterval)animationDurationForAnimationDistance:(CGFloat)distance{
    NSTimeInterval duration = MAX(distance/self.animationVelocity,JKDrawerMinimumAnimationDuration);
    return duration;
}
//------------------------------------------------------------------------------
- (void) updateMaskView
{
    if (!CGRectIsEmpty(_centerMaskFrame)) {
        [self.centerMaskView setFrame:_centerMaskFrame];
        return;
    }
    
    if (_centerContainerView) {
        CGRect centerContentFrame = self.view.bounds;
        if (_centerViewController && [_centerViewController isKindOfClass:[UINavigationController class]])
        {
            UIView* centerContentView = [(UINavigationController*)_centerViewController topViewController].view;
            centerContentFrame = [_centerViewController.view
                                  convertRect:centerContentView.frame
                                  toView:self.view];
        }else if (_centerViewController){
            centerContentFrame = [_centerViewController.view convertRect:_centerViewController.view.frame
                                                                  toView:self.view];
        }
        [self.centerMaskView setFrame:centerContentFrame];
        [self.view sendSubviewToBack:_centerContainerView];
    }else{
        [self.centerMaskView setFrame: self.view.bounds];
    }
}

//------------------------------------------------------------------------------
#pragma mark - Animation Helpers
- (void)updateVisualStateForDrawerSide:(JKDrawerSide)drawerSide
                        percentVisible:(CGFloat)percentVisible
{
    NSParameterAssert(drawerSide != JKDrawerSideNone);
    
    //UIViewController* drawer = [self sideDrawerViewControllerForSide:drawerSide];
    UIView* containerView = [self sideDrawerContainerViewForSide:drawerSide];
    CGRect targetFrame;
    
    if (percentVisible == 0.0f) {
         targetFrame = [self hiddenDrawerFrameForSide:drawerSide];
        if (_showsShadow) [containerView.layer setShadowOpacity:0.0f];
        [containerView setFrame:targetFrame];
        return;
    }else if (percentVisible == 1.0f){
        targetFrame = [self visibleDrawerFrameForSide:drawerSide];
        if (_showsShadow) [containerView.layer setShadowOpacity:JKDrawerMaxShadowOpacity];
        [containerView setFrame:targetFrame];
        return;
    }

    targetFrame = [self hiddenDrawerFrameForSide:drawerSide];
    switch (drawerSide) {
        case JKDrawerSideLeft:
            targetFrame.origin.x = _leftDrawerSize.width *(percentVisible -1);
            break;
            
        case JKDrawerSideRight:
            targetFrame.origin.x = CGRectGetWidth(self.view.frame) - percentVisible * _rightDrawerSize.width;
            break;
        default:
            break;
    }
    if (_showsShadow) [containerView.layer setShadowOpacity:(percentVisible * JKDrawerMaxShadowOpacity)];
    [containerView setFrame:targetFrame];
}

//------------------------------------------------------------------------------
//!!!: Deprecated
-(void)resetDrawerVisualStateForDrawerSide:(JKDrawerSide)drawerSide
{
    UIViewController * sideDrawerViewController = [self sideDrawerViewControllerForSide:drawerSide];

    [sideDrawerViewController.view.layer setAnchorPoint:CGPointMake(0.5f, 0.5f)];
    [sideDrawerViewController.view.layer setTransform:CATransform3DIdentity];
    [sideDrawerViewController.view setAlpha:1.0];
}

//------------------------------------------------------------------------------
//!!!: Deprecated
-(CGFloat)roundedOriginXForDrawerConstriants:(CGFloat)originX{
    
    if (originX < -self.maxRightDrawerWidth) {
        if (self.shouldStretchDrawer &&
            self.rightViewController) {
            CGFloat maxOvershoot = (CGRectGetWidth(self.centerContainerView.frame)-self.maxRightDrawerWidth)*JKDrawerOvershootPercentage;
            return __originXForDrawerOriginAndTargetOriginOffset(originX, -self.maxRightDrawerWidth, maxOvershoot);
        }
        else{
            return -self.maxRightDrawerWidth;
        }
    }
    else if(originX > self.maxLeftDrawerWidth){
        if (self.shouldStretchDrawer &&
            self.leftViewController) {
            CGFloat maxOvershoot = (CGRectGetWidth(self.centerContainerView.frame)-self.maxLeftDrawerWidth)*JKDrawerOvershootPercentage;
            return __originXForDrawerOriginAndTargetOriginOffset(originX, self.maxLeftDrawerWidth, maxOvershoot);
        }
        else{
            return self.maxLeftDrawerWidth;
        }
    }
    
    return originX;
}

//------------------------------------------------------------------------------
- (JKDrawerSide)visibleDrawerSide
{
    CGRect leftFrame = _leftContainerView.frame;
    CGRect rightFrame = _rightContainerView.frame;
    
    if (CGRectIntersectsRect(leftFrame, self.view.bounds))
        return JKDrawerSideLeft;
    else if(CGRectIntersectsRect(rightFrame, self.view.bounds))
        return JKDrawerSideRight;
    else
        return JKDrawerSideNone;
}
//------------------------------------------------------------------------------
- (CGFloat) visiblePercentForSide:(JKDrawerSide) drawerSide
{
    if (drawerSide == JKDrawerSideNone) {
        return 0.0f;
    }
    CGFloat percentVisible=0.0f;
    CGFloat distance = [self visibleDistanceForSide:drawerSide];
    
    CGRect leftFrame = _leftContainerView.frame;
    CGRect rightFrame = _rightContainerView.frame;
    
    if (drawerSide == JKDrawerSideLeft) {
        percentVisible = MAX(0.0f, distance/ CGRectGetWidth(leftFrame)) ;
    }else{
        percentVisible = MAX(0.0f, distance/CGRectGetWidth(rightFrame)) ;
    }
    return percentVisible;
}
//------------------------------------------------------------------------------
- (CGFloat) visibleDistanceForSide:(JKDrawerSide) drawerSide
{
    if (drawerSide == JKDrawerSideNone) {
        return 0.0f;
    }
//    UIViewController* leftDrawer = [self sideDrawerViewControllerForSide:(JKDrawerSideLeft)];
//    UIViewController* rightDrawer = [self sideDrawerViewControllerForSide:(JKDrawerSideRight)];
    UIView* leftContainer = [self sideDrawerContainerViewForSide:JKDrawerSideLeft];
    UIView* rightContainer = [self sideDrawerContainerViewForSide:(JKDrawerSideRight)];
    
    CGFloat distance=0.0f;
    if (drawerSide == JKDrawerSideLeft) {
        distance = CGRectGetMaxX(leftContainer.frame);
    }else{
        distance = self.view.bounds.size.width - CGRectGetMinX(rightContainer.frame);
    }
    return distance;
}

//------------------------------------------------------------------------------
-(void)updateViewForPanGestureWithTranslation:(CGPoint) translatedPoint
{
    CGRect targetFrame;

    switch (self.openSide) {
        case JKDrawerSideNone:
        {
            // Pan to right -> show left
            if (translatedPoint.x > 0)
            {
                targetFrame = [self hiddenDrawerFrameForSide:(JKDrawerSideLeft)];
                targetFrame.origin.x += translatedPoint.x;
                targetFrame.origin.x = MIN([self visibleDrawerFrameForSide:(JKDrawerSideLeft)].origin.x, targetFrame.origin.x);
                [_leftContainerView setFrame:targetFrame];
                [_rightContainerView setFrame:[self hiddenDrawerFrameForSide:(JKDrawerSideRight)]];
            }
            // Pan to left -> show right
            else if(translatedPoint.x < 0)
            {
                targetFrame = [self hiddenDrawerFrameForSide:(JKDrawerSideRight)];
                targetFrame.origin.x += translatedPoint.x;
                targetFrame.origin.x = MAX(targetFrame.origin.x, [self visibleDrawerFrameForSide:(JKDrawerSideRight)].origin.x);
                [_rightContainerView setFrame:targetFrame];
                [_leftContainerView setFrame:[self hiddenDrawerFrameForSide:(JKDrawerSideLeft)]];
            }
            else
            {
                [_rightViewController.view setFrame:[self hiddenDrawerFrameForSide:(JKDrawerSideRight)]];
                [_leftViewController.view setFrame:[self hiddenDrawerFrameForSide:(JKDrawerSideLeft)]];
            }
            
            break;
        }
        case JKDrawerSideLeft:
        {
            targetFrame = [self visibleDrawerFrameForSide:(JKDrawerSideLeft)];
            targetFrame.origin.x = targetFrame.origin.x + translatedPoint.x;
            targetFrame.origin.x = MIN(0, targetFrame.origin.x);
            targetFrame.origin.x = MAX(-_leftDrawerSize.width, targetFrame.origin.x);
            //[_leftViewController.view setFrame:targetFrame];
            [_leftContainerView setFrame:targetFrame];
            break;
        }
        case JKDrawerSideRight:
            targetFrame = [self visibleDrawerFrameForSide:(JKDrawerSideRight)];
            targetFrame.origin.x = targetFrame.origin.x + translatedPoint.x;
            targetFrame.origin.x = MAX([self visibleDrawerFrameForSide:(JKDrawerSideRight)].origin.x, targetFrame.origin.x);
            targetFrame.origin.x = MIN(self.view.bounds.size.width, targetFrame.origin.x);
            //[_rightViewController.view setFrame:targetFrame];
            [_rightContainerView setFrame:targetFrame];
            break;
        default:
            break;
    }
    UIView* view = [self sideDrawerContainerViewForSide:[self visibleDrawerSide]];
    CGFloat percent = [self visiblePercentForSide:[self visibleDrawerSide]];
    if (_showsShadow) [view.layer setShadowOpacity:(percent * JKDrawerMaxShadowOpacity)];
    [_centerMaskView setAlpha:(percent * JKDrawerMaxCenterMaskAlpha)];

}

//------------------------------------------------------------------------------
-(void)finishPanGestureWithXVelocity:(CGFloat)xVelocity
                          completion:(void(^)(BOOL finished))completion
{
    CGFloat animationVelocity = MAX(ABS(xVelocity),JKDrawerDefaultAnimationVelocity);
    CGFloat percentVisible;
    switch (self.openSide) {
        case JKDrawerSideNone:
        {
            JKDrawerSide visibleSide = [self visibleDrawerSide];
            if (visibleSide == JKDrawerSideNone) {
//                [_rightViewController.view setFrame: [self hiddenDrawerFrameForSide:(JKDrawerSideRight)]];
//                [_leftViewController.view setFrame:[self hiddenDrawerFrameForSide:(JKDrawerSideLeft)]];
                [_leftContainerView setFrame:[self hiddenDrawerFrameForSide:(JKDrawerSideLeft)]];
                [_rightContainerView setFrame:[self hiddenDrawerFrameForSide:(JKDrawerSideRight)]];
                if (completion) {
                    completion(NO);
                }
            }else{
                percentVisible = [self visiblePercentForSide:visibleSide];
                if ((ABS(xVelocity) > JKDrawerPanVelocityXAnimationThreshold) || (percentVisible > 0.5))
                {
                    [self openDrawerSide:visibleSide
                                animated:YES
                                velocity:animationVelocity
                        animationOptions:(UIViewAnimationOptionCurveEaseInOut)
                              completion:completion];
                }else{
                    [self closeDrawerAnimated:YES
                                     velocity:animationVelocity
                             animationOptions:(UIViewAnimationOptionCurveEaseInOut)
                                   completion:completion];
                }
            }
            break;
        }
        case JKDrawerSideLeft: // Closing left drawer
        case JKDrawerSideRight:
        {
            percentVisible = [self visiblePercentForSide:(self.openSide)];
            if ((ABS(xVelocity) > JKDrawerPanVelocityXAnimationThreshold) || (percentVisible < 0.5))
            {
                [self closeDrawerAnimated:YES
                                 velocity:animationVelocity
                         animationOptions:(UIViewAnimationOptionCurveEaseInOut)
                               completion:completion];
            }else{
                [self openDrawerSide:self.openSide
                            animated:YES
                            velocity:animationVelocity
                    animationOptions:(UIViewAnimationOptionCurveEaseInOut)
                          completion:completion];
            }
            break;
        }
        default:
            break;
    }
}
@end


#pragma mark -  UIViewController (JKDrawerController)
//==============================================================================
@implementation UIViewController (JKDrawerController)
- (JKDrawerController*) drawerController{
    JKDrawerController* drawer = nil;
    if ([self.parentViewController isKindOfClass:[JKDrawerController class]]) {
        drawer = (JKDrawerController*)self.parentViewController;
    }
    return drawer;
}
@end
