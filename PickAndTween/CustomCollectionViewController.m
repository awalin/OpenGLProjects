//
//  CustomeCollectionViewController.m
//  TexImg
//
//  Created by Sopan, Awalin on 6/17/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import "CustomCollectionViewController.h"
#import "TexImgCollectionCell.h"
#import "TexImgCollectionHeaderView.h"
#import "TexImgMainUIController.h"

@implementation CustomCollectionViewController


- (void)viewDidLoad{
    
    [super viewDidLoad];
    self.collectionView.backgroundColor = [UIColor  colorWithRed:0.22 green:0.22 blue:0.22 alpha:0.8];
}


#pragma mark -
#pragma mark UICollectionViewDataSource

//one section
-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 4;
}


//number of cells
-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if(section==0) {
        return 1;}
    else
        return 3;
  ;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                 cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    TexImgCollectionCell *myCell = [collectionView
                                    dequeueReusableCellWithReuseIdentifier:@"customCellView"
                                    forIndexPath:indexPath];
    
    UIImage* imageOrigin = [UIImage imageNamed:@"easing-functions.png"];
    
    long index = indexPath.item;
    float left=(index)*(80+10);
    float top=([indexPath section])*(62+16);
    
    CGRect rect = CGRectMake(left, top, 80, 62);
    CGImageRef imageRef = CGImageCreateWithImageInRect([imageOrigin CGImage], rect);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    myCell.imageView.image = image;
    
//    if(indexPath.section==self.selectedSection  && indexPath.row==self.selectedCellInSection){
//        myCell.selected = YES;
//    }
//    else {
//        myCell.selected=NO;
//    }
    return myCell;
}

#pragma mark - UICollectionViewDelegate

-(BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // TODO: Select Item
//    indexPath
    NSLog(@" %d, %d ", indexPath.row, indexPath.section);
    NSMutableString* function= [NSMutableString string];;
    
    if(indexPath.section==0){
        [function appendString:@"linear"];
    }else if (indexPath.section==1){
        [function appendString:@"sine"];
        if(indexPath.row==0){
            [function appendString:@"in"];
            
        }else if(indexPath.row==1){
            [function appendString:@"out"];
        }
    }else if (indexPath.section==2){
        [function appendString:@"quad"];
        if(indexPath.row==0){
            [function appendString:@"in"];
        }else if(indexPath.row==1){
            [function appendString:@"out"];
        }
    }
    else if (indexPath.section==3){
        [function appendString:@"bounce"];
        if(indexPath.row==0){
            [function appendString:@"in"];
        }else if(indexPath.row==1){
            [function appendString:@"out"];
        }
    }else {
     [function appendString:@"linear"];
    }
    self.selectedSection = indexPath.section;
    self.selectedCellInSection = indexPath.row;
    
//    [myCell reloadInputViews];
    NSLog(@"selected function %@", function);
    
    self.selectedFunction = function;
    [(TexImgMainUIController*)[self parentViewController] setTweenFunction:self.selectedFunction];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:@"Easing" object:self userInfo:nil];

}
- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    // TODO: Deselect item
}

@end
