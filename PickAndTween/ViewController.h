#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@class GLK2BufferObject;
@class GLKVAObject;
@class TexImgPlane;
@class TexImgTweens;
@class TexImgTweenFunction;
@class PNT_EarthPoint;


@interface ViewController : GLKViewController

@property (strong, nonatomic) GLKBaseEffect *effect;

typedef struct {
    GLKVector3 positionCoords;
    GLKVector2 textureCoords;
    GLKVector4 colorCoords;
}
CustomPoint;



typedef enum {
    WALL,
    GLOBE,
    RESET
} ViewType;

@property BOOL viewChanged;
@property ViewType viewType;
@property CustomPoint *locations; // array of the planes

@property NSMutableArray* tweens;
@property NSMutableArray* allLocations;

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
-(void) makePlane;
-(void) makeGlobe;
-(void) resetView;
-(void) changeView:(ViewType)viewType;
-(IBAction) changeViewType:(id)sender;
-(void)setupGL;@end
