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
    NSMutableDictionary *registeredStates;

    NSMutableArray *triggerQueue;
    NSMutableDictionary *transitionListeners;

    PLStateMachineStateChangeBlock debugBlock;
}

@synthesize state = state;
@synthesize triggeredBy = triggeredBy;
@synthesize prevState = prevState;
@synthesize debugBlock = debugBlock;

NSString *const kStateMachineCallbackListenerBlockKey = @"callback";
NSString *const kStateMachineCallbackListenerOwnerKey = @"owner";

- (id)init {
    self = [super init];
    if (self) {
        state = PLStateMachineStateUndefined;
        prevState = PLStateMachineStateUndefined;
        triggeredBy = nil;

        registeredStates = [[NSMutableDictionary alloc] init];

        triggerQueue = [[NSMutableArray alloc] init];

        transitionListeners = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (void)startWithState:(PLStateMachineStateId)aState {
    if (state == PLStateMachineStateUndefined) {
        [self setState:aState triggeredBy:nil];
    }
}

- (void)emitSignal:(PLStateMachineTriggerSignal)triggerSignal {
    [self emit:[PLStateMachineTrigger triggerWithSignal:triggerSignal]];
}

- (void)emitSignal:(PLStateMachineTriggerSignal)triggerSignal object:(id <NSObject>)object {
    [self emit:[PLStateMachineTrigger triggerWithSignal:triggerSignal object:object]];
}

- (void)emit:(PLStateMachineTrigger *)trigger {
    @synchronized (self) {
        [triggerQueue addObject:trigger];
        if ([triggerQueue count] == 1) {
            [self processTriggers];
        }
    }
}

- (void)registerStateWithId:(PLStateMachineStateId)aState name:(NSString *)aName resolver:(id <PLStateMachineResolver>)aResolver {
    if (![self hasState:aState]) {
        if (aState == PLStateMachineStateUndefined) {
            @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"you canot register the undefined state" userInfo:nil];
        }
        if (aName == nil || aResolver == nil || aName.length == 0) {
            @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"both name and resolver must be non-nil" userInfo:nil];
        }

        PLStateMachineStateNode *node = [[PLStateMachineStateNode alloc] initWithStateId:aState name:aName resolver:aResolver];
        [registeredStates setObject:node forKey:[NSNumber numberWithUnsignedInteger:aState]];
    } else {
        @throw [NSException exceptionWithName:@"InvalidStateException" reason:@"this state was already registered" userInfo:nil];
    }
}

- (BOOL)hasState:(PLStateMachineStateId)aState {
    return [self nodeForState:aState] != nil;
}

- (NSString *)nameForState:(PLStateMachineStateId)aState {
    return [[self nodeForState:aState] name];
}

- (void)onTransitionCall:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner {
    [self onLeaving:PLStateMachineStateUndefined entering:PLStateMachineStateUndefined call:block owner:owner];
}

- (void)onLeaving:(PLStateMachineStateId)aState call:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner {
    [self onLeaving:aState entering:PLStateMachineStateUndefined call:block owner:owner];
}

- (void)onEntering:(PLStateMachineStateId)aState call:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner {
    [self onLeaving:PLStateMachineStateUndefined entering:aState call:block owner:owner];
}

- (void)onLeaving:(PLStateMachineStateId)aPrevState entering:(PLStateMachineStateId)aNewState call:(PLStateMachineStateChangeBlock)block owner:(id <NSObject>)owner {
    //TODO: implement owners

    PLStateMachineTransitionSignature *signature = [PLStateMachineTransitionSignature signatureForLeaving:aPrevState forEntering:aNewState];

    NSMutableArray *listenersForSignature = [transitionListeners objectForKey:signature];
    if (listenersForSignature == nil) {
        listenersForSignature = [NSMutableArray array];
        [transitionListeners setObject:listenersForSignature forKey:signature];
    }

    if (owner == nil) {
        [listenersForSignature addObject:@{kStateMachineCallbackListenerBlockKey : [block copy]}];
    } else {
        [listenersForSignature addObject:@{kStateMachineCallbackListenerBlockKey : [block copy], kStateMachineCallbackListenerOwnerKey : owner}];
    }
}

- (void)removeListenersOwnedBy:(id <NSObject>)owner {
    if (owner == nil) {
        return;
    }

    for (PLStateMachineTransitionSignature *signature in [transitionListeners allKeys]) {
        NSMutableArray *listenersForSignature = [transitionListeners objectForKey:signature];
        [listenersForSignature filterUsingPredicate:[NSPredicate predicateWithFormat:@"%K != %@", kStateMachineCallbackListenerOwnerKey, owner]];
        if (listenersForSignature.count == 0) {
            [transitionListeners removeObjectForKey:signature];
        }
    }
}

- (PLStateMachineStateId)state {
    return state;
}

- (void)setState:(PLStateMachineStateId)aState triggeredBy:(PLStateMachineTrigger *)trigger {
    if (aState == PLStateMachineStateUndefined) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"you canot enter the undefined state" userInfo:nil];
    }

    if (![self hasState:aState]) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"you canot enter a state that was not registered" userInfo:nil];
    }

    BOOL stateChanges = aState != state;
    BOOL prevStateChanges = prevState != state;
    BOOL triggerChanges = trigger != triggeredBy;

    if (!stateChanges && !triggerChanges) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"at least one state or trigger needs to change" userInfo:nil];
    }

    if (triggerChanges) {
        [self willChangeValueForKey:@"triggeredBy"];
    }

    [self willChangeValueForKey:@"prevState"];
    [self willChangeValueForKey:@"state"];
    prevState = state;
    state = aState;
    triggeredBy = trigger;
    [self didChangeValueForKey:@"state"];
    [self didChangeValueForKey:@"prevState"];

    if (triggerChanges) {
        [self didChangeValueForKey:@"triggeredBy"];
    }

    if (debugBlock) {
        debugBlock(self);
    }

    [self notifyStateChange];
}

- (PLStateMachineStateNode *)nodeForState:(PLStateMachineStateId)aState {
    return [registeredStates objectForKey:[NSNumber numberWithUnsignedInteger:aState]];
}

- (void)processTriggers {
    @synchronized (self) {
        PLStateMachineStateNode *node = [self nodeForState:state];
        while ([triggerQueue count] > 0) {
            PLStateMachineTrigger *trigger = [triggerQueue objectAtIndex:0];

            PLStateMachineStateId nextState = [node.resolver resolve:trigger in:self];
            if (nextState != PLStateMachineStateUndefined) {
                [self setState:nextState triggeredBy:trigger];
                node = [self nodeForState:state];
            }

            [triggerQueue removeObjectAtIndex:0];
        }
    }
}

- (void)notifyStateChange {
    if (prevState != PLStateMachineStateUndefined) {
        PLStateMachineTransitionSignature *leavingSignature = [PLStateMachineTransitionSignature signatureForLeaving:prevState];
        for (NSDictionary *listeners in [transitionListeners objectForKey:leavingSignature]) {
            PLStateMachineStateChangeBlock block = [listeners objectForKey:kStateMachineCallbackListenerBlockKey];
            if (block) {
                block(self);
            }
        }

        PLStateMachineTransitionSignature *transitionSignature = [PLStateMachineTransitionSignature signatureForLeaving:prevState forEntering:state];
        for (NSDictionary *listeners in [transitionListeners objectForKey:transitionSignature]) {
            PLStateMachineStateChangeBlock block = [listeners objectForKey:kStateMachineCallbackListenerBlockKey];
            if (block) {
                block(self);
            }
        }
    }


    PLStateMachineTransitionSignature *enteringSignature = [PLStateMachineTransitionSignature signatureForEntering:state];
    for (NSDictionary *listeners in [transitionListeners objectForKey:enteringSignature]) {
        PLStateMachineStateChangeBlock block = [listeners objectForKey:kStateMachineCallbackListenerBlockKey];
        if (block) {
            block(self);
        }
    }

    for (NSDictionary *listeners in [transitionListeners objectForKey:[PLStateMachineTransitionSignature zeroSignature]]) {
        PLStateMachineStateChangeBlock block = [listeners objectForKey:kStateMachineCallbackListenerBlockKey];
        if (block) {
            block(self);
        }
    }
}

@end
