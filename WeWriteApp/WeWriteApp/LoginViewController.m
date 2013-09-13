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

@synthesize client, baseFileData;

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
    NSError *error;
    [self setClient:[[CollabrifyClient alloc] initWithGmail:@"gmail@gmail.com" displayName:@"Maize" accountGmail:@"441fall2013@umich.edu" accessToken:@"XY3721425NoScOpE" getLatestEvent:NO error:&error]];
    [[self client] setDelegate:self];
    [[self client] setDataSource:self];
    
    baseFileData = [[NSData alloc] init];
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
    NSArray * tagArray = [[NSArray alloc] initWithObjects:@"MaizeSession", nil];
    [[self client] createSessionWithBaseFileWithName:@"MaizeIceCream" tags:tagArray password:@"IceCream" participantLimit:0 startPaused:NO completionHandler:^(int64_t sessionID, CollabrifyError *error){
        if(!error)
        {
            [self performSegueWithIdentifier:@"LoginTransitionSegue" sender:sender];
        }
        else
        {
            NSLog(@"Create Session error: %@", error);
        }
    }];
}

- (IBAction)joinSessionButtonPressed:(id)sender
{
    [self performSegueWithIdentifier:@"LoginTransitionSegue" sender:sender];
}

-(NSData *) client:(CollabrifyClient *)client requestsBaseFileChunkForCurrentBaseFileSize:(NSInteger)baseFileSize
{
    if(![self baseFileData])
    {
        NSString *string = @"This is sample data for baseFile";
        baseFileData = [string dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSInteger length = [[self baseFileData] length];
    
    if(length == 0)
    {
        return nil;
    }
    
    return [NSData dataWithBytes:([[self baseFileData] bytes] + baseFileSize) length:length];
}

@end
