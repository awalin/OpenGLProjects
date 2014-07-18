//
//  TexImgMainUIController.h
//  TexImg
//
//  Created by Sopan, Awalin on 6/10/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ViewController;
@class CustomCollectionViewController;

@interface TexImgMainUIController : UIViewController <UIPopoverControllerDelegate>

@property ViewController* glkViewController;

-(void) setTweenFunction:(NSString*) function;
@end
