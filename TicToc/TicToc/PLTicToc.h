//
// Created by Antoni Kedracki on 28.10.2013.
// Copyright (c) 2013 Polidea. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <PLStateMachine/PLStateMachine.h>

/*
PLTicToc is the main model class for the example project. It uses a FSM internal for all the logic, out of which only the
PLTicTocState is exposed in the interface. In contrast to Triggers are which are hidden.
 */

/*
PLStateMachine uses PLStateMachineStateId for state identification. As a good practice you should always define a enum with the
PLStateMachineStateId base type for your state machine.
PLTicTocState is used for
 */
typedef NS_ENUM(PLStateMachineStateId, PLTicTocState) {
    PLTicTocStateStart,
    PLTicTocStateCatchRhythm,
    PLTicTocStateClick,
    PLTicTocStateResult
};

@interface PLTicToc : NSObject

/*
KVC property for observation purposes. PLTicTocViewController uses it.
 */
@property(nonatomic, assign, readonly) PLTicTocState state;

/*
Trigger method. PLTicTocViewController uses it. Internal this will emit a PLTicTocTriggerTic to the builtin FSM.
 */
- (void)tic;

@property (nonatomic, assign, readonly) NSTimeInterval interval;
@property (nonatomic, assign, readonly) NSUInteger repeats;

@end