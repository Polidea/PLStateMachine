//
// Created by Antoni Kedracki on 28.10.2013.
// Copyright (c) 2013 Polidea. All rights reserved.
//


#import <Foundation/Foundation.h>

/*
This is the main view controller for the example game. All the game logic is implemented in the PLTicToc class.
PLTicTocViewController interfaces with it in two ways:
1) it pushes click events
2) it observes changes to the 'state' property and setups the view accordingly.
 */
@interface PLTicTocViewController : UIViewController
@end