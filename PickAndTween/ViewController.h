#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@class GLK2BufferObject;
@class GLKVAObject;
@class TexImgPlane;
@class TexImgTweens;
@class TexImgTweenFunction;


@interface ViewController : GLKViewController


@property(nonatomic, retain) NSMutableArray* shapes;



@property (strong, nonatomic) GLKBaseEffect *effect;

typedef struct {
    GLKVector3 positionCoords;
    GLKVector2 textureCoords;
    GLKVector4 colorCoords;
}
CustomPlane;

typedef enum {
    GLOBE,
    WALL,
    RESET
} ViewType;

@property BOOL viewChanged;
@property ViewType* viewType;
@property CustomPlane *planes; // array of the planes

@property NSMutableArray* tweens;
@property NSMutableArray* allPlanes;

@property double latMx;
@property double longMx;
@property double latMn;
@property double longMn;

@property UIPanGestureRecognizer *panRecognizer;
@property UIPinchGestureRecognizer *pinchRecognizer;
@property(nonatomic,retain) EAGLContext* localContext;
@property (strong) NSMutableDictionary *colorMap;

@property (strong, nonatomic) UIWindow *window;
-(void) setDuration:(float) val;
-(void) setDelay:(float) val;
-(void) makePlanes;
-(void) makeGlobe;
-(void) resetView;
-(void) changeView:(ViewType*)viewType;
-(void)setupGL;
-(void) setTweenFunction:(NSString*) function;

@end
