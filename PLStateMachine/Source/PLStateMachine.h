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

@class PLStateMachine;
@protocol PLStateMachineResolver;

typedef void (^PLStateMachineStateChangeBlock)(PLStateMachine * fsm);
typedef NSUInteger PLStateMachineStateId;

static PLStateMachineStateId const PLStateMachineStateUndefined = NSUIntegerMax;

@interface PLStateMachine : NSObject

@property (nonatomic, assign, readonly) PLStateMachineStateId prevState;
@property (nonatomic, assign, readonly) PLStateMachineStateId state;
@property (nonatomic, strong, readonly) PLStateMachineTrigger * triggeredBy;

@property (nonatomic, copy, readwrite) PLStateMachineStateChangeBlock debugBlock;

-(void)startWithState:(PLStateMachineStateId)state;

-(void)emitSignal:(PLStateMachineTriggerSignal)triggerSignal;
-(void)emitSignal:(PLStateMachineTriggerSignal)triggerSignal object:(id<NSObject>)object;
-(void)emit:(PLStateMachineTrigger*)trigger;

-(void)registerStateWithId:(PLStateMachineStateId)state name:(NSString*)name resolver:(id<PLStateMachineResolver>)resolver;
-(BOOL)hasState:(PLStateMachineStateId)state;
-(NSString *)nameForState:(PLStateMachineStateId)state;

-(void)onTransitionCall:(PLStateMachineStateChangeBlock)block owner:(id<NSObject>)owner;
-(void)onLeaving:(PLStateMachineStateId)state call:(PLStateMachineStateChangeBlock)block owner:(id<NSObject>)owner;
-(void)onEntering:(PLStateMachineStateId)state call:(PLStateMachineStateChangeBlock)block owner:(id<NSObject>)owner;
-(void)onLeaving:(PLStateMachineStateId)prevState entering:(PLStateMachineStateId)newState call:(PLStateMachineStateChangeBlock)block owner:(id<NSObject>)owner;

-(void) removeListenersOwnedBy:(id<NSObject>)owner;

@end