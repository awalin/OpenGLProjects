//
//  GLK2BufferObject.h
//  map3d
//
//  Created by Sopan, Awalin on 5/15/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GLK2BufferObject : NSObject

@property(nonatomic, readonly) GLuint glName;
@property GLsizei totalBytesPerItem;
@property GLenum usageHint;
@property int items;

@property(nonatomic) GLenum glBufferType; // = GL_ARRAY_BUFFER

-(void) upload:(void *) dataArray numItems:(int) count usageHint:(GLenum) usage ;

+(GLK2BufferObject*) vertexBufferObject;
-(void) update: (void *) dataArray;

@end
