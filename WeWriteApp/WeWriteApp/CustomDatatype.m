//
//  CustomDatatype.m
//  WeWriteApp
//
//  Created by Watermelon on 9/10/13.
//  Copyright (c) 2013 Yijia Tang. All rights reserved.
//

#import "CustomDatatype.h"

@implementation CustomDatatype

NSString *const INSERT_EVENT = @"InsertEvent";
NSString *const DELETE_EVENT = @"DeleteEvent";
NSString *const LOCK_REQUEST_EVENT = @"LockRequestEvent";
NSString *const LOCK_RELEASE_EVENT = @"LockReleaseEvent";
NSInteger const MAX_BUFFER_SIZE = 16;

@end
