//
//  PNT_EarthPoint.m
//  PickAndTween
//  Created by Sopan, Awalin on 7/16/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.


#import "PNT_EarthPoint.h"

@class TexImgTween;

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
    
    if(timeElapsed >= duration){
        self.center= targetCenter;
    }
    return YES;
    
}

-(void) createBezierStart:(PNT_EarthPoint*) start view:(ViewType)vType segments:(int)segments{
    
    //4+20, 20=segments
    if(self.bezierPointsGlobe==NULL){
        self.bezierPointsGlobe = (GLKVector3*)malloc((segments+1+4)*sizeof(GLKVector3));
    }
    
    if(self.bezierPointsFlat==NULL){
        self.bezierPointsFlat = (GLKVector3*)malloc((segments+1+4)*sizeof(GLKVector3));
    }
    if(self.bezierPoints==NULL){
        self.bezierPoints = (GLKVector3*)malloc((segments+1+4)*sizeof(GLKVector3));
    }
    
//    NSLog(@"creating bezier %d", self.planeId);
    
    GLKVector3 controlPoint1 ;
    GLKVector3 controlPoint2 ;
    
      float angleCos =  (-(GLKVector3DotProduct(start.roundLoc, self.roundLoc))+2.0)*0.5;
    
    
 //prepare the bezier for globe mode
        float theta1  = 0.25*self.theta+0.75*start.theta;
        float phi1    = 0.25*self.phi+0.75*start.phi;
        
        GLfloat x1 = 1.0*sin(theta1)*cos(phi1);
        GLfloat y1 = 1.0*sin(theta1)*sin(phi1);
        GLfloat z1 = 1.0*cos(theta1);
        controlPoint1 = GLKVector3Make( y1, z1, x1);
        
        GLKVector3 startP = controlPoint1;
        GLKVector3 endP = GLKVector3Normalize(GLKVector3Subtract(controlPoint1,GLKVector3Make(0,0,0)));
        endP = GLKVector3Add(GLKVector3MultiplyScalar(endP,angleCos),startP);
        controlPoint1 = endP;
        
        float theta2 = 0.75*self.theta+0.25*start.theta;
        float phi2    = 0.75*self.phi+0.25*start.phi;
        x1 = 1.0*sin(theta2)*cos(phi2);
        y1 = 1.0*sin(theta2)*sin(phi2);
        z1 = 1.0*cos(theta2);
        controlPoint2 = GLKVector3Make( y1, z1, x1);
        
        startP = controlPoint2;
        endP = GLKVector3Normalize(GLKVector3Subtract(controlPoint2,GLKVector3Make(0,0,0)));
        endP = GLKVector3Add(GLKVector3MultiplyScalar(endP,angleCos),startP);
        controlPoint2 = endP;

        self.bezierPointsGlobe[0]=start.roundLoc;
        self.bezierPointsGlobe[1]=controlPoint1;
        self.bezierPointsGlobe[2]=controlPoint2;
        self.bezierPointsGlobe[3]=self.roundLoc;
        
        //    NSLog(@"creating bezier location id %d, center %f", self.planeId, self.bezierPoints[0].x);
        //cubic bezier curve
        for(int i=0; i<=segments; i++){
            float t = i*1.0/(1.0f*segments);
            float nt = 1.0f - t;
            GLKVector3 pointb = GLKVector3Make(start.roundLoc.x * nt * nt * nt + 3.0 * controlPoint1.x * nt * nt * t + 3.0 * controlPoint2.x * nt * t * t +  self.roundLoc.x * t * t * t,
                                               start.roundLoc.y * nt * nt * nt + 3.0 * controlPoint1.y * nt * nt * t + 3.0 * controlPoint2.y * nt * t * t +  self.roundLoc.y * t * t * t,
                                               start.roundLoc.z * nt * nt * nt + 3.0 * controlPoint1.z * nt * nt * t + 3.0 * controlPoint2.z * nt * t * t +  self.roundLoc.z * t * t * t );
            self.bezierPointsGlobe[4+i] = pointb;
        }
    //prepare the bezier for flat surface
        angleCos =  (-(GLKVector3DotProduct(start.flatLoc, self.flatLoc))+2.0)*0.2 ;
    
//        NSLog(@"%f", angleCos);
        controlPoint1 =  GLKVector3Make(0.25*self.flatLoc.x+0.75*start.flatLoc.x, 0.25*self.flatLoc.y+0.75*start.flatLoc.y, 1.0*angleCos);
        controlPoint2 =  GLKVector3Make(0.75*self.flatLoc.x+0.25*start.flatLoc.x, 0.75*self.flatLoc.y+0.25*start.flatLoc.y, 1.0*angleCos);
        
        self.bezierPointsFlat[0]=start.flatLoc;
        self.bezierPointsFlat[1]=controlPoint1;
        self.bezierPointsFlat[2]=controlPoint2;
        self.bezierPointsFlat[3]=self.flatLoc;
        
        //    NSLog(@"creating bezier location id %d, center %f", self.planeId, self.bezierPoints[0].x);
        //cubic bezier curve
        for(int i=0; i<=segments; i++){
            float t = i*1.0/(1.0f*segments);
            float nt = 1.0f - t;
            GLKVector3 pointb = GLKVector3Make(start.flatLoc.x * nt * nt * nt + 3.0 * controlPoint1.x * nt * nt * t + 3.0 * controlPoint2.x * nt * t * t +  self.flatLoc.x * t * t * t,
                                               start.flatLoc.y * nt * nt * nt + 3.0 * controlPoint1.y * nt * nt * t + 3.0 * controlPoint2.y * nt * t * t +  self.flatLoc.y * t * t * t,
                                               start.flatLoc.z * nt * nt * nt + 3.0 * controlPoint1.z * nt * nt * t + 3.0 * controlPoint2.z * nt * t * t +  self.flatLoc.z * t * t * t );
            self.bezierPointsFlat[4+i] = pointb;
        }
    
    
    if(vType==GLOBE){
        for(int i=0; i< segments+1+4; i++){
            self.bezierPoints[i] = self.bezierPointsGlobe[i];
        }
    }else{
        for(int i=0; i< segments+1+4; i++){
            self.bezierPoints[i] = self.bezierPointsFlat[i];
        }

    }
    
}



-(BOOL) updateBezierView:(ViewType)vType
                 segments:(int)segments
              timeElapsed:(NSTimeInterval)timeElapsed
                 duration:(NSTimeInterval)duration
                    ratio:(float)ratio{
    

    
    if(duration<=0.0){
        self.needsUpdate=NO;
        return NO;
    }
     GLKVector3 vrtx, distanceC;
    
    if(vType==GLOBE){//target == globe
        for(int i=0; i< segments+1+4; i++){
            
            vrtx = self.bezierPoints[i];//current fist point
            distanceC = GLKVector3Subtract(self.bezierPointsGlobe[i], vrtx) ;
            //multiply scalar ratio , then add with the current value
            vrtx.x = vrtx.x + ratio*distanceC.x;
            vrtx.y = vrtx.y + ratio*distanceC.y;
            vrtx.z = vrtx.z + ratio*distanceC.z;
            
            distanceC = GLKVector3Subtract(vrtx, self.bezierPoints[i]);
            if(GLKVector3Length(distanceC) == 0){
                //change complete
                return NO;
            }
            
            self.bezierPoints[i] = vrtx;
            if(duration<=timeElapsed){
                self.bezierPoints[i] = self.bezierPointsGlobe[i];
            }
            
        }
        
    } else if(vType==WALL){//target == globe
        for(int i=0; i< segments+1+4; i++){
            
            vrtx = self.bezierPoints[i];//current fist point
            distanceC = GLKVector3Subtract(self.bezierPointsFlat[i], vrtx) ;
            //multiply scalar ratio , then add with the current value
            vrtx.x = vrtx.x + ratio*distanceC.x;
            vrtx.y = vrtx.y + ratio*distanceC.y;
            vrtx.z = vrtx.z + ratio*distanceC.z;
            
            distanceC = GLKVector3Subtract(vrtx, self.bezierPoints[i]);
            if(GLKVector3Length(distanceC) == 0){
                //change complete
                return NO;
            }
            self.bezierPoints[i] = vrtx;
            
            if(duration<=timeElapsed){
                self.bezierPoints[i] = self.bezierPointsFlat[i];
            }
            
        }
        
    }
    return YES;
    
    
    
}

@end
