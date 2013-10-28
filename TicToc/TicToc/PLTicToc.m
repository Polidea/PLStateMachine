//
// Created by Antoni Kedracki on 28.10.2013.
// Copyright (c) 2013 Polidea. All rights reserved.
//


#import <PLStateMachine/PLStateMachineMapResolver.h>
#import <PLStateMachine/PLStateMachineBlockResolver.h>
#import "PLTicToc.h"

typedef NS_ENUM(PLStateMachineTriggerSignal, PLTicTocTrigger) {
    PLTicTocTriggerTic,
    PLTicTocTriggerTimeout,
};

@interface PLTicToc ()

/*
We are using automaticallyNotifiesObserversForKey for KVO, so we need to have access to the fsm.* path. This is the quickest way to achieve this.
 */
@property(nonatomic, strong, readonly) PLStateMachine *fsm;

@property(nonatomic, assign, readwrite) NSUInteger repeats;
@property(nonatomic, assign, readwrite) NSTimeInterval interval;

@end

@implementation PLTicToc {

}

/*
The FSM is setup inside of this method. All the state's and actions are registered in here. The use of all kinds of
action callbacks is presented. As are both map and block resolvers.
 */
- (id)init {
    self = [super init];
    if (self) {
        //we will use it in the blocks
        __weak __block typeof (self) weakSelf = self;

        //create the FSM
        _fsm = [PLStateMachine new];

        //just a value holding the timestamp of the last click. We need it to calculate the time passed beaten clicks.
        __block NSTimeInterval lastTic = [NSDate timeIntervalSinceReferenceDate];

        //This is a registration call. All the state need to be registered this way. In addition to the enum and name,
        //a resolver also needs to be provided.
        //
        // mapResolver is a short-form for [[PLStateMachineMapResolver alloc] initWithParent:nil map:map].
        // It maps a trigger onto a target state, or other resolver (example couple lines down)
        [_fsm registerStateWithId:PLTicTocStateStart
                             name:@"Start"
                         resolver:mapResolver(@{
                                 @(PLTicTocTriggerTic) : @(PLTicTocStateCatchRhythm)
                         })];

        //This is a action registration call. The block will be called when transitioning between PLTicTocStateStart
        // and PLTicTocStateCatchRhythm.
        [_fsm onLeaving:PLTicTocStateStart
               entering:PLTicTocStateCatchRhythm
                   call:^(PLStateMachine *fsm) {
                       NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
                       lastTic = currentTime;
                   }
                  owner:nil];

        [_fsm registerStateWithId:PLTicTocStateCatchRhythm
                             name:@"CatchRhythm"
                         resolver:mapResolver(@{
                                 @(PLTicTocTriggerTic) : @(PLTicTocStateClick)
                         })];

        [_fsm onLeaving:PLTicTocStateCatchRhythm
               entering:PLTicTocStateClick
                   call:^(PLStateMachine *fsm) {
                       NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
                       weakSelf.interval = currentTime - lastTic;
                       lastTic = currentTime;
                       weakSelf.repeats = 0;

                       NSLog(@"interval: %f", weakSelf.interval);
                   }
                  owner:nil];

        //Here a blockResolver is used. It gets called whenever PLTicTocTriggerTic trigger is received, and should
        // return the next state to transition to.
        [_fsm registerStateWithId:PLTicTocStateClick
                             name:@"Click"
                         resolver:mapResolver(@{
                                 @(PLTicTocTriggerTic) : blockResolver(^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                     NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
                                     NSTimeInterval ticInterval = currentTime - lastTic;
                                     lastTic = currentTime;

                                     NSLog(@"click: %f", ticInterval);

                                     if (ticInterval > weakSelf.interval * 0.9f && ticInterval < weakSelf.interval * 1.1f) {
                                         return PLTicTocStateClick;
                                     } else {
                                         return PLTicTocStateResult;
                                     }
                                 }),
                                 @(PLTicTocTriggerTimeout) : @(PLTicTocStateResult)
                         })];


        //This is a action registration call. The block will be called when transitioning to PLTicTocStateClick.
        [_fsm onEntering:PLTicTocStateClick
                    call:^(PLStateMachine *fsm) {
                        NSLog(@"onEntering");
                        [weakSelf performSelector:@selector(timeout)
                                       withObject:nil
                                       afterDelay:weakSelf.interval * 1.1f];
                    }
                   owner:nil];

        //This is a action registration call. The block will be called when transitioning away from PLTicTocStateClick.
        [_fsm onLeaving:PLTicTocStateClick
               entering:PLTicTocStateClick
                   call:^(PLStateMachine *fsm) {
                       weakSelf.repeats++;
                   }
                  owner:nil];

        [_fsm onLeaving:PLTicTocStateClick
                   call:^(PLStateMachine *fsm) {
                       NSLog(@"onLeaving");
                       [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                                selector:@selector(timeout)
                                                                  object:nil];
                   }
                  owner:nil];

        [_fsm registerStateWithId:PLTicTocStateResult
                             name:@"Result"
                         resolver:mapResolver(@{
                                 @(PLTicTocTriggerTic) : @(PLTicTocStateStart)
                         })];

        //In addition to the normal action callbacks, you can use the debug block
        _fsm.debugBlock = ^(PLStateMachine *fsm) {
            NSLog(@"tictoc: %@ -> %@ : %d", [fsm nameForState:fsm.prevState], [fsm nameForState:fsm.state], fsm.triggeredBy.signal);
        };

        [_fsm startWithState:PLTicTocStateStart];
    }

    return self;
}

/*
Just to be pedantic about KVC.
 */
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"state"]) {
        return NO;
    } else {
        return [super automaticallyNotifiesObserversForKey:key];
    }
}

/*

 */
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"state"]) {
        return [NSSet setWithObject:@"fsm.state"];
    } else {
        return [super keyPathsForValuesAffectingValueForKey:key];
    }
}

- (PLTicTocState)state {
    return (PLTicTocState) _fsm.state;
}

- (void)tic {
    //this is how you emit a signal
    [_fsm emitSignal:PLTicTocTriggerTic];
}

- (void)timeout {
    [_fsm emitSignal:PLTicTocTriggerTimeout];
}

@end