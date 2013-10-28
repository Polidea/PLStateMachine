//
// Created by Antoni Kedracki on 28.10.2013.
// Copyright (c) 2013 Polidea. All rights reserved.
//

#import "PLTicTocViewController.h"
#import "PLTicToc.h"


@implementation PLTicTocViewController {
    PLTicToc *_model;
}

- (id)init {
    self = [super init];
    if (self) {
        _model = [PLTicToc new];

        [_model addObserver:self
                 forKeyPath:@"state"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
    }

    return self;
}

- (void)dealloc {
    [_model removeObserver:self
                forKeyPath:@"state"
                   context:nil];
}

- (UILabel *)labelView{
    return (UILabel *) self.view;
}

- (void)loadView {
    self.view = [[UILabel alloc] initWithFrame:CGRectZero];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.labelView.textColor = [UIColor blackColor];
    self.labelView.font = [UIFont boldSystemFontOfSize:40];
    self.labelView.textAlignment = NSTextAlignmentCenter;
    self.labelView.adjustsFontSizeToFitWidth = YES;
    self.labelView.numberOfLines = 2;
    self.labelView.userInteractionEnabled = YES;

    UITapGestureRecognizer * tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedView)];
    [self.view addGestureRecognizer:tapGestureRecognizer];

    [self setupViewForState];
}

- (void)tappedView {
    [_model tic];
}

- (void)setupViewForState{
    if(![self isViewLoaded]){
        return;
    }

    switch (_model.state){
        case PLTicTocStateStart:
            self.view.backgroundColor = [UIColor yellowColor];
            self.labelView.text = @"start";
            break;
        case PLTicTocStateCatchRhythm:
            self.view.backgroundColor = [UIColor orangeColor];
            self.labelView.text = @"set interval";
            break;
        case PLTicTocStateClick:
            self.view.backgroundColor = [UIColor greenColor];
            self.labelView.text = [NSString stringWithFormat:@"%d", _model.repeats];
            break;
        case PLTicTocStateResult:
            self.view.backgroundColor = [UIColor redColor];
            self.labelView.text = [NSString stringWithFormat:@"You lost!\nscore: %d", _model.repeats];
            break;
        default:
            break;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([keyPath isEqualToString:@"state"]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupViewForState];
        });
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


@end