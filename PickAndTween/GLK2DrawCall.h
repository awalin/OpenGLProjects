#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>


@class GLKVAObject;
@class GLK2BufferObject;
@interface GLK2DrawCall : NSObject

@property(nonatomic) BOOL shouldClearColorBit;
@property(nonatomic,retain) GLKVAObject* VAO;

/** Every draw call MUST have a shaderprogram, or else it cannot draw objects nor pixels */
//@property(nonatomic,retain) GLK2ShaderProgram* shaderProgram;
@property GLKVector4* colors;
@property int numOfVerticesToDraw;
@property GLuint mode;
- (id)init;

-(float*) clearColourArray;
-(void) setClearColourRed:(float) r green:(float) g blue:(float) b alpha:(float) a;
-(void) drawWithMode:(GLuint) mode;
-(void) drawWithElements:(GLuint)mode;

@end
