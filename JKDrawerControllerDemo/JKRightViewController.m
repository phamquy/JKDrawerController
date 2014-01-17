//
//  JKRightViewController.m
//  JKDrawerControllerDemo
//
//  Created by jack on 1/13/14.
//  Copyright (c) 2014 jkorp. All rights reserved.
//

#import "JKRightViewController.h"
#import "JKDrawerController.h"

@interface JKRightViewController ()

@end

@implementation JKRightViewController

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
    [self.view setBackgroundColor:[UIColor greenColor]];
    UILabel* label = [[UILabel alloc] initWithFrame: CGRectInset(self.view.bounds, 50, 150)];
    label.text = @"Right view";
    [self.view addSubview: label];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
