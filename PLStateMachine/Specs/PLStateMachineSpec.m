#import <Kiwi/Kiwi.h>
#import "PLStateMachine.h"
#import "PLStateMachineBlockResolver.h"

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

        it(@"should move to the start state", ^{
            [stateMachine registerStateWithId:startState name:@"startState" resolver:[PLStateMachineBlockResolver blockResolverWithParent:nil
                                                                                                                            resolverBlock:^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                                                                                                                return startState;
                                                                                                                            }]];

            [[theValue(stateMachine.state) should] equal:theValue(PLStateMachineStateUndefined)];
        });

        it(@"should emit KVO messages about the transition to the start state", ^{

        });

    });



});

SPEC_END