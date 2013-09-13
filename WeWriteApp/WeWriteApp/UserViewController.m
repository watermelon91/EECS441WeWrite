//
//  UserViewController.m
//  WeWriteApp
//
//  Created by Watermelon on 9/6/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import "UserViewController.h"
#import "CustomDatatype.h"

@interface bufferNode ()
@end

@implementation bufferNode

@synthesize sizeOfBuffer, lockIsFree;

-(id)init
{
    self = [super init];
    if(self)
    {
        sizeOfBuffer = 0;
        lockIsFree = YES;
    }
    return self;
}

@end

@interface pendingChangeBuffer ()
@end

@implementation pendingChangeBuffer

@synthesize startPosition, content;

-(id)init
{
    self = [super init];
    if(self)
    {
        startPosition = 0;
        content = [[NSString alloc] init];
    }
    return self;
}

@end


@interface UserViewController ()

@end

@implementation UserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.textViewForUser.delegate = self;
    localBuffer = [[pendingChangeBuffer alloc] init];
    currentPosition = 0;
    bufferList = [[NSMutableArray alloc] init];
    undoStack = [[NSMutableArray alloc] init];
    redoStack = [[NSMutableArray alloc] init];
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(timerTriggeredSubmission) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([[segue identifier] isEqualToString:@"LogoutTransitionSegue"]){
        UIViewController * destC = [segue destinationViewController];
    }
}

-(void)textViewDidBeginEditing:(UITextView *)textView
{
    NSLog(@"Begin");
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    NSLog(@"End");
}

- (IBAction)exitSessionButtonPressed:(id)sender
{
    [self performSegueWithIdentifier:@"LogoutTransitionSegue" sender:sender];
}

- (IBAction)redoButtonPressed:(id)sender
{
    NSLog(@"Redo button pressed.");
    // Pop redoStack;
    // Push undoStack;
}

- (IBAction)undoButtonPressed:(id)sender
{
    NSLog(@"Undo button pressed");
    // Pop undoStack;
    // Push redoStack;
}

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{    
    NSLog(@"SelectedRange: %d, %d", textView.selectedRange.length, textView.selectedRange.location);
    
    // Record newly typed/deleted words in localBuffer
    
    // Update current cursor position
    
    return YES;
}

-(void)textViewDidChangeSelection:(UITextView *)textView
{
    NSLog(@"cursor location chagned");
    NSLog(@"current cursor location: %d, %d", textView.selectedRange.length, textView.selectedRange.location);
    
    // Pack latest changes
    
    // Request lock
    
    // Submit event
    //[self submitLastPacketOfChanges];
    
    // Update current cursor position
    //currentPosition = textView.selectedRange.location;
}

-(void)timerTriggeredSubmission
{
    [self submitLastPacketOfChanges];
    NSLog(@"TimerTriggeredSubmission called.");
}

-(BOOL)submitLastPacketOfChanges
{
    // Update start and end position
    NSLog(@"Submission of last packet called.");
    return YES; // UPDATE HERE to reflect actual submission status
}

@end
