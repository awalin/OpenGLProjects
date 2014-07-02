//
//  TexImgFrameBuffer.m
//  TexImg
//
//  Created by Sopan, Awalin on 6/30/14.
//  Copyright (c) 2014 __mstr__. All rights reserved.
//

#import "TexImgFrameBuffer.h"

@implementation TexImgFrameBuffer

@synthesize glName=framebuffer;

- (id)initWithWidth:(int)width height:(int)height {
    //create framebuffer and bind it
    
    self.VBOs = [[NSMutableDictionary alloc] init];
    
//    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    //  Create a color renderbuffer, allocate storage for it, and attach it to the framebuffer’s color attachment point.
    GLuint colorRenderbuffer;
    glGenRenderbuffers(1, &colorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER, colorRenderbuffer);
    
    GLuint depthRenderbuffer;
    glGenRenderbuffers(1, &depthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER) ;
    if(status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
    }
    
    self.VBOs = [[NSMutableDictionary alloc] init];
    
    return self;
}

@end
