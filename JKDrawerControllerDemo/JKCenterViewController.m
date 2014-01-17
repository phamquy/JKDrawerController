//
//  JKCenterViewController.m
//  JKDrawerControllerDemo
//
//  Created by jack on 1/13/14.
//  Copyright (c) 2014 jkorp. All rights reserved.
//

#import "JKCenterViewController.h"
#import "JKDrawerController.h"

@interface JKCenterViewController ()

@end

@implementation JKCenterViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self.view setBackgroundColor:[UIColor whiteColor]];
    UILabel* label = [[UILabel alloc] initWithFrame: CGRectInset(self.view.bounds, 50, 150)];
    label.text = @"Center view";
    [self.view addSubview: label];
    
    UIButton* showLeft = [UIButton buttonWithType:(UIButtonTypeRoundedRect)];
    [showLeft addTarget:self
               action:@selector(showLeft:)
     forControlEvents:(UIControlEventTouchUpInside)];
    [showLeft setFrame:(CGRect){{50,5},{100,50}}];
    [showLeft setTitle:@"Show left" forState:(UIControlStateNormal)];
    [showLeft setBackgroundColor:[UIColor blueColor]];
    [self.view addSubview:showLeft];

    
    UIButton* showRight = [UIButton buttonWithType:(UIButtonTypeRoundedRect)];
    [showRight addTarget:self
                 action:@selector(showRight:)
       forControlEvents:(UIControlEventTouchUpInside)];
    [showRight setFrame:(CGRect){{150,5},{100,50}}];
    [showRight setTitle:@"Show right" forState:(UIControlStateNormal)];
    [showRight setBackgroundColor:[UIColor greenColor]];
    [self.view addSubview:showRight];

    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void) showLeft:(id) sender
{
    [[self drawerController]
     toggleDrawerSide:(JKDrawerSideLeft)
     animated:YES
     completion:^(BOOL finished) {
         NSLog(@"Left drawer is opened");
     }];
}


- (void) showRight:(id) sender
{
    [[self drawerController] toggleDrawerSide:(JKDrawerSideRight) animated:YES completion:^(BOOL finished) {
        NSLog(@"Right drawer is opened");
    }];
}

@end
