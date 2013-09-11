//
//  UserViewController.m
//  WeWriteApp
//
//  Created by Watermelon on 9/6/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import "UserViewController.h"
#import "CustomDatatype.h"

@interface myTextView ()

@end

@implementation myTextView

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"CursorPositionAfterTouch: %d, %d", self.selectedRange.length, self.selectedRange.location);
    [super touchesBegan:touches withEvent:event];
}

@end

@interface UserViewController ()

@end

@implementation UserViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.textViewForUser.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)textViewDidBeginEditing:(UITextView *)textView
{
    NSLog(@"Begin");
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    NSLog(@"End");
}

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    /*
    CGPoint cursorPosition;
    if (textView.selectedTextRange.empty) {
        // get cursor position and do stuff ...
        cursorPosition = [textView caretRectForPosition:textView.selectedTextRange.start].origin;
        NSLog(@"CursorPosition: (%f, %f)", cursorPosition.x, cursorPosition.y);
    }*/
    
    NSLog(@"SelectedRange: %d, %d", textView.selectedRange.length, textView.selectedRange.location);
    
    return YES;
}

@end
