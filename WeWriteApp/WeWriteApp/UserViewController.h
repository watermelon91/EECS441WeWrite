//
//  UserViewController.h
//  WeWriteApp
//
//  Created by Watermelon on 9/6/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Collabrify/Collabrify.h>

@interface bufferNode : NSObject
@property (nonatomic) NSInteger sizeOfBuffer;
@property (nonatomic) BOOL lockIsFree;
@end

@interface pendingChangeBuffer : NSObject
@property (nonatomic) NSInteger startPosition;
@property (strong, nonatomic) NSString *content;
@end

@interface UserViewController : UIViewController <UITextViewDelegate>{
    pendingChangeBuffer *localBuffer;
    NSInteger currentPosition;
    NSMutableArray *bufferList;
    NSMutableArray *undoStack;
    NSMutableArray *redoStack;
}

@property (weak, nonatomic) IBOutlet UIButton *undoButton;
@property (weak, nonatomic) IBOutlet UIButton *redoButton;
@property (weak, nonatomic) IBOutlet UITextView *textViewForUser;
@end

