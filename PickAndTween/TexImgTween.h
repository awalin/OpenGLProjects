//
//  TexImgTween.h
//  TexImg
//
//  Created by Sopan, Awalin on 6/9/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
@class TexImgPlane;

@interface TexImgTween : NSObject

@property TexImgPlane* plane;
@property int planeId;

@property GLKVector3 tweenRotation;
@property GLKVector3 tweenScale;

@property GLKVector3 globeCenter;
@property GLKVector3 wallCenter;

@property GLKVector3 targetCenter;//either globe or wall center
@property GLKVector3 sourceCenter;//either globe or wall center

@property float targetTheta;
@property float targetPhi;

@property NSTimeInterval duration;

//@property NSDate* currentTime;

@end
