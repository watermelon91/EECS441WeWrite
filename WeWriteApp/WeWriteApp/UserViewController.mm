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

@synthesize buffer;

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
    deletedChars = [[NSMutableString alloc] init];
    undoStack = [[NSMutableArray alloc] init];
    redoStack = [[NSMutableArray alloc] init];
    userJustSubmitted = NO;
    globalLock = [[SingletonLock alloc] init];
    
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
    lockIsFree = YES;
    
    timer = [NSTimer scheduledTimerWithTimeInterval:100000000 target:self selector:@selector(timerTriggeredSubmission) userInfo:nil repeats:YES];
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
    
    // submit pending changes
    dispatch_async(submissionQueue, ^{
        [self submitLastPacketOfChanges];
    });
    
    @synchronized(globalLock)
    {
        // Pop redoStack
        // We don't push to undoStack, leave it to the SubmitLastPacket function
        if ([redoStack count] == 0) {
            return;
        }
        
        EventBufferWrapper *redoEvent = [redoStack objectAtIndex:0];
        [redoStack removeObjectAtIndex:0];
        
        // Submit event to server.
        EventBuffer *originalEvent = [redoEvent buffer];
        if (originalEvent->eventtype() == EventBuffer_EventType_INSERT)
        {
            startCursorPosition = originalEvent->startlocation();
            newlyInsertedChars = [NSMutableString stringWithFormat:@"%s", originalEvent->contents().c_str()];
            
            // Update UI
            _textViewForUser.scrollEnabled = NO;
            _textViewForUser.text = [NSString stringWithFormat:@"%@%@%@",
                                     [_textViewForUser.text substringToIndex:startCursorPosition],
                                     newlyInsertedChars,
                                     [_textViewForUser.text substringFromIndex:startCursorPosition]];
            _textViewForUser.scrollEnabled = YES;
            
            
        }
        else if (originalEvent->eventtype() == EventBuffer_EventType_DELETE)
        {
            startCursorPosition = originalEvent->startlocation();
            deletedLength = originalEvent->lengthused();
            deletedChars = [NSMutableString stringWithFormat:@"%s", originalEvent->contents().c_str()];
            
            // Update UI
            if (startCursorPosition >= 0) {
                // Update UI with other users' changes
                _textViewForUser.scrollEnabled = NO;
                _textViewForUser.text = [NSString stringWithFormat:@"%@%@",
                                         [_textViewForUser.text substringToIndex:startCursorPosition],
                                         [_textViewForUser.text substringFromIndex:startCursorPosition + deletedLength]];
                _textViewForUser.scrollEnabled = YES;
            }
        }
        else
        {
            NSLog(@"Events other than insert and delete on redo stack.");
            assert(false);
        }
    }
    
    // Submit event to server.
    dispatch_async(submissionQueue, ^{
        [self submitLastPacketOfChanges];
    });
    userJustSubmitted = YES;
}

- (IBAction)undoButtonPressed:(id)sender
{
    NSLog(@"Undo button pressed");
    
    // submit pending changes
    dispatch_async(submissionQueue, ^{
        [self submitLastPacketOfChanges];
    });
    
    @synchronized(globalLock)
    {
        // Pop undoStack;
        if ([undoStack count] == 0)
        {
            return;
        }
        
        EventBufferWrapper *undoEvent = [undoStack objectAtIndex:0];
        [undoStack removeObjectAtIndex:0];
        
        // Push redoStack;
        [redoStack insertObject:undoEvent atIndex:0];
        
        // Submit reverse event to server.
        EventBuffer *originalEvent = [undoEvent buffer];
        if (originalEvent->eventtype() == EventBuffer_EventType_INSERT)
        {
            // Change to delete event
            startCursorPosition = originalEvent->startlocation() + originalEvent->lengthused();
            deletedLength = originalEvent->lengthused();
            deletedChars = [NSMutableString stringWithFormat:@"%s", originalEvent->contents().c_str()];
            
            // Update UI
            if (startCursorPosition >= 0) {
                // Update UI with other users' changes
                _textViewForUser.scrollEnabled = NO;
                _textViewForUser.text = [NSString stringWithFormat:@"%@%@",
                                         [_textViewForUser.text substringToIndex:startCursorPosition - deletedLength],
                                         [_textViewForUser.text substringFromIndex:startCursorPosition]];
                _textViewForUser.scrollEnabled = YES;
            }
            
        }
        else if (originalEvent->eventtype() == EventBuffer_EventType_DELETE)
        {
            // Change to insert event
            startCursorPosition = originalEvent->startlocation() - originalEvent->lengthused();
            newlyInsertedChars = [NSMutableString stringWithFormat:@"%s", originalEvent->contents().c_str()];
            
            // Update UI
            _textViewForUser.scrollEnabled = NO;
            if (startCursorPosition == 0)
            {
                _textViewForUser.text = [NSString stringWithFormat:@"%@%@",
                                         newlyInsertedChars,
                                         [_textViewForUser.text substringFromIndex:startCursorPosition]];
            }
            else
            {
                _textViewForUser.text = [NSString stringWithFormat:@"%@%@%@",
                                         [_textViewForUser.text substringToIndex:startCursorPosition-1],
                                         newlyInsertedChars,
                                         [_textViewForUser.text substringFromIndex:startCursorPosition]];
            }
            _textViewForUser.scrollEnabled = YES;
        }
        else
        {
            NSLog(@"Events other than insert and delete on undo stack.");
            assert(false);
        }
        
        isFromUndoStack = YES;
    }
    
    dispatch_async(submissionQueue, ^{
        [self submitLastPacketOfChanges];
    });
    userJustSubmitted = YES;
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
    
    @synchronized(globalLock)
    {
        // Record newly typed/deleted words in localBuffer
        if (range.length == 1)
        {
            // Delete
            NSLog(@"delete");
            deletedLength++;
            newChar = [[_textViewForUser text] characterAtIndex:newCursorPosition-2];
            [deletedChars insertString:[NSString stringWithFormat:@"%c", currentChar] atIndex:0];
            if([newlyInsertedChars length] > 0)
            {
                NSRange tempRange;
                tempRange.length = 1;
                tempRange.location = [newlyInsertedChars length] - 1;
                [newlyInsertedChars deleteCharactersInRange: tempRange];
                deletedLength--;
            }
            // Check if reached MAX_BUFFER_SIZE
            if (deletedLength > MAX_BUFFER_SIZE) {
                dispatch_async(submissionQueue, ^{
                    [self submitLastPacketOfChanges];
                });
                userJustSubmitted = YES;
            }
            NSLog(@"deletedLength: %d, chars: %@", deletedLength, deletedChars);
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
            if ([newlyInsertedChars length] > MAX_BUFFER_SIZE) {
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
    }
    
    return YES;
}

-(void)textViewDidChangeSelection:(UITextView *)textView
{
    if ([_textViewForUser touchIsWithinView] ) {
        // Submit event
        dispatch_async(submissionQueue, ^{
            [self submitLastPacketOfChanges];
        });
        
        @synchronized(globalLock)
        {
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
    
    int32_t submissionRegID = -1;
    NSData *serialziedLockRequest = nil;
    @synchronized(globalLock)
    {
        if (startCursorPosition < 0) {
            return NO;
        }
        
        // Request for lock
        serialziedLockRequest = [self constrcutLockEvent:YES];
        submissionRegID = [[self client] broadcast:serialziedLockRequest eventType:LOCK_REQUEST_EVENT];
    }
    
    [requestLockCond lock];
    while (!lockIsFree)
    {
        [requestLockCond wait];
    }
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
    
    @synchronized(globalLock)
    {
        NSLog(@"Lock obtained. SubmissionID: %d", submissionRegID);
        
        // Pack localBuffer into Protocol Buffer
        EventBuffer *pendingChangeBuffer = new EventBuffer;
        participantID = [[self client] participantID];
        if ([newlyInsertedChars length] > 0)
        {
            assert(deletedLength >= 0);
            if (deletedLength > 0)
            {
                startCursorPosition = startCursorPosition - deletedLength;
            }
            pendingChangeBuffer->set_participantid(participantID);
            pendingChangeBuffer->set_eventtype(EventBuffer::EventType::EventBuffer_EventType_INSERT);
            pendingChangeBuffer->set_startlocation(startCursorPosition);
            pendingChangeBuffer->set_contents([newlyInsertedChars UTF8String]);
            pendingChangeBuffer->set_lengthused([newlyInsertedChars length]);
        }
        else
        {
            assert([newlyInsertedChars length] == 0);
            if (!isFromUndoStack)
            {
                assert(startCursorPosition - deletedLength >= 0);
            }
            pendingChangeBuffer->set_participantid(participantID);
            pendingChangeBuffer->set_eventtype(EventBuffer::EventType::EventBuffer_EventType_DELETE);
            pendingChangeBuffer->set_startlocation(startCursorPosition);
            pendingChangeBuffer->set_contents([deletedChars UTF8String]);
            pendingChangeBuffer->set_lengthused(deletedLength);
        }
        
        // Serialzie Protocol buffer
        char * dataForSubmissionStr = (char *)malloc(pendingChangeBuffer->ByteSize());
        pendingChangeBuffer->SerializeToArray(dataForSubmissionStr, pendingChangeBuffer->ByteSize());
        NSData * serializedData = [NSData dataWithBytesNoCopy:dataForSubmissionStr length:pendingChangeBuffer->ByteSize()];
        
        // Clear local storage
        [newlyInsertedChars setString:@""];
        [deletedChars setString:@""];
        deletedLength = 0;
        startCursorPosition = -1;
        
        // Push Protocol Buffer onto undo stack;
        if (!isFromUndoStack) {
            EventBufferWrapper *pendingBufferWrapper = [[EventBufferWrapper alloc] initWithBuffer:pendingChangeBuffer];
            [undoStack insertObject:pendingBufferWrapper atIndex:0];
        }
        isFromUndoStack = NO;
        
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
        
        NSData *freeLockReq = [self constrcutLockEvent:NO];
        int32_t subID = [[self client] broadcast:freeLockReq eventType:LOCK_RELEASE_EVENT];
        NSLog(@"Lock release. Submission id: %d.", subID);
        
        [requestLockCond lock];
        requestLockIsSuccess = YES;
        [requestLockCond unlock];
    }
    
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
            // Do nothing.
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_DELETE)
        {
            NSLog(@"Own Delete event received");
            // Do nothing.
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_LOCK_REQUEST)
        {
            NSLog(@"Own Lock request event received");
            [requestLockCond lock];
            if (otherUserHasRequestLockEarlier)
            {
                // Other user requested or holding the lock
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
        else if (bufferReceived.eventtype() == EventBuffer_EventType_LOCK_RELEASE)
        {
            NSLog(@"Own Event Lock Release event received");
            // Do nothing. Only counts receipts from other users.
        }
        else if(bufferReceived.eventtype() == EventBuffer_EventType_UNDO)
        {
            NSLog(@"Own Undo Event Received");
            // Do nothing. Changes already applied.
        }
        else if (bufferReceived.eventtype() == EventBuffer_EventType_REDO)
        {
            NSLog(@"Own Redo Event Received");
            // Do nothing. Changes already applied.
        }
        else
        {
            assert(bufferReceived.eventtype() == EventBuffer_EventType_UNKNOWN);
            NSLog(@"Own Unknown Event Received");
        }
    }
    else
    {
        @synchronized(globalLock)
        {
            // other user's event
            NSLog(@"TextView text length: %d, bufferReceived Start Location: %d", [_textViewForUser.text length], bufferReceived.startlocation());
            if (bufferReceived.startlocation() < 0)
            {
                // Not a legal packet;
                return;
            }
            assert([_textViewForUser.text length] >= bufferReceived.startlocation());
            if (bufferReceived.eventtype() == EventBuffer_EventType_INSERT)
            {
                NSLog(@"Other Insert event received");
                if (bufferReceived.startlocation() >= 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Update UI with other users' changes
                        _textViewForUser.scrollEnabled = NO;
                        NSString *middlePartString = [NSString stringWithUTF8String:bufferReceived.contents().c_str()];
                        NSLog(@"bufferStart: %d, exisingTextL: %d", bufferReceived.startlocation(),([_textViewForUser.text length]-1));
                        assert(bufferReceived.startlocation() <= ([_textViewForUser.text length]));
                        if (bufferReceived.startlocation() == ([_textViewForUser.text length]-1))
                        {
                            // insert at the end of current text
                            NSString *firstPartString = [_textViewForUser.text substringToIndex:bufferReceived.startlocation()];
                            NSLog(@"firstPart Equal: %@", firstPartString);
                            _textViewForUser.text = [firstPartString stringByAppendingString:middlePartString];
                        }
                        else
                        {
                            NSString *firstPartString = [_textViewForUser.text substringToIndex:bufferReceived.startlocation()];
                            NSLog(@"firstPart NOT Equal: %@; bufferEventStart: %d, existingTextLength: %d", firstPartString, bufferReceived.startlocation(), [_textViewForUser.text length]);
                            _textViewForUser.text = [NSString stringWithFormat:@"%@%@%@",
                                                     firstPartString,
                                                     middlePartString,
                                                     [_textViewForUser.text substringFromIndex:bufferReceived.startlocation()]];
                        }
                        _textViewForUser.scrollEnabled = YES;
                    });
                    
                    if ((bufferReceived.startlocation() <= startCursorPosition) && (startCursorPosition >= 0))
                    {
                        startCursorPosition += bufferReceived.lengthused();
                    }
                    
                    // Update offsets in undo and redo stacks
                    [self updateStackOffset:bufferReceived.startlocation()
                               withContents:[NSString stringWithFormat:@"%s", bufferReceived.contents().c_str()]
                              withEventType:bufferReceived.eventtype()
                                   forStack:undoStack];
                    [self updateStackOffset:bufferReceived.startlocation()
                               withContents:[NSString stringWithFormat:@"%s", bufferReceived.contents().c_str()]
                              withEventType:bufferReceived.eventtype()
                                   forStack:redoStack];
                }
            }
            else if (bufferReceived.eventtype() == EventBuffer_EventType_DELETE)
            {
                NSLog(@"Other Delete event received");
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Update UI with other users' changes
                    if (bufferReceived.startlocation() >= 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // Update UI with other users' changes
                            _textViewForUser.scrollEnabled = NO;
                            assert(bufferReceived.startlocation() <= [_textViewForUser.text length]);
                            if (bufferReceived.startlocation() == ([_textViewForUser.text length] - 1))
                            {
                                // delete from the end of current text
                                _textViewForUser.text = [_textViewForUser.text substringToIndex:bufferReceived.startlocation()-bufferReceived.lengthused()];
                            }
                            else
                            {
                                _textViewForUser.text = [NSString stringWithFormat:@"%@%@",
                                                         [_textViewForUser.text substringToIndex:bufferReceived.startlocation()-bufferReceived.lengthused()],
                                                         [_textViewForUser.text substringFromIndex:bufferReceived.startlocation()]];
                            }
                            _textViewForUser.scrollEnabled = YES;
                        });
                    }
                    
                    if ((bufferReceived.startlocation() <= startCursorPosition) && (startCursorPosition >= 0)) {
                        assert(bufferReceived.lengthused() <= startCursorPosition);
                        startCursorPosition -= bufferReceived.lengthused();
                    }
                    
                    // Update offsets in undo and redo stacks
                    [self updateStackOffset:bufferReceived.startlocation()
                               withContents:[NSString stringWithFormat:@"%s", bufferReceived.contents().c_str()]
                              withEventType:bufferReceived.eventtype()
                                   forStack:undoStack];
                    [self updateStackOffset:bufferReceived.startlocation()
                               withContents:[NSString stringWithFormat:@"%s", bufferReceived.contents().c_str()]
                              withEventType:bufferReceived.eventtype()
                                   forStack:redoStack];
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
                    lockIsFree = NO;
                }
                [requestLockCond unlock];
            }
            else if (bufferReceived.eventtype() == EventBuffer_EventType_LOCK_RELEASE)
            {
                NSLog(@"Other Event Lock Release event received");
                [requestLockCond lock];
                lockIsFree = YES;
                [requestLockCond broadcast];
                [requestLockCond unlock];
            }
            else if(bufferReceived.eventtype() == EventBuffer_EventType_UNDO)
            {
                NSLog(@"Other Undo Event Received");
                // Not used.
            }
            else if (bufferReceived.eventtype() == EventBuffer_EventType_REDO)
            {
                NSLog(@"Other Redo Event Received");
                // Not used.
            }
            else
            {
                assert(bufferReceived.eventtype() == EventBuffer_EventType_UNKNOWN);
                NSLog(@"Other Unknown Event Received");
            }
        }
    }
}

- (void) updateStackOffset:(NSInteger) startLocation
              withContents:(NSString *) contents
             withEventType:(EventBuffer_EventType) eventType
                  forStack:(NSMutableArray *) stack
{
    for (int i = 0; i < [stack count]; i++)
    {
        EventBufferWrapper *ebw = [stack objectAtIndex:i];
        assert(ebw.buffer->eventtype() == EventBuffer_EventType_DELETE ||
               ebw.buffer->eventtype() == EventBuffer_EventType_INSERT);
        EventBufferWrapper *possibleSplittedBuffer;
        if (eventType == EventBuffer_EventType_INSERT)
        {
            possibleSplittedBuffer = [self updateOffsetForInsert:startLocation withContents:contents forEventBuffer:ebw];
            if (possibleSplittedBuffer != nil) {
                NSLog(@"Inserted at index: %d", i);
                [stack insertObject:possibleSplittedBuffer atIndex:i];
                i++;
            }
        }
        else
        {
            [self updateOffsetForDelete:startLocation withContents:contents forEventBuffer:ebw];
        }
    }
}

-(EventBufferWrapper *)updateOffsetForInsert:(NSInteger) startLocation
                                withContents:(NSString *) contents
                              forEventBuffer:(EventBufferWrapper *)ebw
{
    @try {
        if (ebw.buffer->eventtype() == EventBuffer_EventType_INSERT)
        {
            if(startLocation <= ebw.buffer->startlocation())
            {
                // insert before this insert chunk
                ebw.buffer->set_startlocation(ebw.buffer->startlocation() + [contents length]);
                return nil;
            }
            else if ((startLocation > ebw.buffer->startlocation()) &&
                     (startLocation < (ebw.buffer->startlocation() + ebw.buffer->lengthused()-1)))
            {
                // insert in the middle of this insert chunk
                // we need to split on insert event into two
                EventBuffer *secondHalfBuffer = new EventBuffer;
                secondHalfBuffer->set_participantid(ebw.buffer->participantid());
                secondHalfBuffer->set_eventtype(ebw.buffer->eventtype());
                secondHalfBuffer->set_startlocation(startLocation+[contents length]);
                NSLog(@"%d", __LINE__);
                std::string temp1 = ebw.buffer->contents().substr(startLocation-ebw.buffer->startlocation(), ebw.buffer->lengthused()-(startLocation-ebw.buffer->startlocation()));
                NSLog(@"temp1: %s", temp1.c_str());
                secondHalfBuffer->set_contents(temp1);
                secondHalfBuffer->set_lengthused(temp1.length());
                
                NSLog(@"%d", __LINE__);
                std::string temp2 = ebw.buffer->contents().substr(0, startLocation-ebw.buffer->startlocation()-1);
                NSLog(@"temp2: %s", temp2.c_str());
                ebw.buffer->set_contents(temp2);
                ebw.buffer->set_lengthused(startLocation);
                
                EventBufferWrapper *splittedBufferSecondHalf = [[EventBufferWrapper alloc] initWithBuffer:secondHalfBuffer];
                return splittedBufferSecondHalf;
            }
            else
            {
                // insert after this insert chunk. don't care.
                return nil;
            }
        }
        else // delete event
        {
            if (startLocation <= ebw.buffer->startlocation()) {
                // delete before this insert chunk
                ebw.buffer->set_startlocation(ebw.buffer->startlocation() - [contents length]);
                return nil;
            }
            else
            {
                // since it's delete, the contents are no longer on the screen.
                // so no one can affect the deleted contents besides shifting the whole
                // chunk forward or backward.
                return nil;
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception: %@", exception);
    }

}

-(void)updateOffsetForDelete:(NSInteger) startLocation
                                withContents:(NSString *) contents
                              forEventBuffer:(EventBufferWrapper *)ebw
{
    if (ebw.buffer->eventtype() == EventBuffer_EventType_INSERT) {
        if(startLocation <= ebw.buffer->startlocation())
        {
            // insert before this delete chunk
            ebw.buffer->set_startlocation(ebw.buffer->startlocation() + [contents length]);
        }
        else if ((startLocation > ebw.buffer->startlocation()) &&
                 (startLocation < (ebw.buffer->startlocation() + ebw.buffer->lengthused()-1)))
        {
            // delete in the middle of this insert chunk
            std::string firstHalf;
            if (startLocation - ebw.buffer->startlocation() >= [contents length])
            {
                firstHalf = ebw.buffer->contents().substr(0, startLocation-ebw.buffer->startlocation() - [contents length]);
            }
            else
            {
                firstHalf = "";
            }
            std::string secondHalf = ebw.buffer->contents().substr(startLocation-ebw.buffer->startlocation(), ebw.buffer->lengthused()-startLocation);
            ebw.buffer->set_contents(firstHalf.append(secondHalf));
            ebw.buffer->set_lengthused(ebw.buffer->contents().length());
        }
        else
        {
            // insert after this delete chunk. don't care.
        }
    }
    else // delete event
    {
        if (startLocation <= ebw.buffer->startlocation()) {
            // delete before this delete chunk
            ebw.buffer->set_startlocation(ebw.buffer->startlocation() - [contents length]);
        }
        else
        {
            // delete after this delete starting point. don't care
        }
    }
}

- (NSData *) constrcutLockEvent:(BOOL) isRequest
{
    // Construct lock buffer
    EventBuffer *lockReqBuffer = new EventBuffer;
    lockReqBuffer->set_participantid(participantID);
    if (isRequest)
    {
        lockReqBuffer->set_eventtype(EventBuffer::EventType::EventBuffer_EventType_LOCK_REQUEST);
    }
    else
    {
        lockReqBuffer->set_eventtype(EventBuffer::EventType::EventBuffer_EventType_LOCK_RELEASE);
    }

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
