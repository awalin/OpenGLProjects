//
//  PNT_EarthPoint.h
//  PickAndTween
//
//  Created by Sopan, Awalin on 7/16/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import "GLKVAObject.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "ViewController.h"

@interface PNT_EarthPoint : GLKVAObject


@property GLKVector3 flatLoc;
@property GLKVector3 roundLoc;
@property GLKVector2 texCoord;
@property GLKVector3 center;
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

-(PNT_EarthPoint*) init;

-(void) updateVertex:(GLKVector3) targetCenter
                mode:(ViewType)viewType
         timeElapsed:(NSTimeInterval)timeElapsed
            duration:(NSTimeInterval)duration
               ratio:(float)ratio;



@end
