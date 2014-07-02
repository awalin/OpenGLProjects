//
//  TexImgPlane.m
//  TexImg
//
//  Created by Sopan, Awalin on 5/28/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import "TexImgPlane.h"
#import "ViewController.h"


@implementation TexImgPlane

-(TexImgPlane*) init{
    
    self = [super init];
    
    self.vertices = (GLKVector3*)malloc(6*sizeof(GLKVector3));
    self.texCoord = (GLKVector2*)malloc(6*sizeof(GLKVector2));
    self.colors = (GLKVector4*)malloc(6*sizeof(GLKVector4));

    return self;
}

-(void) updateVertices:(GLKVector3) targetCenter
          sourceCEnter:(GLKVector3) sourceCenter
                  mode:(ViewType*)viewType
           timeElapsed:(NSTimeInterval)timeElapsed
              duration:(NSTimeInterval)duration
                 ratio:(float)ratio {

    if(duration<=0.0){
        return;
    }
    GLKVector3 vrtx;
    GLfloat eachWidth = self.width;
    GLfloat eachHeight = self.height;
    
    GLKMatrix3 rot = GLKMatrix3Identity;
    GLKVector3 c = GLKVector3Make( 0, 0, 0);
    GLKVector3* targets =  (GLKVector3*) malloc(6*sizeof(GLKVector3));
    
    targets[0]= GLKVector3Make(c.x - eachWidth/2,  c.y - eachHeight/2, c.z);// BL
    targets[1]= GLKVector3Make(c.x + eachWidth/2,  c.y - eachHeight/2, c.z); // BR
    targets[2]= GLKVector3Make(c.x - eachWidth/2,  c.y + eachHeight/2, c.z); //TL
    targets[3]= GLKVector3Make(c.x + eachWidth/2,  c.y + eachHeight/2, c.z); //TR
    targets[4]= GLKVector3Make(c.x + eachWidth/2,  c.y - eachHeight/2, c.z); //BR
    targets[5]= GLKVector3Make(c.x - eachWidth/2,  c.y + eachHeight/2, c.z); //TL
    
    if(viewType==GLOBE){
//        NSLog(@"GLOBE");
        rot = GLKMatrix3MakeXRotation((self.theta+M_PI_2+M_PI) );
        rot = GLKMatrix3Multiply(GLKMatrix3MakeYRotation( self.phi), rot);
    } else {
//        NSLog(@"WALL");
    }
    
    //Center
    vrtx = self.center;
    
    GLKVector3 distanceC = GLKVector3Subtract(targetCenter, vrtx) ;
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

    for(int i =0; i< 6; i++){
        vrtx = self.vertices[i];
        targets[i] = GLKMatrix3MultiplyVector3(rot, targets[i]);
        targets[i] = GLKVector3Add(targets[i],targetCenter);
        if(duration<=timeElapsed){
            self.vertices[i]= targets[i];
        }else {
        //distanceC: change on position
            distanceC = GLKVector3Subtract(targets[i], vrtx) ;
        //here the ratio is for linear function, it will be changed based on funtion
            vrtx.x = vrtx.x + ratio*distanceC.x;
            vrtx.y = vrtx.y + ratio*distanceC.y;
            vrtx.z = vrtx.z + ratio*distanceC.z;
            self.vertices[i]= vrtx;
        }
    }

}

@end
