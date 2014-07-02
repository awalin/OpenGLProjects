//
//  TexImgTweenFunction.h
//  TexImg
//
//  Created by Sopan, Awalin on 6/20/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TexImgTweenFunction : UICollectionReusableView


@property NSMutableDictionary* functionNames;
@property NSString* selectedFunction;

-(float) calculateTweenWithTime:(float)time duration:(float)duration;

@end
