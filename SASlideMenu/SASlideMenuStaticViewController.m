//
//  SASlideMenuStaticViewController.m
//  SASlideMenu test test 123
//
//  Created by Stefano Antonelli on 7/29/12.
//  Copyright (c) 2012 Stefano Antonelli. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "SASlideMenuStaticViewController.h"
#import "SASlideMenuStaticStoryboardSegue.h"

#define kSlideInInterval 0.3
#define kSlideOutInterval 0.1
#define kMenuTableSize 280

@interface SASlideMenuStaticViewController (){
    UINavigationController* selectedContent;
    BOOL isFirstViewWillAppear;
}

@property (nonatomic, strong) UIView* shield;
@property (nonatomic, strong) UIView* shieldWithMenu;

@end

@implementation SASlideMenuStaticViewController

@synthesize slideMenuDataSource;

#pragma mark - SASlideMenuStaticViewController

-(CGFloat) menuSize{
    if ([self.slideMenuDataSource respondsToSelector:@selector(slideMenuVisibleWidth)]){
        return [self.slideMenuDataSource slideMenuVisibleWidth];
    }else{
        return kMenuTableSize;
    }
}

-(void) slideOut:(UINavigationController*) controller{
    CGRect bounds = self.view.bounds;
    controller.view.frame = CGRectMake(bounds.size.width,0.0,bounds.size.width,bounds.size.height);
}

-(void) slideToSide:(UINavigationController*) controller{
    CGRect bounds = self.view.bounds;
    controller.view.frame = CGRectMake([self menuSize],0.0,bounds.size.width,bounds.size.height);
}

-(void) slideIn:(UINavigationController*) controller{
    CGRect bounds = self.view.bounds;
    controller.view.frame = CGRectMake(0.0,0.0,bounds.size.width,bounds.size.height);
}

-(void) completeSlideIn:(UINavigationController*) controller{
    [self.shieldWithMenu removeFromSuperview];
    [controller.visibleViewController.view addSubview:self.shield];
    [controller.visibleViewController.view sendSubviewToBack:self.shield];
    self.shield.frame = controller.visibleViewController.view.bounds;
}

-(void) completeSlideToSide:(UINavigationController*) controller{
    [self.shield removeFromSuperview];
    [controller.view addSubview:self.shieldWithMenu];
    self.shieldWithMenu.frame = controller.view.bounds;
}

-(void) doSlideToSide{
    
    [UIView animateWithDuration:kSlideInInterval
                          delay:0.0
                        options:UIViewAnimationCurveEaseInOut
                     animations:^{
                         [self slideToSide:selectedContent];
                     }
                     completion:^(BOOL finished) {
                         [self completeSlideToSide:selectedContent];
                     }];
}

-(void) doSlideOut:(void (^)(BOOL completed))completion{
    [UIView animateWithDuration:kSlideOutInterval delay:0.0 options:UIViewAnimationCurveEaseInOut animations:^{
        [self slideOut:selectedContent];
    } completion:^(BOOL finished) {
        if (completion) {
            completion(finished);
        }
    }];
}

-(void) doSlideIn:(void (^)(BOOL completed))completion{

    [UIView animateWithDuration:kSlideInInterval delay:0.0 options:UIViewAnimationCurveEaseInOut animations:^{
        [self slideIn:selectedContent];
    } completion:^(BOOL finished) {
        if (completion) {
            completion(finished);
        }
        [self completeSlideIn:selectedContent];
    }];
}


-(void) tapItem:(UIPanGestureRecognizer*)gesture{
    [self switchToContentViewController:selectedContent];
}

-(void) tapShield:(UITapGestureRecognizer*)gesture{
    [self doSlideIn:nil];
}

-(void) panItem:(UIPanGestureRecognizer*)gesture{
    UIView* panningView = gesture.view;
    CGPoint translation = [gesture translationInView:panningView];
    UIView* movingView = selectedContent.view;
    if (movingView.frame.origin.x + translation.x<0) {
        translation.x=0.0;
    }
    if (translation.x>0 && movingView.frame.origin.x >=[self menuSize]) {
        translation.x=0.0;
    }

    [movingView setCenter:CGPointMake([movingView center].x + translation.x, [movingView center].y)];
    [gesture setTranslation:CGPointZero inView:[panningView superview]];
    if ([gesture state] == UIGestureRecognizerStateEnded){
        CGFloat pcenterx = movingView.center.x;
        CGRect bounds = self.view.bounds;
        CGSize size = bounds.size;
        
        if (pcenterx > size.width ) {
            [self doSlideToSide];
        }else{
            [self doSlideIn:nil];
        }
	}
}

-(void) switchToContentViewController:(UINavigationController*) content{
    CGRect bounds = self.view.bounds;
    self.view.userInteractionEnabled = NO;

    Boolean slideOutThenIn = NO;
    if ([slideMenuDataSource respondsToSelector:@selector(slideOutThenIn)]){
        slideOutThenIn = [slideMenuDataSource slideOutThenIn];
    }
    
    if (slideOutThenIn) {
        //Animate out the currently selected UIViewController
        [self doSlideOut:^(BOOL completed) {
            [selectedContent willMoveToParentViewController:nil];
            [selectedContent.view removeFromSuperview];
            [selectedContent removeFromParentViewController];
            
            content.view.frame = CGRectMake(bounds.size.width,0,bounds.size.width,bounds.size.height);
            [self addChildViewController:content];
            [self.view addSubview:content.view];
            selectedContent = content;
            
            [self doSlideIn:^(BOOL completed) {
                [content didMoveToParentViewController:self];
                self.view.userInteractionEnabled = YES;
            }];
        }];
    }else{
        [selectedContent willMoveToParentViewController:nil];
        [selectedContent.view removeFromSuperview];
        [selectedContent removeFromParentViewController];
        [self slideToSide:content];
        [self addChildViewController:content];
        [self.view addSubview:content.view];
        selectedContent = content;
        [self doSlideIn:^(BOOL completed) {
            [content didMoveToParentViewController:self];
            self.view.userInteractionEnabled = YES;
        }];
    }    
}

#pragma mark - UIViewController

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (isFirstViewWillAppear) {
        NSString* identifier= [slideMenuDataSource initialSegueId];
        [self performSegueWithIdentifier:identifier sender:self];
        isFirstViewWillAppear = NO;
    }
}

-(void) viewDidLoad{
    [super viewDidLoad];

    isFirstViewWillAppear = YES;
    self.shield = [[UIView alloc] initWithFrame:CGRectZero];
    self.shieldWithMenu= [[UIView alloc] initWithFrame:CGRectZero];
    
    UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapShield:)];
    [self.shieldWithMenu addGestureRecognizer:tapGesture];
    [tapGesture setDelegate:self];
    
    UIPanGestureRecognizer* panGestureMenu = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panItem:)];
    [panGestureMenu setMaximumNumberOfTouches:2];
    [panGestureMenu setDelegate:self];
    [self.shieldWithMenu addGestureRecognizer:panGestureMenu];

    UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panItem:)];
    [panGesture setMaximumNumberOfTouches:2];
    [panGesture setDelegate:self];
    [self.shield addGestureRecognizer:panGesture];    

    self.tableView.delegate = self;
}
@end
