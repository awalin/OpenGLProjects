//
//  TexImgCustomCellBackground.m
//  TexImg
//
//  Created by Sopan, Awalin on 6/24/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import "TexImgCustomCellBackground.h"

@implementation TexImgCustomCellBackground


- (void)drawRect:(CGRect)rect
{
    // draw a rounded rect bezier path filled with blue
    CGContextRef aRef = UIGraphicsGetCurrentContext();
    CGContextSaveGState(aRef);
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:1.0f];
    [bezierPath setLineWidth:5.0f];
     UIColor *fillColor = [UIColor colorWithRed:0.6 green:0.7 blue:0.8 alpha:1];
    [fillColor setFill];
    [bezierPath stroke];
    [bezierPath fill];
    CGContextRestoreGState(aRef);
}

@end
