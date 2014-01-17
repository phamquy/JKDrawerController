//
//  JKDrawerController.h
//  JKDrawerControllerDemo
//
//  Created by jack on 1/6/14.
//  Copyright (c) 2014 jkorp. All rights reserved.
//

#import <UIKit/UIKit.h>



typedef NS_ENUM (NSInteger, JKDrawerSide) {
	JKDrawerSideNone = 0,
	JKDrawerSideLeft,
	JKDrawerSideRight
};

typedef NS_OPTIONS (NSInteger, JKDrawerOpenGestureMode) {
	JKDrawerOpenGestureModeNone                   = 0,
	JKDrawerOpenGestureModeBezelPanningCenterView = 1 << 1,
    JKDrawerOpenGestureModePanningCenterView      = 1 << 2,
    JKDrawerOpenGestureModeAll                    = JKDrawerOpenGestureModeBezelPanningCenterView |
    JKDrawerOpenGestureModePanningCenterView,
};

typedef NS_OPTIONS (NSInteger, JKDrawerCloseGestureMode) {
	JKDrawerCloseGestureModeNone                   = 0,
	JKDrawerCloseGestureModePanningDrawer          = 1 << 1,
    JKDrawerCloseGestureModePanningCenterView      = 1 << 2,
    JKDrawerCloseGestureModePanningNavigatorBar    = 1 << 3,
    JKDrawerCloseGestureModeBezelPanningCenterView = 1 << 4,
    JKDrawerCloseGestureModeTapNavigationBar       = 1 << 5,
    JKDrawerCloseGestureModeTapCenterView          = 1 << 6,
    JKDrawerCloseGestureModeAll                    = (JKDrawerCloseGestureModePanningDrawer |
                                                      JKDrawerCloseGestureModePanningCenterView |
                                                      JKDrawerCloseGestureModePanningNavigatorBar |
                                                      JKDrawerCloseGestureModeBezelPanningCenterView |
                                                      JKDrawerCloseGestureModeTapCenterView |
                                                      JKDrawerCloseGestureModeTapNavigationBar)
};



typedef NS_ENUM(NSInteger, JKDrawerCenterInteractionMode) {
    JKDrawerCenterInteractionModeNone,
    JKDrawerCenterInteractionModeFull,
    JKDrawerCenterInteractionModeNavigationBarOnly
};


@class JKDrawerController;
/** 
  The call back to define visual state of drawer given percent of
visibility of the drawer

 *  @param drawerController the drawer controller
 *  @param drawerSide       JKDrawerSide side of drawer
 *  @param percentVisible   0.0 to 1.0
 */
typedef void (^JKDrawerControllerVisualStateBlock)(JKDrawerController *drawerController,
                                                   JKDrawerSide        drawerSide,
                                                   CGFloat             percentVisible);
/**
 *  This call back is call when a gesture has been completed
 *
 *  Query the openSide property of drawerController to determine which drawer side is open
 *  @param drawerController the drawer controller
 *  @param gesture the gesture recognizer object
 */
typedef void (^JKDrawerGestureCompletionBlock)(JKDrawerController  *drawerController,
                                               UIGestureRecognizer *gesture);

/**
 *  Called when drawer fnished its animation
 *
 *  @param finished YES meant finished
 */
typedef void (^JKDrawerOpenCloseCompletionBlock)(BOOL finished);
typedef JKDrawerOpenCloseCompletionBlock JKDrawerBounceCompletionBlock;

//==============================================================================

@interface JKDrawerController : UIViewController

@property (nonatomic, strong ) UIViewController              *centerViewController;
@property (nonatomic, strong ) UIViewController              *leftViewController;
@property (nonatomic, strong ) UIViewController              *rightViewController;

@property (nonatomic         ) CGFloat                       maxLeftDrawerWidth; //FIXME: Deprecated
@property (nonatomic         ) CGFloat                       maxRigthDrawerWidth; //FIXME: Deprecated
@property (nonatomic,readonly) CGFloat                       visibleLeftDrawerWidth;
@property (nonatomic,readonly) CGFloat                       visibleRightDrawerWidth;
@property (nonatomic         ) CGFloat                       animationVelocity;


@property (nonatomic         ) BOOL                          showsShadow;
@property (nonatomic         ) BOOL                          shouldStretchDrawer;
@property (nonatomic,readonly) JKDrawerSide                  openSide;
@property (nonatomic         ) JKDrawerOpenGestureMode       openDrawerGestureMask;
@property (nonatomic         ) JKDrawerCloseGestureMode      closeDrawerGestureMask;
@property (nonatomic         ) JKDrawerCenterInteractionMode centerInteractionMode;


@property (nonatomic         ) CGSize                        leftDrawerSize;
@property (nonatomic         ) CGSize                        rightDrawerSize;
@property (nonatomic         ) CGRect                        centerMaskFrame;
@property (nonatomic         ) BOOL                          enableDimCenter;
#pragma mark Initialization methods
/**
 *  @name Initialization methods
 */

/**
 *  Create and initialize drawer with center, left and right view controller
 *
 *  @param centerViewController The center view controller, must not be nil
 *  @param leftViewController   The left view controller
 *  @param rightViewController  The right view controller
 *
 *  @return new instance of drawer
 */
- (id)initWithCenterViewController:(UIViewController *)centerViewController
                leftViewController:(UIViewController *)leftViewController
               rightViewController:(UIViewController *)rightViewController;

- (id)initWithCenterViewController:(UIViewController *)centerViewController
                leftViewController:(UIViewController *)leftViewController;

- (id)initWithCenterViewController:(UIViewController *)centerViewController
               rightViewController:(UIViewController *)rightViewController;


#pragma mark Open and closing methods
/// @name Open and closing methods

/**
 *  Toggle/Open/Close drawer of given side
 *
 *  @param drawerSide side to be toggled
 *  @param animated   set YES to animate
 *  @param completion completion handler, called when animation finished (if animated is YES), or call after toggle (if animated is NO)
 */
- (void)toggleDrawerSide:(JKDrawerSide)drawerSide
                animated:(BOOL)animated
              completion:(JKDrawerOpenCloseCompletionBlock)completion;

- (void)openDrawerSide:(JKDrawerSide)drawerSide
              animated:(BOOL)animated
            completion:(JKDrawerOpenCloseCompletionBlock)completion;

//- (void)closeDrawerSide:(JKDrawerSide)drawerSide
//               animated:(BOOL)animated
//             completion:(JKDrawerOpenCloseCompletionBlock)completion;

- (void)closeDrawerAnimated:(BOOL)animated
             completion:(JKDrawerOpenCloseCompletionBlock)completion;


#pragma mark Set Center View Controller
/// @name set center view controller

/**
 Set center view controller animatedly
 
 @param centerViewController
 @param animated
 @param completion
 
 */
- (void)setCenterViewController:(UIViewController *)centerViewController
                       animated:(BOOL)animated
                     completion:(JKDrawerOpenCloseCompletionBlock)completion;



/**
 *  Set the new center view controller
 *
 *  @param centerViewController new center view controller
 *  @param fullCloseAnimated    if YES, the new view controller will be animated in, aafter that the drawer will be closed animatedly
 *  @param completion           called after all the animations are finished
 */
//- (void)setCenterViewController:(UIViewController *)centerViewController
//         withFullCloseAnimation:(BOOL)fullCloseAnimated
//                     completion:(JKDrawerOpenCloseCompletionBlock)completion;


#pragma mark Animated update width of side drawers
/**
 *  @name Animating the width of side drawers
 */

/**
 *  Set width of side drawers with animation
 *
 *  @param drawerSide drawer side
 *  @param animated   set YES to animated
 *  @param completion called when animation is finished
 */
//- (void)setMaximumDrawerWidth:(CGFloat)width
//                      forSide:(JKDrawerSide)drawerSide
//                     animated:(BOOL)animated
//                   completion:(JKDrawerOpenCloseCompletionBlock)completion;

/**
 *  Set block to customize visual appearance of drawer during animation
 *
 *  @param block customize block
 */
//- (void)setDrawerVisualStateBlock:(JKDrawerControllerVisualStateBlock)block;


/**
 *  Bounce drawer side to preview
 *
 *  @param drawerSide side of drawer
 *  @param distance   how much distance to bounce
 *  @param completion called when animation is finished
 */
//- (void)bouncePreviewForDrawerSide:(JKDrawerSide)drawerSide
//                          distance:(CGFloat)distance
//                        completion:(JKDrawerBounceCompletionBlock)completion;



@end

@interface UIViewController (JKDrawerController)
- (JKDrawerController*) drawerController;
@end

