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

@synthesize client, baseFileData, loginScreenSessionIDTextView;

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
        UserViewController * destC = [segue destinationViewController];
        destC.client = client;
    }
}

- (IBAction)createSessionButtonPressed:(id)sender
{
    srand(time(NULL));
    int tempID = rand();
    NSArray * tagArray = [[NSArray alloc] initWithObjects:@"MaizeIceCream", nil];
    NSString * sessionName = [[NSString alloc] initWithFormat:@"MaizeIceCream%d", tempID];
    
    [[self client] createSessionWithName:sessionName tags:tagArray password:@"IceCream" participantLimit:0 startPaused:NO completionHandler:^(int64_t sessionID, CollabrifyError *error){
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
    NSArray * tagArray = [[NSArray alloc] initWithObjects:@"MaizeIceCream", nil];
    [[self client] listSessionsWithTags:tagArray completionHandler:^(NSArray *sessionList, CollabrifyError *error){
        if (!error)
        {
            assert([sessionList count] > 0);
            int64_t userIuputSessionID = [[loginScreenSessionIDTextView text] longLongValue];
            
            for (CollabrifySession *s in sessionList)
            {
                if(s.sessionID == userIuputSessionID)
                {
                    [[self client] joinSessionWithID: s.sessionID password:@"IceCream" completionHandler:^(int64_t maxOrderID, int32_t baseFileSize, CollabrifyError *error){
                        if(!error){
                            [self performSegueWithIdentifier:@"LoginTransitionSegue" sender:sender];
                        }
                    }];
                    break;
                }
            }
        }
    }];
}

// The part below is only needed when we need to support basefile
// Also need to add receive function in JoinSession portion
/*
-(void)client:(CollabrifyClient *)client receivedBaseFileChunk:(NSData *)data
{
    if (data == nil) {
        // Done
    }
    else
    {
        // APPEND DATA and UPDATE UI WHEN DONE
    }
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
}*/

@end
