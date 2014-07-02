//
//  TexImgPlane.h
//  TexImg
//
//  Created by Sopan, Awalin on 5/28/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "ViewController.h"
//@class ViewController;

@interface TexImgPlane : NSObject


@property GLKVector3* vertices;
@property GLKVector2* texCoord;
@property GLKVector4* colors;
@property GLKVector3 center;
@property UIColor* pickingColor;


@property int planeId;
@property int colorId;

@property float height;
@property float width;

@property int row;
@property int col;

@property float theta;
@property float phi;
@property float radius;
@property GLKVector3 planeRotation;
@property GLKVector3 scale;

-(TexImgPlane*) init;

-(void) updateVertices:(GLKVector3) targetCenter
          sourceCEnter:(GLKVector3) sourceCenter
                  mode:(ViewType*)viewType
           timeElapsed:(NSTimeInterval)timeElapsed
              duration:(NSTimeInterval)duration
                 ratio:(float)ratio;

@end
