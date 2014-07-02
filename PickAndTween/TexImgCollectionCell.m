//
//  TexImgCollectionCell.m
//  TexImg
//
//  Created by Sopan, Awalin on 6/17/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import "TexImgCollectionCell.h"

#import "TexImgCustomCellBackground.h"

@implementation TexImgCollectionCell


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        // change to our custom selected background view
        TexImgCustomCellBackground *backgroundView = [[TexImgCustomCellBackground alloc] initWithFrame:CGRectZero];
        self.selectedBackgroundView = backgroundView;
//        self.contentView.backgroundColor = [UIColor whiteColor];
    }
    return self;
}

@end
