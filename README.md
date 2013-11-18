# PLStateMachine

State machine framework for Objective-C

## Instalation

* build the PLStateMachine project
* copy and add the resulting libPLStateMachine.a and attached header files to your project.

## Concepts

The PLStateMachine is used to define and model a trigger based FSM. That is, a state change occurs only on arrival of an trigger/signal. PLStateMachine operates on following constructs:

* stateId - basic type (PLStateMachineStateId) constant identifing your states
* triggerId - basic type (PLStateMachineTriggerId) constant identifying your triggers
* transition resolver - on trigger arrival the transition resolver for the current state is consulted. It returns the next state the machine should transition to (or PLStateMachineStateUndefined if no transition occures). Two concrete implementation are provided out of the box. One taking a dictionary maping trigger signals to stateIds. The second taking a block.
* transition callback - on transition all the registered callbacks for it are called.

## Usage

* define your machine states and triggers (pro tip: use typedef NS_ENUM with the PLStateMachineStateId and PLStateMachineTriggerId base types)
* create a PLStateMachine instance
* register your states with [PLStateMachine registerStateWithId:name:resolver:] The first and second argument beeing your stateId (the enum) and human readable name respectivly. The third parameter should be a transition resolver for the state. (pro tip: if you use block resolvers, try to add only code for transition handling into it)
* attach your transition callbacks. Thats the place all your logic goes in

## Example

A simple "click with right timing" game is provided to ilustrate some of functionality of PLStateMachine. The aim of the game is to click the screen in constant intervals. Just build and run the TitToc project to check it out.