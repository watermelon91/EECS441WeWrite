//
//  UserViewController.h
//  WeWriteApp
//
//  Created by Watermelon on 9/6/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Collabrify/Collabrify.h>
#import "protocoalBufferRawDefinition.pb.h"
#import <google/protobuf/io/zero_copy_stream_impl_lite.h>
#import <google/protobuf/io/coded_stream.h>

using namespace wewriteapp;

@interface EventBufferWrapper : NSObject{
    EventBuffer *buffer;
}
-(id)initWithBuffer:(EventBuffer*) inBuffer;
@end

@interface UserViewController : UIViewController <UITextViewDelegate, CollabrifyClientDelegate, CollabrifyClientDataSource>{
    NSInteger startCursorPosition;
    NSInteger currentCursorPosition;
    char currentChar;
    NSInteger deletedLength;
    NSMutableString *newlyInsertedChars;
    NSMutableArray *undoStack;  // stack containing EventBuffer objects
    NSMutableArray *redoStack;  // stack containing EventBuffer objects
    NSTimer *timer;
}

//-(void)setClientFromLogin:(CollabrifyClient *)inClient;

@property (weak, nonatomic) IBOutlet UILabel *sessionIDLabel;

@property (strong, nonatomic) CollabrifyClient *client;

@property (weak, nonatomic) IBOutlet UIButton *undoButton;
@property (weak, nonatomic) IBOutlet UIButton *redoButton;
@property (weak, nonatomic) IBOutlet UITextView *textViewForUser;
@end

