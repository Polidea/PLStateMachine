//
// Created by Antoni Kedracki on 6/5/13.
// Copyright (c) 2013 Polidea. All rights reserved.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Kiwi/Kiwi.h>
#import "PLBlockKVOObserver.h"


@implementation PLBlockKVOObserver {
    NSMutableDictionary * registeredObservers;
}

NSString * const kKVOBObserverTargetKey = @"target";
NSString * const kKVOBObserverBlockKey = @"block";

- (id)init {
    self = [super init];
    if (self) {
        registeredObservers = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)dealloc {
    for(NSString * keypath in [registeredObservers allKeys]){
        NSDictionary * observerstruct = [registeredObservers objectForKey:keypath];
        NSObject * target = [observerstruct objectForKey:kKVOBObserverTargetKey];
        [target removeObserver:self forKeyPath:keypath];
    }
}

- (void)observeOnObject:(NSObject *)object keypath:(NSString *)keypath block:(void (^)(NSObject *, NSDictionary *))block {
    if([registeredObservers objectForKey:keypath] != nil){
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"the keypath is allready being observed" userInfo:nil];
    }

    [registeredObservers setObject:@{ kKVOBObserverTargetKey : object, kKVOBObserverBlockKey : [block copy] } forKey:keypath];
    [object addObserver:self forKeyPath:keypath options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSDictionary * observerstruct = [registeredObservers objectForKey:keyPath];
    if(observerstruct == nil){
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    void (^block)(NSObject *, NSDictionary *) = [observerstruct objectForKey:kKVOBObserverBlockKey];
    if(block != nil){
        block(object, change);
    }
}


@end