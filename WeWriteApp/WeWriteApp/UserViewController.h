//
//  UserViewController.h
//  WeWriteApp
//
//  Created by Watermelon on 9/6/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Collabrify/Collabrify.h>

@interface UserViewController : UIViewController <UITextViewDelegate>{
    NSInteger startPosition;
    NSInteger endPosition;
}

@property (weak, nonatomic) IBOutlet UITextView *textViewForUser;
@end

