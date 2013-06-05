//
// Created by Antoni Kedracki on 6/5/13.
// Copyright (c) 2013 Polidea. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>


@interface PLBlockKVOObserver : NSObject

-(void)observeOnObject:(NSObject *)object keypath:(NSString *)keypath block:(void (^)(NSObject *, NSDictionary *))block;

@end