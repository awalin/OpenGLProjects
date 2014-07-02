//
//  CustomeCollectionViewController.h
//  TexImg
//
//  Created by Sopan, Awalin on 6/17/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TexImgCollectionCell;
@class TexImgCollectionHeaderView;

@interface CustomCollectionViewController : UICollectionViewController <UICollectionViewDataSource, UICollectionViewDelegate>

//@property IBOutlet TexImgCollectionHeaderView* header;
@property (strong, nonatomic) NSMutableArray *tweenFunctionImages;
@property (nonatomic, strong) NSIndexPath *selectedItemIndexPath;
@property NSInteger selectedSection;
@property NSInteger selectedCellInSection;
@property NSString* selectedFunction;

@end
