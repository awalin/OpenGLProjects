#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>


@class GLKVAObject;
@class TexImgFrameBuffer;


@interface GLK2DrawCall : NSObject

@property(nonatomic) BOOL shouldClearColorBit;



@property(nonatomic,retain) GLKVAObject* VAO;
@property(nonatomic,retain) TexImgFrameBuffer* frameBuffer;

/** Every draw call MUST have a shaderprogram, or else it cannot draw objects nor pixels */
//@property(nonatomic,retain) GLK2ShaderProgram* shaderProgram;
@property GLKVector3* vertices;
@property GLKVector4* colors;

@property int numOfVerticesToDraw;
@property GLuint mode;
- (id)init;

-(float*) clearColourArray;
-(void) setClearColourRed:(float) r green:(float) g blue:(float) b alpha:(float) a;
-(void) drawWithMode:(GLuint) mode;

-(void) drawInFrmeBuffer:(GLuint) mode;

@end
