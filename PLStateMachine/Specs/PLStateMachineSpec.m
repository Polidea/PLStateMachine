#import <Kiwi/Kiwi.h>
#import "PLStateMachine.h"
#import "PLStateMachineBlockResolver.h"
#import "PLBlockKVOObserver.h"

SPEC_BEGIN(PLStateMachineSpec)

describe(@"PLStateMachine", ^{
    __block PLStateMachine * stateMachine;

    __block dispatch_queue_t queue;

    beforeEach(^{
        queue = dispatch_queue_create("fsm-test", DISPATCH_QUEUE_SERIAL);

        stateMachine = [[PLStateMachine alloc] initWithQueue:queue];
    });

    it(@"should be in undefined state just after creation", ^{
        [[theValue(stateMachine.state) should] equal:theValue(PLStateMachineStateUndefined)];
    });

    describe(@"setting up states", ^{
        PLStateMachineStateId placeholderState = 1;
        __block id<PLStateMachineResolver> resolver;

        beforeEach(^{
            resolver = blockResolver(^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                return placeholderState;
            });
        });

        it(@"should throw an exception if the undefined state id is provided", ^{
            [[theBlock(^{
                [stateMachine registerStateWithId:PLStateMachineStateUndefined name:@"some name" resolver:resolver];
            }) should] raise];
        });

        describe(@"should throw an exception if the state name", ^{
            it(@"is to short", ^{
                [[theBlock(^{
                    [stateMachine registerStateWithId:placeholderState name:@"" resolver:resolver];
                }) should] raise];
            });

            it(@"is nil", ^{
                [[theBlock(^{
                    [stateMachine registerStateWithId:placeholderState name:nil resolver:resolver];
                }) should] raise];
            });
        });

        it(@"should throw an exception if no rosolver is provided", ^{
            [[theBlock(^{
                [stateMachine registerStateWithId:PLStateMachineStateUndefined name:@"" resolver:nil];
            }) should] raise];
        });

        it(@"should throw an exception if the same id is used twice to register two distinct states", ^{
            [[theBlock(^{
                [stateMachine registerStateWithId:placeholderState name:@"first" resolver:resolver];
                [stateMachine registerStateWithId:placeholderState name:@"second" resolver:resolver];
            }) should] raise];
        });
    });

    describe(@"starting", ^{
        PLStateMachineStateId startState = 1;

        it(@"should throw an exception if the start state doesn't exist", ^{
            [[theBlock(^{
                [stateMachine startWithState:startState];
            }) should] raise];
        });

        it(@"should move to the provided state", ^{
            [stateMachine registerStateWithId:startState
                                         name:@"startState"
                                     resolver:blockResolver(^(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                         return startState;
                                     })];
            [[theValue(stateMachine.state) should] equal:theValue(PLStateMachineStateUndefined)];
            [stateMachine startWithState:startState];
            [stateMachine wait];
            [[theValue(stateMachine.state) should] equal:theValue(startState)];
        });

        it(@"should emit KVO messages about the transition", ^{
            [stateMachine registerStateWithId:startState
                                         name:@"startState"
                                     resolver:blockResolver(^(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                         return startState;
                                     })];
            PLBlockKVOObserver * observer = [PLBlockKVOObserver new];
            __block BOOL valid = NO;
            [observer observeOnObject:stateMachine keypath:@"state" block:^(NSObject *object, NSDictionary *dictionary) {
                [[theValue(stateMachine.state) should] equal:theValue(startState)];
                valid = YES;
            }];

            [stateMachine startWithState:startState];

            [stateMachine wait];

            [[theValue(valid) should] beTrue];
        });
    });

    describe(@"emitting a triger", ^{
        __block id resolverA;
        __block id resolverB;
        __block id resolverC;
        PLStateMachineStateId stateA = 3;
        PLStateMachineStateId stateB = 5;
        PLStateMachineStateId stateC = 6;
        PLStateMachineTriggerId signalA = 6;

        beforeEach(^{
            resolverA = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];
            resolverB = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];
            resolverC = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];

            [resolverA stub:@selector(resolve:in:) andReturn:theValue(stateB)];
            [resolverB stub:@selector(resolve:in:) andReturn:theValue(stateC)];

            [stateMachine registerStateWithId:stateA name:@"stateA" resolver:resolverA];
            [stateMachine registerStateWithId:stateB name:@"stateB" resolver:resolverB];
            [stateMachine registerStateWithId:stateC name:@"stateC" resolver:resolverC];

            [stateMachine startWithState:stateA];
            [stateMachine wait];
        });

        it(@"should consult the resolver for the state it's in", ^{
            KWCaptureSpy * signalSpy = [((KWMock *)resolverA) captureArgument:@selector(resolve:in:) atIndex:0];

            [[resolverA should] receive:@selector(resolve:in:)];
            [[resolverB shouldNot] receive:@selector(resolve:in:)];
            [[resolverC shouldNot] receive:@selector(resolve:in:)];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            PLStateMachineTrigger * trigger = signalSpy.argument;
            [[theValue(trigger.triggerId) should] equal:theValue(signalA)];
        });

        it(@"should transition to the state provided by the resolver", ^{

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(stateMachine.state) should] equal:theValue(stateB)];
        });

        it(@"should emit KVO messages about the transition", ^{
            PLBlockKVOObserver * observer = [PLBlockKVOObserver new];
            __block BOOL valid = NO;
            [observer observeOnObject:stateMachine keypath:@"state" block:^(NSObject *object, NSDictionary *dictionary) {
                PLStateMachineStateId newState = [[dictionary objectForKey:NSKeyValueChangeNewKey] unsignedIntegerValue];
                PLStateMachineStateId oldState = [[dictionary objectForKey:NSKeyValueChangeOldKey] unsignedIntegerValue];
                [[theValue(newState) should] equal:theValue(stateB)];
                [[theValue(oldState) should] equal:theValue(stateA)];

                valid = YES;
            }];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(valid) should] beTrue];
        });

//        it(@"should handle signals emited from inside transitions callbacks", ^{
//            [stateMachine onLeaving:stateA
//                               call:^(PLStateMachine *fsm) {
//                                   [stateMachine emitTriggerId:signalA];
//                               }
//                              owner:nil];
//
//            [stateMachine emitTriggerId:signalA];
//            synchronize();
//
//            [[theValue(stateMachine.state) should] equal:theValue(stateC)];
//        });
    });

    describe(@"transition between states", ^{
        PLStateMachineStateId stateA = 3;
        PLStateMachineStateId stateB = 5;
        PLStateMachineTriggerId signalA = 6;

        __block NSUInteger callCount;
        __block PLStateMachineStateChangeBlock blockA;
        __block PLStateMachineStateChangeBlock blockB;
        __block PLStateMachineStateChangeBlock blockC;

        beforeEach(^{
            id resolverA = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];
            [resolverA stub:@selector(resolve:in:) andReturn:theValue(stateB)];
            [stateMachine registerStateWithId:stateA name:@"stateA" resolver:resolverA];

            id resolverB = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];
            [resolverB stub:@selector(resolve:in:) andReturn:theValue(stateA)];
            [stateMachine registerStateWithId:stateB name:@"stateB" resolver:resolverB];

            blockA = ^(PLStateMachine *fsm) {
                callCount += 3;
            };

            blockB = ^(PLStateMachine *fsm) {
                callCount += 5;
            };

            blockC = ^(PLStateMachine *fsm) {
                callCount += 9;
            };

            [stateMachine startWithState:stateA];
            [stateMachine wait];

            callCount = 0;
        });

        it(@"should call the 'debug' callback", ^{
            stateMachine.debugBlock = blockA;

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(3)];
        });

        it(@"should call all the 'leaving' callbacks", ^{
            [stateMachine onLeaving:stateA call:blockA owner:nil];
            [stateMachine onLeaving:stateA call:blockB owner:nil];
            [stateMachine onLeaving:stateB call:blockC owner:nil];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(8)];

        });

        it(@"should call all the 'between' callbacks", ^{
            [stateMachine onLeaving:stateA entering:stateB call:blockA owner:nil];
            [stateMachine onLeaving:stateB entering:stateA call:blockB owner:nil];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(3)];

        });

        it(@"should call the 'entering' callbacks", ^{
            [stateMachine onEntering:stateA call:blockA owner:nil];
            [stateMachine onEntering:stateA call:blockB owner:nil];
            [stateMachine onEntering:stateB call:blockC owner:nil];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(9)];
        });

        it(@"should call the 'transition' callbacks", ^{
            [stateMachine onTransitionCall:blockA owner:nil];
            [stateMachine onTransitionCall:blockB owner:nil];
            [stateMachine onTransitionCall:blockC owner:nil];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(17)];
        });

        it(@"should call all types of callback in the right order", ^{
            __block NSUInteger order = 0;
            [stateMachine onLeaving:stateA
                               call:^(PLStateMachine *fsm) {
                                   [[theValue(order++) should] equal:theValue(0)];
                               }
                              owner:nil];

            [stateMachine onLeaving:stateA
                           entering:stateB
                               call:^(PLStateMachine *fsm) {
                                   [[theValue(order++) should] equal:theValue(1)];
                               }
                              owner:nil];

            [stateMachine onEntering:stateB
                                call:^(PLStateMachine *fsm) {
                                    [[theValue(order++) should] equal:theValue(2)];
                                }
                               owner:nil];

            [stateMachine onTransitionCall:^(PLStateMachine *fsm) {
                [[theValue(order++) should] equal:theValue(3)];
            }
                                     owner:nil];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];
        });

        it(@"should have all the state/prevState/triggeredBy properties properly set at time of callbacks invocation", ^{
            [stateMachine onTransitionCall:^(PLStateMachine *fsm) {
                [[theValue(fsm.state) should] equal:theValue(stateB)];
                [[theValue(fsm.prevState) should] equal:theValue(stateA)];
                [[theValue(fsm.triggeredBy.triggerId) should] equal:theValue(signalA)];
            }
                                     owner:nil];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];
        });
    });

    describe(@"owned callbacks", ^{
        PLStateMachineStateId stateA = 3;
        PLStateMachineStateId stateB = 5;
        PLStateMachineTriggerId signalA = 6;

        __block NSUInteger callCount;
        __block PLStateMachineStateChangeBlock blockA;
        __block PLStateMachineStateChangeBlock blockB;
        __block PLStateMachineStateChangeBlock blockC;

        __block NSObject * ownerA;
        __block NSObject * ownerB;

        beforeEach(^{
            id resolverA = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];
            [resolverA stub:@selector(resolve:in:) andReturn:theValue(stateB)];
            [stateMachine registerStateWithId:stateA name:@"stateA" resolver:resolverA];

            id resolverB = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];
            [resolverB stub:@selector(resolve:in:) andReturn:theValue(stateA)];
            [stateMachine registerStateWithId:stateB name:@"stateB" resolver:resolverB];

            callCount = 0;
            blockA = ^(PLStateMachine *fsm) {
                callCount += 3;
            };

            blockB = ^(PLStateMachine *fsm) {
                callCount += 5;
            };

            blockC = ^(PLStateMachine *fsm) {
                callCount += 9;
            };

            ownerA = [NSObject new];
            ownerB = [NSObject new];

            [stateMachine startWithState:stateA];
            [stateMachine wait];
        });


        it(@"should of the 'leaving' type should be removable on a per owner basis", ^{
            [stateMachine onLeaving:stateA call:blockA owner:ownerA];
            [stateMachine onLeaving:stateA call:blockB owner:ownerB];
            [stateMachine onLeaving:stateA call:blockC owner:ownerA];

            [stateMachine removeListenersOwnedBy:ownerA];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(5)];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(5)];
        });

        it(@"should of the 'between' type should be removable on a per owner basis", ^{
            [stateMachine onLeaving:stateA entering:stateB call:blockA owner:ownerB];
            [stateMachine onLeaving:stateA entering:stateB call:blockB owner:ownerA];

            [stateMachine removeListenersOwnedBy:ownerA];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(3)];
        });

        it(@"should of the 'entering' type should be removable on a per owner basis", ^{
            [stateMachine onEntering:stateA call:blockA owner:ownerA];
            [stateMachine onEntering:stateB call:blockB owner:ownerA];
            [stateMachine onEntering:stateB call:blockC owner:ownerB];

            [stateMachine removeListenersOwnedBy:ownerB];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(5)];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(8)];
        });

        it(@"should of the 'transition' type should be removable on a per owner basis", ^{
            [stateMachine onTransitionCall:blockA owner:ownerA];
            [stateMachine onTransitionCall:blockB owner:ownerB];
            [stateMachine onTransitionCall:blockC owner:ownerA];

            [stateMachine removeListenersOwnedBy:ownerA];

            [stateMachine emitTriggerId:signalA];
            [stateMachine wait];

            [[theValue(callCount) should] equal:theValue(5)];
        });
    });
});

SPEC_END