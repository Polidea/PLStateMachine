#import <Kiwi/Kiwi.h>
#import "PLStateMachineMapResolver.h"
#import "PLStateMachineBlockResolver.h"

SPEC_BEGIN(PLStateMachineMapResolverSpec)

        describe(@"PLStateMachineMapResolver", ^{

            __block PLStateMachine *fsm;

            PLStateMachineStateId const stateId1 = 32;
            PLStateMachineStateId const stateId2 = 13;

            PLStateMachineTriggerSignal const triggerSignal1 = 2;
            PLStateMachineTriggerSignal const triggerSignal2 = 3;

            beforeEach(^{
                fsm = [[PLStateMachine alloc] init];
            });

            it(@"should use the proper trigger->state configuration", ^{
                PLStateMachineMapResolver *resolver = [[PLStateMachineMapResolver alloc] initWithParent:nil map:nil];

                [resolver on:triggerSignal1 goTo:stateId1];
                [resolver on:triggerSignal2 goTo:stateId2];

                [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal2] in:fsm]) should] equal:theValue(stateId2)];
            });

            it(@"should use the proper trigger->block->state configuration", ^{
                PLStateMachineMapResolver *resolver = [[PLStateMachineMapResolver alloc] initWithParent:nil map:nil];

                __block NSObject *a = [NSObject new];
                __block NSUInteger callCount = 0;

                [resolver on:triggerSignal1
                     consult:blockResolver(^(PLStateMachineTrigger *trigger, PLStateMachine *fsm) {
                         ++callCount;
                         if (trigger.object == a) {
                             return stateId1;
                         } else {
                             return stateId2;
                         }
                     })];

                [resolver on:triggerSignal2
                     consult:blockResolver(^(PLStateMachineTrigger *trigger, PLStateMachine *fsm) {
                         ++callCount;
                         if (trigger.object == a) {
                             return stateId2;
                         } else {
                             return stateId1;
                         }
                     })];

                [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal1 object:nil] in:fsm]) should] equal:theValue(stateId2)];
                [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal1 object:a] in:fsm]) should] equal:theValue(stateId1)];
                [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal2 object:nil] in:fsm]) should] equal:theValue(stateId1)];
                [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal2 object:a] in:fsm]) should] equal:theValue(stateId2)];
                [[theValue(callCount) should] equal:theValue(4)];
            });

            describe(@"fast constructor", ^{
                describe(@"with a map", ^{
                    it(@"should apply the provided configuration", ^{
                        PLStateMachineMapResolver *resolver = mapResolver(@{
                                @(triggerSignal1) : @(stateId1),
                                @(triggerSignal2) : mapResolver(@{
                                        @(triggerSignal2) : @(stateId2),
                                })
                        });

                        [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal1] in:fsm]) should] equal:theValue(stateId1)];
                        [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal2] in:fsm]) should] equal:theValue(stateId2)];
                    });

                    it(@"should rise an exception if the map has non NSNumber keys/objects", ^{
                        [[theBlock(^{
                            PLStateMachineMapResolver *resolver = mapResolver(@{
                                    @(triggerSignal1) : @"abc",
                                    @"xyz" : @(stateId2)
                            });
                        }) should] raiseWithName:@"InvalidArgumentException"];

                    });

                });
            });

            it(@"should not consult the parent resolver if the resolverblock succeeds", ^{
                id parentResolver = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];

                PLStateMachineMapResolver *resolver = [[PLStateMachineMapResolver alloc] initWithParent:parentResolver map:nil];

                [resolver on:triggerSignal1 goTo:stateId1];
                [resolver on:triggerSignal2 consult:mapResolver(@{
                        @(triggerSignal2) : @(stateId2)
                })];

                [[parentResolver shouldNot] receive:@selector(resolve:in:)];
                [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal1] in:fsm]) should] equal:theValue(stateId1)];
                [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal2] in:fsm]) should] equal:theValue(stateId2)];
            });

            it(@"should consult the parent resolver if the resolverblock fails", ^{
                id parentResolver = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];
                [parentResolver stub:@selector(resolve:in:) andReturn:theValue(stateId1)];

                PLStateMachineMapResolver *resolver = [[PLStateMachineMapResolver alloc] initWithParent:parentResolver
                                                                                                    map:@{
                                                                                                            @(triggerSignal2) : mapResolver(@{

                                                                                                            })
                                                                                                    }];

                [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal1] in:fsm]) should] equal:theValue(stateId1)];
                [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal2] in:fsm]) should] equal:theValue(stateId1)];
            });
        });

        SPEC_END