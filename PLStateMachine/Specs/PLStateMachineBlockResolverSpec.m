#import <Kiwi/Kiwi.h>
#import "PLStateMachineBlockResolver.h"

SPEC_BEGIN(PLStateMachineBlockResolverSpec)

describe(@"PLStateMachineBlockResolver", ^{

    __block PLStateMachine *fsm;

    PLStateMachineStateId const stateId = 32;
    __block PLStateMachineTrigger *trigger;

    beforeEach(^{
        fsm = [[PLStateMachine alloc] init];

        trigger = [PLStateMachineTrigger triggerWithId:1];
    });

    it(@"should call the resolverblock with proper parameters", ^{
        __block BOOL wasCalled = NO;
        PLStateMachineBlockResolver *resolver = [[PLStateMachineBlockResolver alloc] initWithParent:nil
                                                                                      resolverBlock:^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                                                                          wasCalled = YES;
                                                                                          [[trigger should] equal:trigger];
                                                                                          return PLStateMachineStateUndefined;
                                                                                      }];

        [resolver resolve:trigger in:fsm];

        [[theValue(wasCalled) should] beTrue];
    });

    it(@"should return the value provided by the resolverblock", ^{
        PLStateMachineBlockResolver *resolver = [[PLStateMachineBlockResolver alloc] initWithParent:nil
                                                                                      resolverBlock:^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                                                                          return stateId;
                                                                                      }];

        [[theValue([resolver resolve:trigger in:fsm]) should] equal:theValue(stateId)];
    });

    it(@"should not consult the parent resolver if the resolverblock succeeds", ^{
        id parentResolver = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];

        PLStateMachineBlockResolver *resolver = [[PLStateMachineBlockResolver alloc] initWithParent:parentResolver
                                                                                      resolverBlock:^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                                                                          return stateId;
                                                                                      }];

        [[parentResolver shouldNot] receive:@selector(resolve:in:)];
        [resolver resolve:trigger in:fsm];
    });

    it(@"should consult the parent resolver if the resolverblock fails", ^{
        id parentResolver = [KWMock mockForProtocol:@protocol(PLStateMachineResolver)];
        [parentResolver stub:@selector(resolve:in:) andReturn:theValue(stateId)];

        PLStateMachineBlockResolver *resolver = [[PLStateMachineBlockResolver alloc] initWithParent:parentResolver
                                                                                      resolverBlock:^PLStateMachineStateId(PLStateMachineTrigger *trigger, PLStateMachine *machine) {
                                                                                          return PLStateMachineStateUndefined;
                                                                                      }];

        [[[parentResolver should] receive] resolve:trigger in:fsm];
        [[theValue([resolver resolve:trigger in:fsm]) should] equal:theValue(stateId)];
    });
});

SPEC_END