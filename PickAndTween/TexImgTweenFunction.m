//
//  TexImgTweenFunction.m
//  TexImg
//
//  Created by Sopan, Awalin on 6/20/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import "TexImgTweenFunction.h"

@implementation TexImgTweenFunction {


    float duration;
    float time;
    float ratio;

}

@synthesize  functionNames;

-(TexImgTweenFunction*) init{

    self.selectedFunction = @"linear";
    return self;

}

-(float) quadin{
    
//    NSLog(@"quadin");
    return  pow(ratio, 2.0);
    

}
-(float) quadout{
    
    return -ratio*(ratio-2);
    
}
-(float) sinein{
    
    return (1 - cos(ratio * (M_PI_2)));
}
-(float) sineout{
    
    return sin(ratio * (M_PI_2)); //ease out
}
-(float) linear{
    
    return ratio;
}

-(float) bounceinout{

    if(time<duration/2){
        ratio = time*2/duration;
        return 0.5*[self bouncein];
    }else {
        ratio = (time*2-duration)/duration;
        return 0.5*(1+[self bounceout]);
    }

}

-(float) bouncein{
    ratio = duration-time;
    return -[self bounceout];
}

-(float) bounceout {

    if(ratio < 1/2.75) {
        return  7.5625*ratio*ratio;
    }else if(ratio<2/2.75){
        ratio-=(1.5/2.75);
        return (7.5625*ratio*ratio + .75);
    }else if(ratio<2.5/2.75){
        ratio-=(2.25/2.75);
        return 7.5625*(ratio*ratio) + .9375;
    }else {
        ratio-=(2.625/2.75);
        return 7.5625*(ratio*ratio) +.984375;
    }
    
//    return ratio;
    
}

-(float) calculateTweenWithTime:(float)mtime duration:(float)mduration{
    
    time= mtime;
    duration=mduration;
    ratio = time/duration;
    
    NSString* functionName= self.selectedFunction;
//    NSLog(@"function %@", self.selectedFunction);
    
    if([functionName isEqualToString:@"linear"]){
        return [self linear];
    } else if ([functionName isEqualToString:@"quadin"]){
         return [self quadin];
    } else if ([functionName isEqualToString:@"quadout"]){
         return [self quadout];
    } else if ([functionName isEqualToString:@"sinein"]){
         return [self sinein];
    } else if ([functionName isEqualToString:@"sineout"]){
        return [self sineout];
    } else if ([functionName isEqualToString:@"bouncein"]){
        return [self bouncein];
    } else if ([functionName isEqualToString:@"bounceout"]){
        return [self bounceout];
    }
    
//   SEL selc = NSSelectorFromString(@"linear");
////    if(selc!=NULL){
//        [self performSelector:selc];
////    }
    return ratio;//default linear
}




@end
