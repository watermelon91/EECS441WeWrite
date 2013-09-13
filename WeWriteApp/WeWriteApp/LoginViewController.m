//
//  LoginViewController.m
//  WeWriteApp
//
//  Created by Watermelon on 9/12/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import "LoginViewController.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([[segue identifier] isEqualToString:@"LoginTransitionSegue"]){
        UIViewController * destC = [segue destinationViewController];
    }
}

- (IBAction)createSessionButtonPressed:(id)sender
{
    [self performSegueWithIdentifier:@"LoginTransitionSegue" sender:sender];
}

- (IBAction)joinSessionButtonPressed:(id)sender
{
    [self performSegueWithIdentifier:@"LoginTransitionSegue" sender:sender];
}

@end
