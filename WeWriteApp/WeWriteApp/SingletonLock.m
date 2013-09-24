//
//  SingletonLock.m
//  WeWriteApp
//
//  Created by Watermelon on 9/24/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import "SingletonLock.h"

static SingletonLock *globalVarLock;

@implementation SingletonLock

+(void)initialize
{
    static BOOL initialized = NO;
    if (!initialized)
    {
        initialized = YES;
        globalVarLock = [[SingletonLock alloc] init];
    }
}

@end
