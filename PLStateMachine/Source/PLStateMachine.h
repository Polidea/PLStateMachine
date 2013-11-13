/*
 Copyright (c) 2012, Antoni Kędracki, Polidea
 All rights reserved.

 mailto: akedracki@gmail.com

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the Polidea nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY ANTONI KĘDRACKI, POLIDEA ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL ANTONI KĘDRACKI, POLIDEA BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 Rev 3.0 (Oct 2012):
 Major rewrite:
 States now use resolvers instead of transition maps.

 Rev 2.0 (Aug 2012):
 Trigger based:
 Instead of setting the next state explicitly, a trigger in pair with a transition map is used.
 Triggers can be emitted with a optional object(holding some parameters). Execution is handled on a FIFO basis.

 Rev 1.0 (May 2012):
 Direct state based:
 A state change is performed by directly setting the state property. Such a machine is mainly useful for tracking
 handling transitions between states.

 */

#import <Foundation/Foundation.h>
#import "PLStateMachineTrigger.h"

#define PLSTATE_MACHINE_VERSION 3.2

@class PLStateMachine;
@protocol PLStateMachineResolver;

/**
* Action callback type.
*/
typedef void (^PLStateMachineStateChangeBlock)(PLStateMachine *fsm);

/**
* Base type for all machine state ids. When defining your states, you should use it as the base type for your NS_ENUM.
*/
typedef NSUInteger PLStateMachineStateId;

/**
*  PLStateMachineStateUndefined used as the initial state of the machine, and by transition resolvers to signal that no state change should take place.
*/
static PLStateMachineStateId const PLStateMachineStateUndefined = NSUIntegerMax;

/**
* PLStateMachine is a tool helping to model a Finite State Machine. A mathematical construct very useful when implementing
* complex processes and decision flows.
*/
@interface PLStateMachine : NSObject

/**
* StateId of the previous state
*/
@property(nonatomic, assign, readonly) PLStateMachineStateId prevState;

/**
* StateId of the current state
*/
@property(nonatomic, assign, readonly) PLStateMachineStateId state;

/**
* Trigger that caused the transition to the current state
*/
@property(nonatomic, strong, readonly) PLStateMachineTrigger *triggeredBy;

/**
* A callback block that gets called on every state machine change
*/
@property(nonatomic, copy, readwrite) PLStateMachineStateChangeBlock debugBlock;

/**
* Orders the fsm to start.
*
* @param stateId the id of the state the machine should start in.
*/
- (void)startWithState:(PLStateMachineStateId)stateId;

/**
* Constructs and emits a trigger (short form).
*
* @param triggerId the id of the trigger to emit
*/
- (void)emitTriggerId:(PLStateMachineTriggerId)triggerId;

/**
* Constructs and emits a trigger.
*
* @param triggerId the id of the trigger to emit
* @param object a trigger attachment
*/
- (void)emitTriggerId:(PLStateMachineTriggerId)triggerId object:(id <NSObject>)object;

/**
* Emits a trigger.
*
* @param trigger pre-constructed trigger
*/
- (void)emitTrigger:(PLStateMachineTrigger *)trigger;

/**
* Registers a state.
*
* @param stateId the id of the state. No two states with the same id can be registered at a time
* @param name a human readable identifier for the state. It doesn't have to be unique
* @param resolver the resolver to be used for this state. See PLStateMachineResolver for more info on resolvers
*/
- (void)registerStateWithId:(PLStateMachineStateId)stateId name:(NSString *)name resolver:(id <PLStateMachineResolver>)resolver;

/**
* Checks if a state is registered.
*
* @param stateId the id of the state to check
* @return YES if the state was previously registered, NO otherwise
*/
- (BOOL)hasState:(PLStateMachineStateId)stateId;

/**
* Returns the name for a state.
*
* @param stateId the id of the state to check
* @return the name of the state
*/
- (NSString *)nameForState:(PLStateMachineStateId)stateId;

/**
* Registers a transition callback between any two states.
*
* @param block the transition callback, you can register multiple callbacks for the same transition.
* @param owner the owner(weak referenced) of this callback that can be used for targeted removal
*/
- (void)onTransitionCall:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner;

/**
* Registers a transition callback for leaving a state.
*
* @param stateId the id of the targeted state
* @param block the transition callback
* @param owner the owner(weak referenced) of this callback that can be used for targeted removal
*/
- (void)onLeaving:(PLStateMachineStateId)stateId call:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner;

/**
* Registers a transition callback for entering a state.
*
* @param stateId the id of the targeted state
* @param block the transition callback, you can register multiple callbacks for the same transition
* @param owner the owner(weak referenced) of this callback that can be used for targeted removal
*/
- (void)onEntering:(PLStateMachineStateId)stateId call:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner;

/**
* Registers a transition callback between two defined states.
*
* @param prevStateId the id of the state that's being left
* @param newStateId the id of the state that's being entered
* @param block the transition callback, you can register multiple callbacks for the same transition
* @param owner the owner(weak referenced) of this callback that can be used for targeted removal
*/
- (void)onLeaving:(PLStateMachineStateId)prevStateId entering:(PLStateMachineStateId)newStateId call:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner;

/**
* Removes all the transition callbacks that ware registered with the provided owner.
*
* @param owner the owner of the to be removed callbacks
*/
- (void)removeListenersOwnedBy:(id <NSObject>)owner;

@end