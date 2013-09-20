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

@interface EventBufferWrapper ()

@end

@implementation EventBufferWrapper
-(id)initWithBuffer:(wewriteapp::EventBuffer *)inBuffer
{
    self = [super init];
    if (self) {
        buffer = inBuffer;
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
    
    [_textViewForUser becomeFirstResponder];
    [_textViewForUser selectedRange] = NSMakeRange(0, 1);
    
	// Do any additional setup after loading the view, typically from a nib.
    self.textViewForUser.delegate = self;
    currentCursorPosition = 0;
    startCursorPosition = -1;
    deletedLength = 0;
    newlyInsertedChars = [[NSMutableString alloc] init];
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
    NSLog(@"Text: %@; Range: %d; %d", text, range.location, range.length);
    // Disable multi-deletion
    if (range.length > 1)
    {
        return NO;
    }
    
    NSInteger newCursorPosition = textView.selectedRange.location;
    char newChar = 0;
    NSLog(@"NewCursorPosition for typing %d; text length: %d", newCursorPosition, [text length]);
    
    // Record newly typed/deleted words in localBuffer
    if (range.length == 1)
    {
        // Delete
        NSLog(@"delte");
        deletedLength++;
        if([newlyInsertedChars length] > 0)
        {
            NSRange tempRange;
            tempRange.length = 1;
            tempRange.location = [newlyInsertedChars length] - 1;
            [newlyInsertedChars deleteCharactersInRange: tempRange];
        }
        NSLog(@"deletedLength: %d", deletedLength);
    }
    else if(range.length == 0)
    {
        // Insert
        NSLog(@"insert");
        if ([text length] == 0) { // no real input
            return YES;
        }

        newChar = [text characterAtIndex:0];
        [newlyInsertedChars appendFormat:@"%c", newChar];
        
        if (deletedLength > 0) {
            deletedLength--;
        }
        
        // Check if reached MAX_BUFFER_SIZE
        if ([newlyInsertedChars length] > MAX_BUFFER_SIZE ) {
            [self submitLastPacketOfChanges];
        }
        NSLog(@"newlyInsertedChars: %@", newlyInsertedChars);
    }
    else
    {
        abort();
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
    if (startCursorPosition == -1)
    {
        startCursorPosition = textView.selectedRange.location;
    }
    
    if (textView.selectedRange.location <= [textView.text length])
    {
        currentChar = [textView.text characterAtIndex:textView.selectedRange.location-1];
    }
    else
    {
        currentChar = 0;
    }
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
    EventBuffer *pendingChangeBuffer = new EventBuffer;
    if (deletedLength > 0)
    {
        assert([newlyInsertedChars length] == 0);
        pendingChangeBuffer->set_eventtype(EventBuffer::EventType::EventBuffer_EventType_DELETE);
        pendingChangeBuffer->set_startlocation(startCursorPosition);
        pendingChangeBuffer->set_contents(NULL);
        pendingChangeBuffer->set_lengthused(0);
    }
    else
    {
        assert(deletedLength == 0);
        pendingChangeBuffer->set_eventtype(EventBuffer::EventType::EventBuffer_EventType_INSERT);
        pendingChangeBuffer->set_startlocation(startCursorPosition);
        pendingChangeBuffer->set_contents([newlyInsertedChars UTF8String]);
        pendingChangeBuffer->set_lengthused([newlyInsertedChars length]);
    }

    // Serialzie Protocol buffer
    std::string dataForSubmissionStr;
    pendingChangeBuffer->SerializeToString(&dataForSubmissionStr);
    NSString *dataForSubmission = [NSString stringWithFormat:@"%s", dataForSubmissionStr.c_str()];
    
    // Clear local storage
    [newlyInsertedChars setString:@""];
    deletedLength = 0;
    startCursorPosition = -1;
    
    // Push Protocol Buffer onto undo stack;
    EventBufferWrapper *pendingBufferWrapper = [[EventBufferWrapper alloc] initWithBuffer:pendingChangeBuffer];
    [undoStack insertObject:pendingBufferWrapper atIndex:0];
    
    // Request for lock
    
    // Broadcast Event
    int32_t submissionRegistrationID = -1;
    if (pendingChangeBuffer->eventtype() == wewriteapp::EventBuffer_EventType_DELETE)
    {
        submissionRegistrationID = [[self client] broadcast:[dataForSubmission dataUsingEncoding:NSUTF8StringEncoding] eventType:DELETE_EVENT];
    }
    else if (pendingChangeBuffer->eventtype() == wewriteapp::EventBuffer_EventType_INSERT)
    {
        submissionRegistrationID = [[self client] broadcast:[dataForSubmission dataUsingEncoding:NSUTF8StringEncoding] eventType:INSERT_EVENT];
    }
    else if (pendingChangeBuffer->eventtype() == wewriteapp::EventBuffer_EventType_LOCK_REQUEST)
    {
        submissionRegistrationID = [[self client] broadcast:[dataForSubmission dataUsingEncoding:NSUTF8StringEncoding] eventType:LOCK_REQUEST_EVENT];
    }
    else if (pendingChangeBuffer->eventtype() == wewriteapp::EventBuffer_EventType_RECEIPT_CONFIRMATION)
    {
        submissionRegistrationID = [[self client] broadcast:[dataForSubmission dataUsingEncoding:NSUTF8StringEncoding] eventType:RECEIPT_CONFIRMATION_EVENT];
    }
    else
    {
        NSLog(@"Other event type: %d", pendingChangeBuffer->eventtype());
    }
 
    NSLog(@"SubmissionID: %d", submissionRegistrationID);
    
    return YES; // UPDATE HERE to reflect actual submission status
}

- (void) client:(CollabrifyClient *)client receivedEventWithOrderID:(int64_t)orderID submissionRegistrationID:(int32_t)submissionRegistrationID eventType:(NSString *)eventType data:(NSData *)data
{
    NSLog(@"Server listener is called!");
}

-(void)client:(CollabrifyClient *)client encounteredError:(CollabrifyError *)error
{
    if ([error isMemberOfClass:[CollabrifyUnrecoverableError class]]) {
        NSLog(@"Unrecoverable Error");
    }
    
    switch ([error classType]) {
        case CollabrifyClassTypeAddEvent:
        {
            int32_t submissionRegID;
            NSData *eventData;
            
            submissionRegID = [[[error userInfo] valueForKey:CollabrifySubmissionRegistrationIDKey] intValue];
            eventData = [[error userInfo] valueForKey:CollabrifyDataKey];
            break;
        }
            
        default:
            break;
    }
}

@end
