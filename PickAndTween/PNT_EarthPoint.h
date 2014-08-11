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
#import "TexImgTween.h"

@interface PNT_EarthPoint : NSObject


@property GLKVector3 flatLoc;
@property GLKVector3 roundLoc;
@property GLKVector2 texCoord;
@property GLKVector3 center;

@property GLKVector3 *bezierPointsGlobe;
@property GLKVector3 *bezierPointsFlat;
@property GLKVector3 *points;

@property int planeId;
@property int colorId;

@property float height;
@property float width;
@property float length;
@property int row;
@property int col;
//read long and lat from file, map it into screen coordinates, then those points will become end points of lines
//lines will make one model
@property float longitude;
@property float lattitude;

@property float theta;
@property float phi;
@property float radius;
@property GLKVector3 planeRotation;
@property GLKVector3 scale;

@property BOOL needsUpdate;

-(PNT_EarthPoint*) init;

-(BOOL) updateVertex:(GLKVector3) targetCenter
                mode:(ViewType)viewType
         timeElapsed:(NSTimeInterval)timeElapsed
            duration:(NSTimeInterval)duration
               ratio:(float)ratio;

-(void) createBezierStart:(PNT_EarthPoint*) start
                     view:(ViewType)vType
                 segments:(int)segments;

-(BOOL)updateBezierView:(ViewType)vType
                segments:(int)segments
             timeElapsed:(NSTimeInterval)timeElapsed
                duration:(NSTimeInterval)duration
                   ratio:(float)ratio;

-(void) createParticle;
-(BOOL) updateParticleCenter:(GLKVector3) targetCenter;

-(BOOL) updateParticleCenter:(GLKVector3)pointTarget
                withRotation:(GLKVector3)angle;
@end
