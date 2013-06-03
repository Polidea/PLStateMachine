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


#import "PLStateMachineTransitionSignature.h"

@implementation PLStateMachineTransitionSignature {

@private
    PLStateMachineStateId enteringState;
    PLStateMachineStateId leavingState;
}

@synthesize enteringState;
@synthesize leavingState;

+ (id)signatureForLeaving:(PLStateMachineStateId)leaving forEntering:(PLStateMachineStateId)entering {
    return [[self alloc] initForLeaving:leaving forEntering:entering];
}

+ (id)signatureForLeaving:(PLStateMachineStateId)leaving {
    return [[self alloc] initForLeaving:leaving forEntering:PLStateMachineStateUndefined];
}

+ (id)signatureForEntering:(PLStateMachineStateId)entering {
    return [[self alloc] initForLeaving:PLStateMachineStateUndefined forEntering:entering];
}

+ (id)zeroSignature {
    static PLStateMachineTransitionSignature * zeroSignature = nil;
    if(zeroSignature == nil){
        zeroSignature = [[self alloc] initForLeaving:PLStateMachineStateUndefined forEntering:PLStateMachineStateUndefined];
    }
    return zeroSignature;
}

- (id)initForLeaving:(PLStateMachineStateId)leaving forEntering:(PLStateMachineStateId)entering {
    self = [super init];
    if (self){
        enteringState = entering;
        leavingState = leaving;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    return (self == object) || ([object isKindOfClass:[self class]] && [(PLStateMachineTransitionSignature *)object leavingState] == [self leavingState] && [(PLStateMachineTransitionSignature *)object enteringState] == [self enteringState]);
}

- (NSUInteger)hash {
    //TODO: better hash?!
    return enteringState * 17 + leavingState * 7;
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initForLeaving:self.leavingState forEntering:self.enteringState];
}


@end