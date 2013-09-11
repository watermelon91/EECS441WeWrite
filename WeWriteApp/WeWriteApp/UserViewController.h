//
//  UserViewController.h
//  WeWriteApp
//
//  Created by Watermelon on 9/6/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Collabrify/Collabrify.h>
@interface myTextView : UITextView {}
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@interface UserViewController : UIViewController <UITextViewDelegate>
@property (weak, nonatomic) IBOutlet myTextView *textViewForUser;
@end

