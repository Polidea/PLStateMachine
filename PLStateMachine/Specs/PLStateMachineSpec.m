#import <Kiwi/Kiwi.h>
#import "PLStateMachine.h"
#import "PLStateMachineBlockResolver.h"
#import "PLBlockKVOObserver.h"

SPEC_BEGIN(PLStateMachineSpecs)

describe(@"PLStateMachine", ^{
    __block PLStateMachine * stateMachine;

    beforeEach(^{
        stateMachine = [[PLStateMachine alloc] init];
    });

    it(@"should be in undefined state just after creation", ^{
        [[theValue(stateMachine.state) should] equal:theValue(PLStateMachineStateUndefined)];
    });

    describe(@"setting up states", ^{
        PLStateMachineStateId placeholderState = 1;
        __block id<PLStateMachineResolver> resolver;

        beforeEach(^{
            resolver = [PLStateMachineBlockResolver blockResolverWithParent:nil
                                                              resolverBlock:^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                                                  return placeholderState;
                                                              }];
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
            [stateMachine registerStateWithId:startState name:@"startState" resolver:[PLStateMachineBlockResolver blockResolverWithParent:nil
                                                                                                                            resolverBlock:^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                                                                                                                return startState;
                                                                                                                            }]];
            [[theValue(stateMachine.state) should] equal:theValue(PLStateMachineStateUndefined)];
            [stateMachine startWithState:startState];
            [[theValue(stateMachine.state) should] equal:theValue(startState)];
        });

        it(@"should emit KVO messages about the transition", ^{
            [stateMachine registerStateWithId:startState name:@"startState" resolver:[PLStateMachineBlockResolver blockResolverWithParent:nil
                                                                                                                            resolverBlock:^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                                                                                                                return startState;
                                                                                                                            }]];
            PLBlockKVOObserver * observer = [PLBlockKVOObserver new];
            __block BOOL valid = NO;
            [observer observeOnObject:stateMachine keypath:@"state" block:^(NSObject *object, NSDictionary *dictionary) {
                [[theValue(stateMachine.state) should] equal:theValue(startState)];
                valid = YES;
            }];

            [stateMachine startWithState:startState];

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
        PLStateMachineTriggerSignal signalA = 6;

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
        });

        it(@"should consult the resolver for the state it's in", ^{
            KWCaptureSpy * signalSpy = [((KWMock *)resolverA) captureArgument:@selector(resolve:in:) atIndex:0];

            [[resolverA should] receive:@selector(resolve:in:)];
            [[resolverB shouldNot] receive:@selector(resolve:in:)];
            [[resolverC shouldNot] receive:@selector(resolve:in:)];

            [stateMachine emitSignal:signalA];
            PLStateMachineTrigger * trigger = signalSpy.argument;
            [[theValue(trigger.signal) should] equal:theValue(signalA)];
        });

        it(@"should transition to the state provided by the resolver", ^{

            [stateMachine emitSignal:signalA];
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

            [stateMachine emitSignal:signalA];

            [[theValue(valid) should] beTrue];
        });

        it(@"should handle signals emited from inside transitions callbacks", ^{
            [stateMachine onLeaving:stateA
                               call:^(PLStateMachine *fsm) {
                                   [stateMachine emitSignal:signalA];
                               }
                              owner:nil];

            [stateMachine emitSignal:signalA];

            [[theValue(stateMachine.state) should] equal:theValue(stateC)];
        });
    });

    describe(@"transition between state", ^{
        PLStateMachineStateId stateA = 3;
        PLStateMachineStateId stateB = 5;
        PLStateMachineTriggerSignal signalA = 6;

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

            [stateMachine startWithState:stateA];
        });

        it(@"should call the 'debug' callback", ^{
            stateMachine.debugBlock = blockA;

            [stateMachine emitSignal:signalA];

            [[theValue(callCount) should] equal:theValue(3)];
        });

        it(@"should call the 'transition' callbacks", ^{
            [stateMachine onTransitionCall:blockA owner:nil];
            [stateMachine onTransitionCall:blockB owner:nil];
            [stateMachine onTransitionCall:blockC owner:nil];

            [stateMachine emitSignal:signalA];

            [[theValue(callCount) should] equal:theValue(17)];

        });

        it(@"should call all the 'leaving' callbacks", ^{
            [stateMachine onLeaving:stateA call:blockA owner:nil];
            [stateMachine onLeaving:stateA call:blockB owner:nil];
            [stateMachine onLeaving:stateB call:blockC owner:nil];

            [stateMachine emitSignal:signalA];

            [[theValue(callCount) should] equal:theValue(8)];

        });

        it(@"should call all the 'between' callbacks", ^{
            [stateMachine emitSignal:signalA];

            [[theValue(callCount) should] equal:theValue(17)];

        });

        it(@"should call the 'entering' callbacks", ^{
            [stateMachine onEntering:stateA call:blockA owner:nil];
            [stateMachine onEntering:stateA call:blockB owner:nil];
            [stateMachine onEntering:stateB call:blockC owner:nil];

            [stateMachine emitSignal:signalA];

            [[theValue(callCount) should] equal:theValue(9)];
        });
    });

});

SPEC_END