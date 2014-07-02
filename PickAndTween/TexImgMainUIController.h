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
@property CustomCollectionViewController* collectionViewController;
@property UIPopoverController* popOverController;
@property NSTimeInterval duration;
@property IBOutlet UISlider* durationSlider;
@property IBOutlet UISlider* delaySlider;

-(IBAction) addDelay:(id)sender;
-(IBAction) changeDuration:(id)sender;
-(IBAction) openFunctionMenu:(id) sender;
- (IBAction)reset:(id)sender;

-(void) setTweenFunction:(NSString*) function;
@end
