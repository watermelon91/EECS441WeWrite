//
//  UserViewController.m
//  WeWriteApp
//
//  Created by Watermelon on 9/6/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import "UserViewController.h"
#import "CustomDatatype.h"

using namespace wewriteapp;

@interface bufferNode ()
@end

@implementation bufferNode

@synthesize eventBuffer, lockIsFree;

-(id)init
{
    self = [super init];
    if(self)
    {
        eventBuffer = NULL;
        lockIsFree = YES;
    }
    return self;
}

@end

@interface UserViewController ()

@end

@implementation UserViewController

@synthesize client, sessionIDLabel;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.textViewForUser.delegate = self;
    currentCursorPosition = 0;
    startCursorPosition = -1;
    deletedLength = 0;
    newlyInsertedChars = [[NSMutableString alloc] init];
    bufferList = [[NSMutableArray alloc] init];
    undoStack = [[NSMutableArray alloc] init];
    redoStack = [[NSMutableArray alloc] init];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:10000000 target:self selector:@selector(timerTriggeredSubmission) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    
    sessionIDLabel.text = [NSString stringWithFormat:@"%lld", [client currentSessionID]];
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

- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]])
    {
        [(UITapGestureRecognizer *)gestureRecognizer setNumberOfTapsRequired:1];
    }
    
    [self addGestureRecognizer:gestureRecognizer];
}

/*-(void)setClientFromLogin:(CollabrifyClient *)inClient
{
 
}*/

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
    // CHECK IF IS OWNER
    [[self client] leaveAndDeleteSession:NO completionHandler:^(BOOL success, CollabrifyError *error){
        if(success)
        {
            [timer invalidate];
            [self performSegueWithIdentifier:@"LogoutTransitionSegue" sender:sender];
        }
    }];
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
    // Disable multi-deletion
    if (range.length > 1)
    {
        return NO;
    }
    
    NSInteger newCursorPosition = textView.selectedRange.location;
    char newChar = 0;
    NSLog(@"NewCursorPosition for typing %d; text length: %d", newCursorPosition, [text length]);
    
    // Record newly typed/deleted words in localBuffer
    if (newCursorPosition <= currentCursorPosition)
    {
        // Delete
        NSLog(@"delte");
        deletedLength++;
    }
    else
    {
        // Insert
        NSLog(@"insert");
        if ([text length] == 0) { // no real input
            return YES;
        }

        newChar = [text characterAtIndex:0];
        [newlyInsertedChars appendFormat:@"%c", newChar];
        
        // Check if reached MAX_BUFFER_SIZE
        if ([newlyInsertedChars length] > MAX_BUFFER_SIZE ) {
            [self submitLastPacketOfChanges];
        }
        NSLog(@"newlyInsertedChars: %@", newlyInsertedChars);
    }
    
    // Update current cursor position & char
    if (startCursorPosition == -1) {
        startCursorPosition = newCursorPosition;
    }
    currentChar = newChar;
    currentCursorPosition = newCursorPosition;
    
    return YES;
}

-(void)textViewDidChangeSelection:(UITextView *)textView
{
    // Submit event
    [self submitLastPacketOfChanges];
    
    // Update current cursor position
    if (startCursorPosition == -1) {
        startCursorPosition = textView.selectedRange.location;
    }
    currentChar = [textView.text characterAtIndex:textView.selectedRange.location-1];
    currentCursorPosition = textView.selectedRange.location;
    
    NSLog(@"CursorLocation Manually changed.");
    NSLog(@"current cursor location: %d; currentChar: %c", textView.selectedRange.location, currentChar);
}

-(void)timerTriggeredSubmission
{
    [self submitLastPacketOfChanges];
    NSLog(@"TimerTriggeredSubmission called.");
}

-(BOOL)submitLastPacketOfChanges
{
    NSLog(@"Submission of last packet called.");
    
    // Pack localBuffer into Protocol Buffer
    
    // Clear local storage
    [newlyInsertedChars setString:@""];
    deletedLength = 0;
    startCursorPosition = -1;
    
    // Push Protocol Buffer onto undo stack;
    
    // Request for lock
    
    // Broadcast Event
    
    return YES; // UPDATE HERE to reflect actual submission status
}

#warning listen to broadcasted event
/* if request lock event:
 *      lock free-reply OK
 *      lock busy-reply NO
 * if request lock response:
 *      OK - wait till receive all responses;
 *      NO - keep send request
 * if receipt confirmation for this device's event:
 *      release lock
 *      free EventLock memory and set NULL
 * if not this device's events:
 *      update UITextView
 *      send update confirmation
 * all other events:
 *      ignore
 */

@end
