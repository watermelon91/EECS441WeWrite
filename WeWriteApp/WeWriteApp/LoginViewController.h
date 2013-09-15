//
//  LoginViewController.h
//  WeWriteApp
//
//  Created by Watermelon on 9/12/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Collabrify/Collabrify.h>
#import "UserViewController.h"

@interface LoginViewController : UIViewController <CollabrifyClientDelegate, CollabrifyClientDataSource>

@property (strong, nonatomic) CollabrifyClient *client;
@property (strong, nonatomic) NSData *baseFileData;
@property (weak, nonatomic) IBOutlet UITextField *loginScreenSessionIDTextView;


@end
