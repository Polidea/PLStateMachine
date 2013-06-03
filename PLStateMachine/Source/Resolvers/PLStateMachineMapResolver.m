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


@interface PLStateMachineMapResolver()

@property (nonatomic, retain, readonly) id<PLStateMachineResolver> parent;

@end

@implementation PLStateMachineMapResolver {
@private
    NSMutableDictionary * map;
}
@synthesize parent = parent;

+ (PLStateMachineMapResolver *)mapResolverWithParent:(id <PLStateMachineResolver>)aParent initBlock:(void (^)(PLStateMachineMapResolver *))initBlock {
    PLStateMachineMapResolver * resolver = [[self alloc] initWithParent:aParent];
    if (initBlock != nil){
        initBlock(resolver);
    }
    return resolver;
}


- (id)initWithParent:(id <PLStateMachineResolver>)aParent {
    self = [super init];
    if (self) {
        parent = aParent;

        map = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (void)on:(PLStateMachineTriggerSignal)on goTo:(PLStateMachineStateId)state {
    [map setObject:[NSNumber numberWithUnsignedInteger:state] forKey:[NSNumber numberWithUnsignedInteger:on]];
}

- (PLStateMachineStateId)resolve:(PLStateMachineTrigger *)trigger in:(PLStateMachine *)sm {
    NSNumber * key = [NSNumber numberWithUnsignedInteger:trigger.signal];
    NSNumber * nextState = [map objectForKey:key];
    if (nextState != nil){
        return [nextState unsignedIntegerValue];
    } else if (parent != nil){
        return [parent resolve:trigger in:sm];
    } else {
        return PLStateMachineStateUndefined;
    }

}

@end