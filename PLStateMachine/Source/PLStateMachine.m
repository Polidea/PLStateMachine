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

 Rev 4.0 (Feb 2014):
 The FSM uses an internal GCD queue for transition and callback delivery.

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


#import "PLStateMachine.h"
#import "PLStateMachineTransitionSignature.h"
#import "PLStateMachineResolver.h"
#import "PLStateMachineStateNode.h"

@interface PLStateMachine ()

- (PLStateMachineStateNode *)nodeForState:(PLStateMachineStateId)state;

- (void)setState:(PLStateMachineStateId)aState triggeredBy:(PLStateMachineTrigger *)trigger;

- (void)notifyStateChange;

@end

@implementation PLStateMachine {
@private
    NSMutableDictionary *_registeredStates;
    NSMutableDictionary *_transitionListeners;
    dispatch_queue_t _queue;
}

@synthesize state = _state;
@synthesize triggeredBy = _triggeredBy;
@synthesize prevState = _prevState;
@synthesize debugBlock = _debugBlock;

NSString *const kStateMachineCallbackListenerBlockKey = @"callback";
NSString *const kStateMachineCallbackListenerOwnerKey = @"owner";

- (id)init {
    self = [self initWithQueue:nil];
    return self;
}

- (id)initWithQueue:(dispatch_queue_t)queue {
    self = [super init];
    if (self) {
        _queue = queue;
        static int queueIdAutoKey = 0;
        if (_queue == nil) {
            _queue = dispatch_queue_create([[NSString stringWithFormat:@"fsm-%d", queueIdAutoKey] cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
            ++queueIdAutoKey;
        }

        _state = PLStateMachineStateUndefined;
        _prevState = PLStateMachineStateUndefined;
        _triggeredBy = nil;

        _registeredStates = [[NSMutableDictionary alloc] init];

        _transitionListeners = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (void)wait {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(_queue, ^{
        dispatch_semaphore_signal(semaphore);
    });

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

- (void)startWithState:(PLStateMachineStateId)stateId {
    if (stateId == PLStateMachineStateUndefined) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"you canot enter the undefined state" userInfo:nil];
    }

    if (![self hasState:stateId]) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"you canot enter a state that was not registered" userInfo:nil];
    }

    dispatch_async(_queue, ^{
        [self setState:stateId triggeredBy:nil];
    });
}

- (void)emitTriggerId:(PLStateMachineTriggerId)triggerId {
    [self emitTrigger:[PLStateMachineTrigger triggerWithId:triggerId]];
}

- (void)emitTriggerId:(PLStateMachineTriggerId)triggerId object:(id <NSObject>)object {
    [self emitTrigger:[PLStateMachineTrigger triggerWithId:triggerId object:object]];
}

- (void)emitTrigger:(PLStateMachineTrigger *)trigger {
    dispatch_async(_queue, ^{
        PLStateMachineStateNode *node = [self nodeForState:_state];

        PLStateMachineStateId nextState = [node.resolver resolve:trigger in:self];
        if (nextState != PLStateMachineStateUndefined) {
            [self setState:nextState triggeredBy:trigger];
            node = [self nodeForState:_state];
        }
    });
}

- (void)registerStateWithId:(PLStateMachineStateId)stateId name:(NSString *)aName resolver:(id <PLStateMachineResolver>)aResolver {
    @synchronized (_registeredStates) {
        if (![self hasState:stateId]) {
            if (stateId == PLStateMachineStateUndefined) {
                @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"you canot register the undefined state" userInfo:nil];
            }
            if (aName == nil || aResolver == nil || aName.length == 0) {
                @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"both name and resolver must be non-nil" userInfo:nil];
            }

            PLStateMachineStateNode *node = [[PLStateMachineStateNode alloc] initWithStateId:stateId name:aName resolver:aResolver];
            [_registeredStates setObject:node forKey:[NSNumber numberWithUnsignedInteger:stateId]];
        } else {
            @throw [NSException exceptionWithName:@"InvalidStateException" reason:@"this state was already registered" userInfo:nil];
        }
    }
}

- (BOOL)hasState:(PLStateMachineStateId)stateId {
    return [self nodeForState:stateId] != nil;
}

- (NSString *)nameForState:(PLStateMachineStateId)stateId {
    return [[self nodeForState:stateId] name];
}

- (void)onTransitionCall:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner {
    [self onLeaving:PLStateMachineStateUndefined entering:PLStateMachineStateUndefined call:block owner:owner];
}

- (void)onLeaving:(PLStateMachineStateId)stateId call:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner {
    [self onLeaving:stateId entering:PLStateMachineStateUndefined call:block owner:owner];
}

- (void)onEntering:(PLStateMachineStateId)stateId call:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner {
    [self onLeaving:PLStateMachineStateUndefined entering:stateId call:block owner:owner];
}

- (void)onLeaving:(PLStateMachineStateId)prevStateId entering:(PLStateMachineStateId)newStateId call:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner {
    PLStateMachineTransitionSignature *signature = [PLStateMachineTransitionSignature signatureForLeaving:prevStateId forEntering:newStateId];

    NSMutableArray *listenersForSignature = [_transitionListeners objectForKey:signature];
    if (listenersForSignature == nil) {
        listenersForSignature = [NSMutableArray array];
        [_transitionListeners setObject:listenersForSignature forKey:signature];
    }

    if (owner == nil) {
        [listenersForSignature addObject:@{kStateMachineCallbackListenerBlockKey : [block copy]}];
    } else {
        [listenersForSignature addObject:@{kStateMachineCallbackListenerBlockKey : [block copy], kStateMachineCallbackListenerOwnerKey : [NSValue valueWithNonretainedObject:owner]}];
    }
}

- (void)removeListenersOwnedBy:(id <NSObject>)owner {
    if (owner == nil) {
        return;
    }

    NSValue *nonRetainedOwner = [NSValue valueWithNonretainedObject:owner];
    for (PLStateMachineTransitionSignature *signature in [_transitionListeners allKeys]) {
        NSMutableArray *listenersForSignature = [_transitionListeners objectForKey:signature];
        [listenersForSignature filterUsingPredicate:[NSPredicate predicateWithFormat:@"%K != %@", kStateMachineCallbackListenerOwnerKey, nonRetainedOwner]];
        if (listenersForSignature.count == 0) {
            [_transitionListeners removeObjectForKey:signature];
        }
    }
}

- (PLStateMachineStateId)state {
    return _state;
}

- (void)setState:(PLStateMachineStateId)aState triggeredBy:(PLStateMachineTrigger *)trigger {
    if (aState == PLStateMachineStateUndefined) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"you canot enter the undefined state" userInfo:nil];
    }

    if (![self hasState:aState]) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"you canot enter a state that was not registered" userInfo:nil];
    }

    BOOL stateChanges = aState != _state;
    BOOL triggerChanges = trigger != _triggeredBy;

    if (!stateChanges && !triggerChanges) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"at least one of state or trigger needs to change" userInfo:nil];
    }

    if (triggerChanges) {
        [self willChangeValueForKey:@"triggeredBy"];
    }

    [self willChangeValueForKey:@"prevState"];
    [self willChangeValueForKey:@"state"];
    _prevState = _state;
    _state = aState;
    _triggeredBy = trigger;
    [self didChangeValueForKey:@"state"];
    [self didChangeValueForKey:@"prevState"];

    if (triggerChanges) {
        [self didChangeValueForKey:@"triggeredBy"];
    }

    if (_debugBlock) {
        _debugBlock(self);
    }

    [self notifyStateChange];
}

- (PLStateMachineStateNode *)nodeForState:(PLStateMachineStateId)aState {
    @synchronized (_registeredStates) {
        return [_registeredStates objectForKey:[NSNumber numberWithUnsignedInteger:aState]];
    }
}

- (void)notifyStateChange {
    if (_prevState != PLStateMachineStateUndefined) {
        PLStateMachineTransitionSignature *leavingSignature = [PLStateMachineTransitionSignature signatureForLeaving:_prevState];
        for (NSDictionary *listeners in [_transitionListeners objectForKey:leavingSignature]) {
            PLStateMachineStateChangeBlock block = [listeners objectForKey:kStateMachineCallbackListenerBlockKey];
            if (block) {
                block(self);
            }
        }

        PLStateMachineTransitionSignature *transitionSignature = [PLStateMachineTransitionSignature signatureForLeaving:_prevState forEntering:_state];
        for (NSDictionary *listeners in [_transitionListeners objectForKey:transitionSignature]) {
            PLStateMachineStateChangeBlock block = [listeners objectForKey:kStateMachineCallbackListenerBlockKey];
            if (block) {
                block(self);
            }
        }
    }


    PLStateMachineTransitionSignature *enteringSignature = [PLStateMachineTransitionSignature signatureForEntering:_state];
    for (NSDictionary *listeners in [_transitionListeners objectForKey:enteringSignature]) {
        PLStateMachineStateChangeBlock block = [listeners objectForKey:kStateMachineCallbackListenerBlockKey];
        if (block) {
            block(self);
        }
    }

    for (NSDictionary *listeners in [_transitionListeners objectForKey:[PLStateMachineTransitionSignature zeroSignature]]) {
        PLStateMachineStateChangeBlock block = [listeners objectForKey:kStateMachineCallbackListenerBlockKey];
        if (block) {
            block(self);
        }
    }
}

@end
