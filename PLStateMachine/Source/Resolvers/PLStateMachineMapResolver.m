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

#import "PLStateMachineMapResolver.h"
#import "PLStateMachineTrigger.h"


@interface PLStateMachineMapResolver ()

@property(nonatomic, retain, readonly) id <PLStateMachineResolver> parent;

@end

@implementation PLStateMachineMapResolver {
@private
    NSMutableDictionary *map;
}
@synthesize parent = parent;

- (id)initWithParent:(id <PLStateMachineResolver>)aParent map:(NSDictionary *)aMap {
    self = [super init];
    if (self) {
        parent = aParent;

        map = [[NSMutableDictionary alloc] init];

        for (NSNumber *trigger in aMap.allKeys) {
            NSNumber *value = [aMap objectForKey:trigger];

            if (![trigger isKindOfClass:[NSNumber class]]) {
                @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"the keys must be of the NSNumber type" userInfo:nil];
            }

            if ([value isKindOfClass:[NSNumber class]]) {
                [self on:trigger.unsignedIntegerValue goTo:value.unsignedIntegerValue];
            } else if ([value conformsToProtocol:@protocol(PLStateMachineResolver)]) {
                id <PLStateMachineResolver> consultant = (id <PLStateMachineResolver>) value;
                [self on:trigger.unsignedIntegerValue consult:consultant];
            } else {
                @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"the value must be either a NSNumber or a PLStateMachineResolver" userInfo:nil];
            }
        }
    }

    return self;
}

- (void)on:(PLStateMachineTriggerSignal)on goTo:(PLStateMachineStateId)state {
    [map setObject:[NSNumber numberWithUnsignedInteger:state] forKey:[NSNumber numberWithUnsignedInteger:on]];
}

- (void)on:(PLStateMachineTriggerSignal)on consult:(id <PLStateMachineResolver>)consultant {
    [map setObject:consultant forKey:[NSNumber numberWithUnsignedInteger:on]];
}

- (PLStateMachineStateId)resolve:(PLStateMachineTrigger *)trigger in:(PLStateMachine *)sm {
    NSNumber *key = [NSNumber numberWithUnsignedInteger:trigger.signal];
    NSObject *value = [map objectForKey:key];

    PLStateMachineStateId nextState = PLStateMachineStateUndefined;

    if (value != nil) {
        if ([value isKindOfClass:[NSNumber class]]) {
            nextState = [(NSNumber *) value unsignedIntegerValue];
        } else if ([value conformsToProtocol:@protocol(PLStateMachineResolver)]) {
            id <PLStateMachineResolver> consultant = (id <PLStateMachineResolver>) value;
            nextState = [consultant resolve:trigger in:sm];
        }
    }

    if (nextState == PLStateMachineStateUndefined && parent!=nil) {
        return [parent resolve:trigger in:sm];
    }

    return nextState;
}

@end

PLStateMachineMapResolver *mapResolver(NSDictionary *map) {
    return childMapResolver(nil, map);
}

PLStateMachineMapResolver *childMapResolver(id <PLStateMachineResolver> parent, NSDictionary *map) {
    return [[PLStateMachineMapResolver alloc] initWithParent:parent map:map];
}
