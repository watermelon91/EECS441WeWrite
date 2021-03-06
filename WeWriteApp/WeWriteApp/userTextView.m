//
//  userTextView.m
//  WeWriteApp
//
//  Created by Watermelon on 9/15/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import "userTextView.h"

@implementation userTextView

@synthesize touchIsWithinView;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(paste:))
        return NO;
    else if (action == @selector(copy:))
        return NO;
    else if (action == @selector(cut:))
        return NO;
    else if (action == @selector(select:))
        return NO;
    else if (action == @selector(selectAll:))
        return NO;
    
    return [super canPerformAction:action withSender:sender];
}

-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint locationPoint = [[touches anyObject] locationInView:self];
    if (CGRectContainsPoint(self.bounds, locationPoint))
    {
        touchIsWithinView = YES;
    }
    else
    {
        touchIsWithinView = NO;
    }
    [super touchesBegan:touches withEvent:event];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
