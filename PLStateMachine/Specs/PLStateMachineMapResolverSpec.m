#import <Kiwi/Kiwi.h>
#import "PLStateMachineMapResolver.h"

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

    it(@"should use the proper configuration", ^{
        PLStateMachineMapResolver * resolver = [[PLStateMachineMapResolver alloc] initWithParent:nil];

        [resolver on:triggerSignal1 goTo:stateId1];
        [resolver on:triggerSignal2 goTo:stateId2];

        [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal2] in:fsm]) should] equal:theValue(stateId2)];
    });

    describe(@"fast constructor should take the configuration", ^{
        it(@"from the initBlock", ^{
            PLStateMachineMapResolver *resolver = [PLStateMachineMapResolver mapResolverWithParent:nil
                                                                                         initBlock:^(PLStateMachineMapResolver *locResolver) {
                                                                                             [locResolver on:triggerSignal1 goTo:stateId1];
                                                                                             [locResolver on:triggerSignal2 goTo:stateId2];
                                                                                         }];

            [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal2] in:fsm]) should] equal:theValue(stateId2)];
        });

        it(@"from a map", ^{
            PLStateMachineMapResolver *resolver = [PLStateMachineMapResolver mapResolverWithParent:nil
                                                                                               map:@{
                                                                                                       @(triggerSignal1) : @(stateId1),
                                                                                                       @(triggerSignal2) : @(stateId2)
                                                                                               }];

            [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal1] in:fsm]) should] equal:theValue(stateId1)];
        });
    });

    it(@"should not consult the parent resolver if the resolverblock succeeds", ^{
        id parentResolver = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];

        PLStateMachineMapResolver * resolver = [[PLStateMachineMapResolver alloc] initWithParent:parentResolver];

        [resolver on:triggerSignal1 goTo:stateId1];

        [[parentResolver shouldNot] receive:@selector(resolve:in:)];
        [resolver on:triggerSignal1 goTo:stateId1];
    });

    it(@"should consult the parent resolver if the resolverblock fails", ^{
        id parentResolver = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];
        [parentResolver stub:@selector(resolve:in:) andReturn:theValue(stateId1)];

        PLStateMachineMapResolver * resolver = [[PLStateMachineMapResolver alloc] initWithParent:parentResolver];

        [[parentResolver should] receive:@selector(resolve:in:)];
        [[theValue([resolver resolve:[PLStateMachineTrigger triggerWithSignal:triggerSignal2] in:fsm]) should] equal:theValue(stateId1)];
    });
});

SPEC_END