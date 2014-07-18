//
//  PNT_EarthPoint.m
//  PickAndTween
//
//  Created by Sopan, Awalin on 7/16/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import "PNT_EarthPoint.h"

@implementation PNT_EarthPoint

-(PNT_EarthPoint*) init{
    
    self = [super init];
    
    return self;
}

-(void) updateVertex:(GLKVector3) targetCenter
                mode:(ViewType)viewType
         timeElapsed:(NSTimeInterval)timeElapsed
            duration:(NSTimeInterval)duration
               ratio:(float)ratio {
    
    if(duration<=0.0){
        return;
    }
//    NSLog(@"inside update");
    GLKVector3 vrtx = self.center;
    
    GLKVector3 distanceC = GLKVector3Subtract(targetCenter, vrtx) ;
    //multiply scalar ratio , then add with the current value
    vrtx.x = vrtx.x + ratio*distanceC.x;
    vrtx.y = vrtx.y + ratio*distanceC.y;
    vrtx.z = vrtx.z + ratio*distanceC.z;
    
    distanceC = GLKVector3Subtract(vrtx, self.center);
    
    if(GLKVector3Length(distanceC) == 0){
        //change complete
        return;
    }
    self.center = vrtx;
    
    if(duration<=timeElapsed){
        self.center= targetCenter;
    }
    
}


@end
