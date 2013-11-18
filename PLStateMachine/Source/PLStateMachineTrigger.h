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

#import <Foundation/Foundation.h>

/**
* Base type for all machine trigger ids. When defining your triggers, you should use it as the base type for your NS_ENUM.
*/
typedef NSUInteger PLStateMachineTriggerId;

/**
* PLStateMachineTrigger represents a trigger send to a FSM. In addition to the mandatory id, a attachment object can be passed.
* In most cases this should be sufficient. If not, it's possible to subclass PLStateMachineTrigger.
*/
@interface PLStateMachineTrigger : NSObject

/**
* Identifier
*/
@property(nonatomic, assign, readonly) PLStateMachineTriggerId triggerId;

/**
* Attachment object
*/
@property(nonatomic, strong, readonly) id <NSObject> object;

/**
* Initializes the trigger.
*
* @param triggerId the identifier for this trigger
* @param object the attachment object (retained), can be nil
*/
- (id)initWithId:(PLStateMachineTriggerId)triggerId object:(id <NSObject>)object;

/**
* Shortcut constructor.
*
* @param triggerId the identifier for this trigger
*/
+ (PLStateMachineTrigger *)triggerWithId:(PLStateMachineTriggerId)triggerId;

/**
* Shortcut constructor.
*
* @param triggerId the identifier for this trigger
* @param object the attachment object (retained), can be nil
*/
+ (PLStateMachineTrigger *)triggerWithId:(PLStateMachineTriggerId)triggerId object:(id <NSObject>)object;

@end