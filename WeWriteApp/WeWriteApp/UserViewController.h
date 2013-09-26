//
//  UserViewController.h
//  WeWriteApp
//
//  Created by Watermelon on 9/6/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Collabrify/Collabrify.h>
#import <google/protobuf/io/zero_copy_stream_impl_lite.h>
#import <google/protobuf/io/coded_stream.h>
#import "protocolBufferRawStructDefinition.pb.h"
#import "userTextView.h"
#import "SingletonLock.h"

using namespace wewriteapp;

@interface EventBufferWrapper : NSObject
@property (nonatomic) EventBuffer *buffer;
-(id)initWithBuffer:(EventBuffer*) inBuffer;
@end

@interface UserViewController : UIViewController <UITextViewDelegate, CollabrifyClientDelegate, CollabrifyClientDataSource>{
    NSInteger startCursorPosition;  // submissionLastPacket, parseReceivedEvent, main
    NSInteger currentCursorPosition;
    char currentChar;
    NSInteger deletedLength; // parseReceivedEvent, main
    NSMutableString *newlyInsertedChars; // submitLastPacket, main
    NSMutableString *deletedChars; // submitLastPacket, main
    
    NSMutableArray *undoStack;  // stack containing EventBuffer objects; main, submit, parse
    NSMutableArray *redoStack;  // stack containing EventBuffer objects; parse, main
    
    NSTimer *timer;
    int64_t participantID;
    dispatch_queue_t submissionQueue;
    dispatch_queue_t receiptionQueue;
    
    BOOL userJustSubmitted; // for disable timer right after a typing-triggered submission
    NSCondition *requestLockCond; // condition var for requestLock lock
    BOOL requestLockIsSuccess;
    BOOL isWaitingForLockRequestResponse;
    BOOL otherUserHasRequestLockEarlier;
    BOOL isFromUndoStack; // main, submit
    BOOL lockIsFree;
    
    NSInteger localCursorPosition;
    
    SingletonLock *globalLock;
}

//-(void)setClientFromLogin:(CollabrifyClient *)inClient;

@property (weak, nonatomic) IBOutlet UILabel *sessionIDLabel;

@property (strong, nonatomic) CollabrifyClient *client;

@property (weak, nonatomic) IBOutlet UIButton *undoButton;
@property (weak, nonatomic) IBOutlet UIButton *redoButton;
@property (weak, nonatomic) IBOutlet userTextView *textViewForUser;
@end

