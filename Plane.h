//
//  Plane.h
//  Treemap3D
//
//  Created by Kang, Hyunmo on 9/28/12.
//  Copyright (c) 2012 Kang, Hyunmo. All rights reserved.
//

#import <GLKit/GLKit.h>

#define DEFAULT_PLANE_SIZE 0.3

@interface Plane : NSObject
{
	GLKVector3 *vertices;
	GLKVector3 *labelVertices;
}

@property (nonatomic, strong) NSString *pid;
@property (nonatomic) int index;
@property (nonatomic) int row;
@property (nonatomic) int col;
@property (nonatomic) CGSize size;
@property (nonatomic) GLKVector3 rotation;
@property (nonatomic) GLKVector3 pos;

@property (nonatomic) GLKVector3 normal;

@property (nonatomic) GLKVector4 color;
@property (nonatomic) BOOL selected;
@property (nonatomic) BOOL needUpdate;

- (void)updateVertices;
- (GLKVector3 *)planeVertices;

@end
