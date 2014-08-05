#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@class GLK2BufferObject;
@class GLKVAObject;
@class TexImgPlane;
@class TexImgTweens;
@class TexImgTweenFunction;
@class PNT_EarthPoint;


typedef struct {
    GLKVector3 positionCoords;
    GLKVector2 textureCoords;
    GLKVector4 colorCoords;
} CustomPoint;


typedef struct {
	float lat;
	float lon;
	float magnitude;
} LatLonBar;


typedef enum {
    WALL,
    GLOBE,
    RESET
} ViewType;

typedef enum {
    BAR,
    ARC
} BarOrArc;


@interface ViewController : GLKViewController

@property (strong, nonatomic) GLKBaseEffect *effect;


@property BOOL viewChanged;
@property ViewType viewType;
@property BarOrArc barOrArc;

@property CustomPoint *locations; // array of the planes
@property CustomPoint *bars;
@property CustomPoint *curves;
@property CustomPoint *particles;

@property NSMutableArray* earthTweens;
@property NSMutableArray* barTweens;
@property NSMutableArray* curveTweens;
@property NSMutableArray* particleTweens;

@property NSMutableArray* allLocations;
@property NSMutableArray* allLines;
@property NSMutableArray* allCurves;
@property NSMutableArray* allParticles;

@property(nonatomic, retain) NSMutableArray* shapes;

@property double latMx;
@property double longMx;
@property double latMn;
@property double longMn;

@property IBOutlet UISegmentedControl* viewTypeSegments;
@property IBOutlet UISegmentedControl* barOrArcSegments;
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
-(IBAction)swapBarOrArc:(id)sender;
-(IBAction) changeViewType:(id)sender;
-(void)setupGL;@end
