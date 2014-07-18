//
//  GLK2BufferObject.m
//  map3d
//
//  Created by Sopan, Awalin on 5/15/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import "GLK2BufferObject.h"

@implementation GLK2BufferObject
@synthesize glName;

-(void) upload:(void *) dataArray numItems:(int)count usageHint:(GLenum) usage {
    self.usageHint = usage;
    self.items = count;
	glBindBuffer( self.glBufferType, self.glName );
	glBufferData( self.glBufferType, self.items * self.totalBytesPerItem, dataArray, self.usageHint);
}

-(void) uploadElementArray:(GLushort*)elements {

    glBindBuffer(self.glBufferType, self.glName);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLushort)*self.items, elements, GL_STATIC_DRAW);


}

-(void) update: (void *) dataArray{
    glBindBuffer( self.glBufferType, self.glName );
	glBufferData( self.glBufferType, self.items * self.totalBytesPerItem, dataArray, self.usageHint);
}

+(GLK2BufferObject *)vertexBufferObject {
	GLK2BufferObject* newObject = [[GLK2BufferObject alloc] init];
	newObject.glBufferType = GL_ARRAY_BUFFER;
    
	return newObject;
}

+(GLK2BufferObject *)elementBufferObject {
	GLK2BufferObject* newObject = [[GLK2BufferObject alloc] init];
	newObject.glBufferType = GL_ELEMENT_ARRAY_BUFFER;
    
	return newObject;
}

- (id)init
{
    self = [super init];
    if (self) {
        glGenBuffers(1, &glName);
//         NSLog(@"name of vb = %d", glName);
    }
    return self;
}



-(void) bind {
	glBindBuffer(self.glBufferType, self.glName);
}



@end
