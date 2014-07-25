#import "GLK2DrawCall.h"
#import "GLKVAObject.h"
#import "GLK2BufferObject.h"

@implementation GLK2DrawCall
{
	float clearColour[4];
}

-(void)dealloc
{
//	[super dealloc];
}

- (id)init
{
	self = [super init];
	if (self) {
		[self setClearColourRed:1.0f green:0 blue:1.0f alpha:1.0f];
	}
	return self;
}

-(float*) clearColourArray
{
	return &clearColour[0];
}



-(void) drawWithMode:(GLuint) mode{
//    NSLog(@"VAO name %d", self.VAO.glName );
    glBindVertexArrayOES( self.VAO.glName );
//    NSLog(@"%d", self.numOfVerticesToDraw);
    glDrawArrays(self.mode, 0, self.numOfVerticesToDraw);
    }

-(void) drawWithElements:(GLuint) mode{
    
    NSString* bufferType = [NSString stringWithFormat:@"%d",GL_ELEMENT_ARRAY_BUFFER];
    GLuint _planeIndicesBuffer = [(GLK2BufferObject*)[self.VAO.VBOs objectForKey:bufferType] glName];
//    NSLog(@"Inside draw: indices buffer %d, indices to draw %d", _planeIndicesBuffer, self.numOfVerticesToDraw);
   
    glBindVertexArrayOES( self.VAO.glName );
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _planeIndicesBuffer);
    glDrawElements(GL_TRIANGLES, self.numOfVerticesToDraw, GL_UNSIGNED_INT, NULL);
}

-(void) setClearColourRed:(float) r green:(float) g blue:(float) b alpha:(float) a
{
	clearColour[0] = r;
	clearColour[1] = g;
	clearColour[2] = b;
	clearColour[3] = a;
}

@end
