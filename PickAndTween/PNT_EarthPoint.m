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

-(BOOL) updateVertex:(GLKVector3) targetCenter
                mode:(ViewType)viewType
         timeElapsed:(NSTimeInterval)timeElapsed
            duration:(NSTimeInterval)duration
               ratio:(float)ratio {
    
    if(duration<=0.0){
        return NO;
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
        return NO;
    }
    self.center = vrtx;
    
    if(duration<=timeElapsed){
        self.center= targetCenter;
    }
    return YES;
    
}

-(void) createBezierStart:(GLKVector3) start end:(GLKVector3) end view:(ViewType)vType segments:(int)segments{

    
    GLKVector3 controlPoint1 = GLKVector3Add( start,  GLKVector3MultiplyScalar( GLKVector3Normalize( GLKVector3Subtract(end, start)), 0.25) ) ;
    GLKVector3 controlPoint2 = GLKVector3Add( start,  GLKVector3MultiplyScalar( GLKVector3Normalize( GLKVector3Subtract(end, start)), 0.75) ) ;
    //if globe mode
    if(vType==GLOBE){
        //            controlPoint1 =  GLKVector3Make(controlPoint1.x, controlPoint1.y, 0.5);
        //            controlPoint2 =  GLKVector3Make(controlPoint2.x, controlPoint2.y, 0.5);
    } else {
        controlPoint1 =  GLKVector3Make(controlPoint1.x, controlPoint1.y, 0.5);
        controlPoint2 =  GLKVector3Make(controlPoint2.x, controlPoint2.y, 0.5);
    }
    //4+20, 20=segments
    if(self.bezierPoints==NULL){
        self.bezierPoints = (GLKVector3*)malloc(24*sizeof(GLKVector3));
    }


    self.bezierPoints[0]=start;
    self.bezierPoints[1]=controlPoint1;
    self.bezierPoints[2]=controlPoint2;
    self.bezierPoints[3]=end;
    
    //cubic bezier curve
    for(int i=0; i<segments; i++){
        float t = i*1.0/(1.0f*segments);
        float nt = 1.0f - t;
        GLKVector3 pointb = GLKVector3Make(start.x * nt * nt * nt  +  3.0 * controlPoint1.x * nt * nt * t  +  3.0 * controlPoint2.x * nt * t * t  +  end.x * t * t * t,
                                           start.y * nt * nt * nt  +  3.0 * controlPoint1.y * nt * nt * t  +  3.0 * controlPoint2.y * nt * t * t  +  end.y * t * t * t,
                                           start.z * nt * nt * nt  +  3.0 * controlPoint1.z * nt * nt * t  +  3.0 * controlPoint2.z * nt * t * t  +  end.z * t * t * t   );
         self.bezierPoints[4+i] = pointb;

    };


}

@end
