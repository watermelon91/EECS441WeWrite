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
    userJustSubmitted = NO;
    
    [[self client] setDelegate:self];
    [[self client] setDataSource:self];
    [[self client] resumeEvents];
    
    participantID = [[self client] participantID];
    NSLog(@"participantID: %lld", participantID);
    
    submissionQueue = dispatch_queue_create("SubmissionQueue", 0);
    receiptionQueue = dispatch_queue_create("ReceptionQueue", 0);
    requestLockCond = [[NSCondition alloc] init];
    requestLockIsSuccess = NO;
    isWaitingForLockRequestResponse = NO;
    otherUserHasRequestLockEarlier = NO;
    
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
    // Submit event to server. // OFFSET
}

- (IBAction)undoButtonPressed:(id)sender
{
    NSLog(@"Undo button pressed");
    // Pop undoStack;
    // Push redoStack;
    // Submit reverse event to server. // OFFSET
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
            dispatch_async(submissionQueue, ^{
                [self submitLastPacketOfChanges];
                 });
            userJustSubmitted = YES;
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
    if ([_textViewForUser touchIsWithinView] ) {
        // Submit event
        dispatch_async(submissionQueue, ^{
            [self submitLastPacketOfChanges];
        });
        
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
    else
    {
        NSLog(@"Touch outside UITextView");
    }
}

-(void)timerTriggeredSubmission
{
    if (!userJustSubmitted)
    {
        dispatch_async(submissionQueue, ^{
            [self submitLastPacketOfChanges];
        });
        NSLog(@"TimerTriggeredSubmission called. Submission performed.");
    }
    else
    {
        userJustSubmitted = NO;
        NSLog(@"TimerTriggeredSubmission called. Submission NOT performed.");
    }
    
}

-(BOOL)submitLastPacketOfChanges
{
    NSLog(@"Submission of last packet called.");
    
    // Request for lock
    NSData *serialziedLockRequest = [self requestLock];
    [requestLockCond lock];
    int32_t submissionRegID = [[self client] broadcast:serialziedLockRequest eventType:LOCK_REQUEST_EVENT];
    while (!requestLockIsSuccess) {
        isWaitingForLockRequestResponse = YES;
        if (otherUserHasRequestLockEarlier) {
            // Broadcast request for lock
            submissionRegID = [[self client] broadcast:serialziedLockRequest eventType:LOCK_REQUEST_EVENT];
            otherUserHasRequestLockEarlier = NO;
        }
        [requestLockCond wait];
    }
    requestLockIsSuccess = NO;
    [requestLockCond unlock];
    NSLog(@"Lock obtained. SubmissionID: %d", submissionRegID);
    
    // Pack localBuffer into Protocol Buffer
    EventBuffer *pendingChangeBuffer = new EventBuffer;
    participantID = [[self client] participantID];
    if (deletedLength > 0)
    {
        assert([newlyInsertedChars length] == 0);
        pendingChangeBuffer->set_participantid(participantID);
        pendingChangeBuffer->set_eventtype(EventBuffer::EventType::EventBuffer_EventType_DELETE);
        pendingChangeBuffer->set_startlocation(startCursorPosition);
        pendingChangeBuffer->set_contents("");
        pendingChangeBuffer->set_lengthused(0);
    }
    else
    {
        assert(deletedLength == 0);
        pendingChangeBuffer->set_participantid(participantID);
        pendingChangeBuffer->set_eventtype(EventBuffer::EventType::EventBuffer_EventType_INSERT);
        pendingChangeBuffer->set_startlocation(startCursorPosition);
        pendingChangeBuffer->set_contents([newlyInsertedChars UTF8String]);
        pendingChangeBuffer->set_lengthused([newlyInsertedChars length]);
    }

    // Serialzie Protocol buffer
    char * dataForSubmissionStr = (char *)malloc(pendingChangeBuffer->ByteSize());
    pendingChangeBuffer->SerializeToArray(dataForSubmissionStr, pendingChangeBuffer->ByteSize());
    NSData * serializedData = [NSData dataWithBytesNoCopy:dataForSubmissionStr length:pendingChangeBuffer->ByteSize()];
    
    // Clear local storage
    [newlyInsertedChars setString:@""];
    deletedLength = 0;
    startCursorPosition = -1;
    
    // Push Protocol Buffer onto undo stack;
    EventBufferWrapper *pendingBufferWrapper = [[EventBufferWrapper alloc] initWithBuffer:pendingChangeBuffer];
    [undoStack insertObject:pendingBufferWrapper atIndex:0];
    
    // Broadcast Event
    int32_t submissionRegistrationID = -1;
    if (pendingChangeBuffer->eventtype() == wewriteapp::EventBuffer_EventType_DELETE)
    {
        submissionRegistrationID = [[self client] broadcast:serializedData eventType:DELETE_EVENT];
    }
    else if (pendingChangeBuffer->eventtype() == wewriteapp::EventBuffer_EventType_INSERT)
    {
        submissionRegistrationID = [[self client] broadcast:serializedData eventType:INSERT_EVENT];
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
    dispatch_async(receiptionQueue, ^{
        [self parseReceivedEvent:eventType data:data];
        });
}

- (void) parseReceivedEvent:(NSString *)eventType data:(NSData *)data
{
    EventBuffer bufferReceived;
    bufferReceived.ParseFromArray([data bytes], [data length]);
    NSLog(@"parsedResult: %d, %s, %d, %d, %d", bufferReceived.participantid(), bufferReceived.contents().c_str(), bufferReceived.lengthused(), bufferReceived.eventtype(), bufferReceived.startlocation());
    if(bufferReceived.participantid() == participantID)
    {
        // user's own event
        if (bufferReceived.eventtype() == EventBuffer_EventType_INSERT)
        {
            NSLog(@"Own Insert event received");
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_DELETE)
        {
            NSLog(@"Own Delete event received");
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_LOCK_REQUEST)
        {
            NSLog(@"Own Lock request event received");
            [requestLockCond lock];
            if (otherUserHasRequestLockEarlier)
            {
                // Need to wait for the next event
                requestLockIsSuccess = NO;
                isWaitingForLockRequestResponse = NO;
                [requestLockCond broadcast];
            }
            else
            {
                // Get one's own lock request event without being interfered by others' lock event
                requestLockIsSuccess = YES;
                isWaitingForLockRequestResponse = NO;
                [requestLockCond broadcast];
            }
            [requestLockCond unlock];
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_RECEIPT_CONFIRMATION)
        {
            NSLog(@"Own Event Receipt confirmation event received");
        }
        else if(bufferReceived.eventtype() == EventBuffer_EventType_UNDO)
        {
            NSLog(@"Own Undo Event Received");
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_REDO)
        {
            NSLog(@"Own Redo Event Received");
        }
        else
        {
            assert(bufferReceived.eventtype() == EventBuffer_EventType_UNKNOWN);
            NSLog(@"Own Unknown Event Received");
        }
    }
    else
    {
        // other user's event
        if (bufferReceived.eventtype() == EventBuffer_EventType_INSERT)
        {
            NSLog(@"Other Insert event received");
            if (bufferReceived.startlocation() >= 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Update UI with other users' changes
                    _textViewForUser.scrollEnabled = NO;
                    _textViewForUser.text = [NSString stringWithFormat:@"%@%@%@",
                                             [_textViewForUser.text substringToIndex:bufferReceived.startlocation()],
                                             [NSString stringWithFormat:@"%s", bufferReceived.contents().substr(0, bufferReceived.lengthused()).c_str()],
                                             [_textViewForUser.text substringFromIndex:bufferReceived.startlocation()]];
                    _textViewForUser.scrollEnabled = YES;
                });
            }
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_DELETE)
        {
            NSLog(@"Other Delete event received");
            dispatch_async(dispatch_get_main_queue(), ^{
                // Update UI with other users' changes
                
            });
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_LOCK_REQUEST)
        {
            NSLog(@"Other Lock request event received");
            [requestLockCond lock];
            if (isWaitingForLockRequestResponse)
            {
                // User waiting for its lock and received some other user's request first
                otherUserHasRequestLockEarlier = YES;
            }
            [requestLockCond unlock];
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_RECEIPT_CONFIRMATION)
        {
            NSLog(@"Other Event Receipt confirmation event received");
        }
        else if(bufferReceived.eventtype() == EventBuffer_EventType_UNDO)
        {
            NSLog(@"Other Undo Event Received");
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_REDO)
        {
            NSLog(@"Other Redo Event Received");
        }
        else
        {
            assert(bufferReceived.eventtype() == EventBuffer_EventType_UNKNOWN);
            NSLog(@"Other Unknown Event Received");
        }
    }
}

- (NSData *) requestLock
{
    // Construct lock buffer
    EventBuffer *lockReqBuffer = new EventBuffer;
    lockReqBuffer->set_participantid(participantID);
    lockReqBuffer->set_eventtype(EventBuffer::EventType::EventBuffer_EventType_LOCK_REQUEST);
    lockReqBuffer->set_startlocation(-1);
    lockReqBuffer->set_contents("");
    lockReqBuffer->set_lengthused(0);
    
    // Serialzie Protocol buffer
    char * dataForSubmissionStr = (char *)malloc(lockReqBuffer->ByteSize());
    lockReqBuffer->SerializeToArray(dataForSubmissionStr, lockReqBuffer->ByteSize());
    NSData * serializedData = [NSData dataWithBytesNoCopy:dataForSubmissionStr length:lockReqBuffer->ByteSize()];
    
    delete lockReqBuffer;
    
    return serializedData;
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
