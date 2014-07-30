/**
 Version 1: c.f. http://t-machine.org/index.php/2013/09/08/opengl-es-2-basic-drawing/
 Part 3: ... not published yet ...
 */
#import "ViewController.h"
#import "GLK2DrawCall.h"
#import "GLKVAObject.h"
#import "GLK2BufferObject.h"
#import "TexImgPlane.h"
#import "PNT_EarthPoint.h"
#import "TexImgTween.h"
#import "TexImgTweenFunction.h"



@implementation ViewController {
    
    float friction;
    int taps;
    GLKTextureInfo * info ;
    GLKVector3 velocity;
    GLKVector3 touchStart;
    NSDate *startTime;
    
    BOOL touchEnded;
    // modelView properties
    GLfloat zoomscale;
    GLKVector3 modelTranslation;
    GLKVector3 modelrotation;
    GLKVector3 currentRotation;
    GLKMatrix4 _rotMatrix;
    GLfloat zTranslation;
    NSTimeInterval _duration;
    NSTimeInterval delay;
    GLuint *meshIndices;
    int totalIndices;
    int totalPlanes;
    int totalPoints;
    int totalBars;
    int totalCurves;
    int totalLinePoints;
    int totalCurvePoints;
    BOOL toRotate;
    float imageAspect;
    
    
    int rows;
    int cols;
    float radius;
    float spanX ;
    float offsetX;
    float spanY;
    float offsetY;
    GLfloat eachWidth;
    GLfloat eachHeight;
    BOOL resetCalled;
    
    GLuint locationVertexBuffer;
    GLuint locationTextureBuffer;
    GLuint locationColorBuffer;
    GLuint _planeIndicesBuffer;
    
    TexImgTweenFunction* tweenFunction;
    int segmentsPerCurve;
    
}


@synthesize effect;

-(void) viewDidLoad
{
	[super viewDidLoad];
    
    
    /** Creating and "making current" an EAGLContext must be the very first thing any OpenGL app does! */
	if( self.localContext == nil )
	{
		self.localContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	}
	NSAssert( self.localContext != nil, @"Failed to create ES context");
	[EAGLContext setCurrentContext:self.localContext]; // VERY important! GL silently stops working without this
	
	/** Enable GL rendering by enabling the GLKView (enable it by giving it an EAGLContext to render to) */
	GLKView *view = (GLKView *)self.view;
	view.context = self.localContext;
	view.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    //To enable multisamle, it needs to be compiled as iPad, not univresal device.
    view.drawableMultisample = GLKViewDrawableMultisample4X;
    
    [view bindDrawable];
    rows = 100;
    cols = 100;
	totalPlanes = (cols-1)*(rows-1);
    totalIndices = totalPlanes*6;
    //    NSLog(@"total indices %d", totalIndices);
    totalPoints = rows*cols;
    self.locations = (CustomPoint*) malloc(totalPoints*sizeof(CustomPoint));
    self.allLocations = [[NSMutableArray alloc] initWithCapacity:totalPoints];
    
    totalBars = (sizeof(_population)/sizeof(_population[0]));
    //    NSLog(@"total bars %d", totalBars);
    totalLinePoints = 2*totalBars;
    self.bars = (CustomPoint*)malloc(totalLinePoints*sizeof(CustomPoint));
    self.allLines = [[NSMutableArray alloc] initWithCapacity:totalLinePoints];
    
    totalCurves = (sizeof(_country)/sizeof(_country[0]))-1;
    segmentsPerCurve = 20;
    totalCurvePoints = totalCurves*(segmentsPerCurve+1);
    self.curves = (CustomPoint*)malloc(totalCurvePoints*sizeof(CustomPoint));
    
    
    self.earthTweens = [[NSMutableArray alloc] initWithCapacity:totalPoints];
    self.barTweens = [[NSMutableArray alloc] initWithCapacity:totalLinePoints];
    self.curveTweens = [[NSMutableArray alloc] initWithCapacity:totalCurvePoints];
    
    meshIndices = (GLuint*)malloc(totalIndices*sizeof(GLuint));
    
    touchEnded = NO;
    friction = 0.90;
    _duration = 1.0;
    delay=0.00001;
    velocity = GLKVector3Make(0,0,0);
    zoomscale = 1.0;
    
    radius = 1;
    resetCalled = NO;
    
    tweenFunction  =  [[TexImgTweenFunction alloc] init];
    
    _rotMatrix = GLKMatrix4Identity;
    
    UITapGestureRecognizer * dtRec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    dtRec.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:dtRec];
    
    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rotateWithPanGesture:)];
    [self.view addGestureRecognizer:self.panRecognizer];
    
    self.pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(zoomWithPinchGesture:)];
    [self.view addGestureRecognizer:self.pinchRecognizer];
    self.viewType = [self.viewTypeSegments selectedSegmentIndex];
    NSLog(@"%d", self.viewType);
    
    [self initData];
    [self setupGL];
}

//initial values
-(void) makePlane{
    self.viewType = WALL;
    for(int i=0; i< rows; i++)
        for( int j =0; j < cols; j++) { // fixed theta
            int index = i*cols+j;
            PNT_EarthPoint* location = [self.allLocations objectAtIndex:index];
            location.center = location.flatLoc;
            self.locations[index].positionCoords = location.center;
        }
    
}

/*
 This is dynamic part
 */

-(void) makeGlobe {
    self.viewType=GLOBE;
    //the first location is on the BL corner of the screen
    for(int i=0; i< rows; i++)
        for( int j =0; j < cols; j++) { // fixed theta
            int index = i*cols+j;
            PNT_EarthPoint* location = [self.allLocations objectAtIndex:index];
            location.center = location.roundLoc;
            self.locations[index].positionCoords = location.center;
        }
    
}


//This is static part//
-(void) initData{
    
    GLfloat s=0.0,t=0.0;
    GLfloat u=0.0,v=0.0;
    GLfloat y=0.0, x=0.0;
    GLKVector2 txtr;
    float spanTX = 1.0; //rect.size.width;//2.0;
    float offsetTX = 0.0;
    
    float spanTY = 1.0f;//rect.size.height;// 2.0;
    float offsetTY = 0.0f;
    GLfloat eachWidthT = spanTX/(cols-1);
    GLfloat eachHeightT = spanTY/(rows-1);
    
    
    UIImage *texImage = [UIImage imageNamed:@"earthbw.jpeg"];
    imageAspect = texImage.size.width/texImage.size.height;
    //    NSLog(@"%f", imageAspect);
    
    spanX = 2.0*imageAspect;
    offsetX = -1.0*imageAspect;
    
    spanY = 2.0f;
    offsetY = -1.0f;
    eachWidth = spanX/(cols-1);
    eachHeight = spanY/(rows-1);
    
    int index =0 ;
    float phi;
    float theta;
    float offsetTheta = GLKMathDegreesToRadians(180.0f) ;
    float offsetPhi = GLKMathDegreesToRadians(-180.0f);//azimuth
    
    GLfloat eachTheta = GLKMathDegreesToRadians(180.0f/(rows-1)); //180
    // 0 to 180, inclination from vertical axis, bottom row, inclination 180, top row inclination 0
    GLfloat eachPhi = GLKMathDegreesToRadians(360.0f/(cols-1)); // 0 to 360, azimuthal, 14. //360
    for(int i=0; i< rows; i++){ // fixed phi
        for( int j =0; j < cols; j++) { // fixed theta
            
            x = offsetX + j*eachWidth;
            y = offsetY + i*eachHeight;
            u = offsetTX + j*eachWidthT;
            v = offsetTY + i*eachHeightT;
            
            PNT_EarthPoint* location = [[PNT_EarthPoint alloc] init];
            location.flatLoc = GLKVector3Make(x,y,0);
            index = cols*i+j;
            
            phi = offsetPhi + eachPhi*j;
            theta = offsetTheta - eachTheta*i;
            
            location.theta = theta;
            location.phi = phi;
            location.row = i;
            location.col = j;
            
            TexImgTween* tween = [[TexImgTween alloc] init];
            tween.planeId = index;
            tween.targetPhi = phi;
            tween.targetTheta = theta;
            tween.duration = _duration;
            tween.delay = abs(cols/2-j)*delay;
            
            GLfloat x1 = radius*sin(location.theta)*cos(location.phi);
            GLfloat y1 = radius*sin(location.theta)*sin(location.phi);
            GLfloat z1 = radius*cos(location.theta);
            
            location.roundLoc = GLKVector3Make( y1, z1, x1 );
            
            tween.globeCenter = location.roundLoc;
            tween.wallCenter =  location.flatLoc;
            tween.duration = _duration;
            
            location.height = eachHeight;
            location.width = eachWidth;
            
            //texture
            s = u ;
            t = v ;
            txtr = GLKVector2Make(s, t); // BL (0,0)
            location.texCoord = txtr;
            
            int colorId = index+1;
            int red = colorId % 255;
			int green = colorId>= 255 ? (colorId/255)%255 : 0;
			int blue = colorId>=255*255 ? (colorId/255)/255 : 0;
			GLKVector4 colorV  = GLKVector4Make(red/255.0f, green/255.0f, blue/255.0f, 1);
            
            self.locations[index].textureCoords = location.texCoord;
            self.locations[index].colorCoords = colorV;
            
            [self.allLocations insertObject:location atIndex:index];
            [self.earthTweens insertObject:tween atIndex:index];
            
        }
        
    }
    int count=0;
    
    for(int r=0;r< rows-1 ;r++)
        for(int c=0; c< cols-1 ; c++)
        {
            
            int first = r*cols+c;
            int second = (r+1)*cols+c;
            count = (first-r)*6 ;
            //         NSLog(@"count %d, %d, %d ", first, (first-r)*6, count);
            //BL
            meshIndices[count] = first;
            //        NSLog(@"%d", meshIndices[count]);
            count++;
            meshIndices[count] = second;
            //        NSLog(@"%d", meshIndices[count]);
            count++;
            meshIndices[count] = first+1;
            //        NSLog(@"%d", meshIndices[count]);
            count++;
            meshIndices[count] = first+1;
            //        NSLog(@"%d", meshIndices[count]);
            count++;
            meshIndices[count] = second;
            //        NSLog(@"%d", meshIndices[count]);
            count++;
            meshIndices[count] = second+1;
            //        NSLog(@"%d", meshIndices[count]);
            
        }
    
    [self initBars];
    
    [self initCurves];
    
}

/***
 
 GLKVector4 UIcolor : RGB to HSV
 
 // Define a new brush color
 CGColorRef color = [UIColor colorWithHue:(CGFloat)[sender selectedSegmentIndex] / (CGFloat)kPaletteSize
 saturation:kSaturation
 brightness:kBrightness
 alpha:1.0].CGColor;
 const CGFloat *components = CGColorGetComponents(color);
 
 // Defer to the OpenGL view to set the brush color
 [(PaintingView *)self.view setBrushColorWithRed:components[0] green:components[1] blue:components[2]];
 
 ***/


-(GLKVector4)toRGBwithHue:(float)h saturation:(float)s value:(float)v alpha:(float)a {
    CGColorRef color = [UIColor colorWithHue:h saturation:s brightness:v alpha:1.0].CGColor;
    const CGFloat *components = CGColorGetComponents(color);
    GLKVector4 rgb = GLKVector4Make(components[0], components[1], components[2], 1.0);
    //    NSLog(@"Hue %f Red %f, Green %f, Blue %f", h, rgb.x, rgb.y, rgb.z);
    return rgb;
}


-(void) initCurves{
    
    //create the centre source of all curve
    PNT_EarthPoint* location0 = [[PNT_EarthPoint alloc] init];
    
    location0.theta  = GLKMathDegreesToRadians(_country[0].lat - 90);// 90 and 180 offset to match with earth view projection
    location0.phi = GLKMathDegreesToRadians(_country[0].lon -180 );
    location0.length = 0.0;
    
    GLfloat x1 = radius*sin(location0.theta)*cos(location0.phi);
    GLfloat y1 = radius*sin(location0.theta)*sin(location0.phi);
    GLfloat z1 = radius*cos(location0.theta);
    location0.roundLoc = GLKVector3Make( y1, z1, x1 );
    
    float xp = 1-(180.0-_country[0].lon)/180.0;
    float yp = 1-(90.0-_country[0].lat)/90.0;
    
    location0.flatLoc = GLKVector3Make(xp*imageAspect, yp, 0.0);
    
    //if globe mode
    if(self.viewType==GLOBE){
        location0.center = location0.roundLoc; // the end pointof the bezier curve
    }
    else {
        location0.center = location0.flatLoc; // the end point of the bezier curve
    }
    
    [self.allCurves insertObject:location0 atIndex:0];
    
    //now make the end points of all curves
    for(int i=1;i<totalCurves; i++){
        
        PNT_EarthPoint* location = [[PNT_EarthPoint alloc] init];
        
        location.theta  = GLKMathDegreesToRadians(_country[i].lat - 90);// 90 and 180 offset to match with earth view projection
        location.phi = GLKMathDegreesToRadians(_country[i].lon -180 );
        location.length = 0.0;
        
        GLfloat x1 = radius*sin(location.theta)*cos(location.phi);
        GLfloat y1 = radius*sin(location.theta)*sin(location.phi);
        GLfloat z1 = radius*cos(location.theta);
        location.roundLoc = GLKVector3Make( y1, z1, x1 );
        
        float xp = 1-(180.0-_country[i].lon)/180.0;
        float yp = 1-(90.0-_country[i].lat)/90.0;
        location.flatLoc = GLKVector3Make(xp*imageAspect, yp, 0.0);
        
        float L = 1.0;
        float S = 0.5;
        float hue =  120;
        GLKVector4 col = [self toRGBwithHue:hue saturation:S value:L alpha:1.0];
        
        //there will be a lot more tweens. For each curve, segment+1 number of tweens and points
        TexImgTween* tween = [[TexImgTween alloc] init];
        tween.planeId = i;
        tween.targetPhi = location.phi;
        tween.targetTheta = location.theta;
        tween.duration = _duration;
        tween.delay = (180.0f-fabs(_country[i].lat))*delay; //i*delay;
        tween.globeCenter = location.roundLoc;
        tween.wallCenter =  location.flatLoc;
        tween.duration = _duration;
        [self.barTweens insertObject:tween atIndex:i*2];
        
        //       NSLog(@"color: %f %f %f", col.x, col.y, col.z);
        
        //there will be a lot more curves
        self.curves[i*segmentsPerCurve].colorCoords = col;
        
        //if globe mode
        if(self.viewType==GLOBE){
            location.center = location.roundLoc; // the end pointof the bezier curve
            self.curves[i*segmentsPerCurve].positionCoords = location0.roundLoc; //the source point of the bezier curve
        } else {
            location.center = location.flatLoc; // the end point of the bezier curve
            self.curves[i*segmentsPerCurve].positionCoords = location0.flatLoc; // the source point of the bezier curve
        }
        
        [location createBezierStart:location0.center end:location.center view:self.viewType segments:segmentsPerCurve];
        
        for(int j =0; j<segmentsPerCurve; j++){
            self.curves[i*segmentsPerCurve+j].positionCoords = location.bezierPoints[j+4];
            self.curves[i*segmentsPerCurve+j].colorCoords = col;
        }
        
        //thse two are control points, now make the segments
        [self.allCurves insertObject:location atIndex:i+1];
        
    }
    
}


-(void) initBars{
    
    for(int i=0;i<totalBars; i++){
        
        PNT_EarthPoint* location = [[PNT_EarthPoint alloc] init];
        
        location.theta  = GLKMathDegreesToRadians(_population[i].lat - 90);// 90 and 180 offset to match with earth view projection
        location.phi = GLKMathDegreesToRadians(_population[i].lon -180 );
        location.length = _population[i].magnitude;
        
        GLfloat x1 = radius*sin(location.theta)*cos(location.phi);
        GLfloat y1 = radius*sin(location.theta)*sin(location.phi);
        GLfloat z1 = radius*cos(location.theta);
        location.roundLoc = GLKVector3Make( y1, z1, x1 );
        
        float xp = 1-(180.0-_population[i].lon)/180.0;
        float yp = 1-(90.0-_population[i].lat)/90.0;
        
        location.flatLoc = GLKVector3Make(xp*imageAspect, yp, 0.0);
        
        float L = 1.0;
        float S = 0.5;
        
        float hue =  (pow(M_E,location.length))*0.5;//240.0f+ 120.0f*(1-pow(M_E,location.length));
        
        GLKVector4 col = [self toRGBwithHue:hue saturation:S value:L alpha:1.0];
        
        GLKVector3 startP = location.roundLoc;
        GLKVector3 endP = GLKVector3Normalize(GLKVector3Subtract(location.roundLoc,GLKVector3Make(0,0,0)));
        endP = GLKVector3Add(GLKVector3MultiplyScalar(endP,location.length),startP);
        
        TexImgTween* tween = [[TexImgTween alloc] init];
        tween.planeId = i;
        tween.targetPhi = location.phi;
        tween.targetTheta = location.theta;
        tween.duration = _duration;
        tween.delay = (180.0f-fabs(_population[i].lat))*delay; //i*delay;
        tween.globeCenter = location.roundLoc;
        tween.wallCenter =  location.flatLoc;
        tween.duration = _duration;
        [self.barTweens insertObject:tween atIndex:i*2];
        
        TexImgTween* tween2 = [[TexImgTween alloc] init];
        tween2.planeId = i;
        tween2.targetPhi = location.phi;
        tween2.targetTheta = location.theta;
        tween2.duration = _duration;
        tween2.delay = tween.delay;
        tween2.globeCenter = endP;
        tween2.wallCenter =   GLKVector3Make(location.flatLoc.x, location.flatLoc.y, location.length);
        tween2.duration = _duration;
        [self.barTweens insertObject:tween2 atIndex:(i*2+1)];
        //       NSLog(@"color: %f %f %f", col.x, col.y, col.z);
        
        self.bars[i*2].colorCoords = col;
        self.bars[i*2+1].colorCoords = col;
        
        //if globe mode
        if(self.viewType==GLOBE){
            location.center = location.roundLoc;
            self.bars[i*2].positionCoords = location.roundLoc;
            self.bars[i*2+1].positionCoords = endP;
        }
        else {
            location.center = location.flatLoc;
            self.bars[i*2].positionCoords = location.flatLoc;
            self.bars[i*2+1].positionCoords = GLKVector3Make(location.flatLoc.x, location.flatLoc.y, location.length);
        }
        
        [self.allLines insertObject:location atIndex:i];
        
    }
    
    
    
}

-(IBAction) changeViewType:(id)sender {
    int i = [sender selectedSegmentIndex];
    if (i== GLOBE){
        [self changeView: GLOBE];
    }
    else if(i== WALL) {
        [self changeView: WALL];
    }
}

-(void) changeView:(ViewType)viewType{
    
    self.viewType = viewType;
    self.viewChanged=YES;
    //    NSLog(@"inside change view ");
    NSDate* currentTime = [NSDate date];
    
    for(int index=0; index<totalPoints; index++){
        TexImgTween* tween = [self.earthTweens objectAtIndex:index];
        tween.startTime = currentTime;
        //        NSLog(@"twn start time %@", tween.startTime);
        if(self.viewType==GLOBE){
            [tween setTargetCenter: tween.globeCenter];
            [tween setSourceCenter: tween.wallCenter];
        } else if(self.viewType==WALL){
            [tween setTargetCenter: tween.wallCenter];
            [tween setSourceCenter: tween.globeCenter];
        }
    }
    for(int index=0; index<totalBars*2; index++){
        TexImgTween* tween = [self.barTweens objectAtIndex:index];
        tween.startTime = currentTime;
        if(self.viewType==GLOBE){
            [tween setTargetCenter: tween.globeCenter];
            [tween setSourceCenter: tween.wallCenter];
        } else if(self.viewType==WALL){
            [tween setTargetCenter: tween.wallCenter];
            [tween setSourceCenter: tween.globeCenter];
        }
    }
}

-(void) setDuration:(float) val {
    _duration = val;
}



-(void)setupGL{
    
    /** All the local setup for the ViewController */
    self.shapes = [[NSMutableArray alloc] init];
    self.effect = [[GLKBaseEffect alloc] init];
    zTranslation = 5.0f;
    taps = 0;
    zoomscale = 1;
    modelTranslation = GLKVector3Make(0.0, 0.0, zTranslation);
    modelrotation = GLKVector3Make(0, 0, 0);
    currentRotation = GLKVector3Make(0, 0, 0);
    
    float aspect = fabsf(self.view.bounds.size.width/self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 1.0f, 100.0f);
    self.effect.transform.projectionMatrix = projectionMatrix;
    
    glEnable(GL_DEPTH_TEST);
    
    NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithBool:YES],
                              GLKTextureLoaderOriginBottomLeft,
                              nil];
    NSError * error;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"earthbw" ofType:@"jpeg"];
    info = [GLKTextureLoader textureWithContentsOfFile:path options:options error:&error];
    if (info == nil) {
        NSLog(@"Error loading file: %@", [error localizedDescription]);
    }
    self.effect.texture2d0.name = info.name;
    
    [self setUpEarth];
    
    [self setUpLines];
    
    [self setUpCurves];
}

-(void) setUpEarth{
    
    //[self makeGlobe];
    if(self.viewType==GLOBE) {
        [self makeGlobe];
    }else {
        [self makePlane];
    }
    //    toRotate = YES;
    
    GLK2DrawCall* drawObject = [[GLK2DrawCall alloc] init ];
    drawObject.mode = GL_TRIANGLES;
    
    drawObject.numOfVerticesToDraw = totalIndices;//because we are drawing by indices here, not by points
    drawObject.VAO = [[GLKVAObject alloc] init];
    
    [drawObject.VAO addVBOForAttribute:GLKVertexAttribPosition
                        filledWithData:self.locations //addres of the bytes to copy
                           numVertices:totalPoints
                           numOfFloats:3 //floats in GLKVector3
                                stride:sizeof(CustomPoint)
                                offset:(void *)offsetof(CustomPoint, positionCoords)];
    
    [drawObject.VAO addVBOForAttribute:GLKVertexAttribTexCoord0
                        filledWithData:self.locations //addres of the bytes to copy
                           numVertices:totalPoints
                           numOfFloats:2
                                stride:sizeof(CustomPoint)
                                offset:(void *)offsetof(CustomPoint, textureCoords) ];
    
    NSString *bufferType = [NSString stringWithFormat:@"%d",GLKVertexAttribPosition];
    locationVertexBuffer = [(GLK2BufferObject*)[drawObject.VAO.VBOs objectForKey:bufferType] glName];
    
    [drawObject.VAO addVBOForAttribute:GL_ELEMENT_ARRAY_BUFFER
                        filledWithData:meshIndices //addres of the bytes to copy
                           numVertices:totalIndices
                           numOfFloats:1
                                stride:sizeof(GLuint)
                                offset:NULL ];
    
    bufferType = [NSString stringWithFormat:@"%d",GL_ELEMENT_ARRAY_BUFFER];
    _planeIndicesBuffer = [(GLK2BufferObject*)[drawObject.VAO.VBOs objectForKey:bufferType] glName];
    [self.shapes addObject: drawObject];
    
}

-(void) setUpLines{
    
    GLK2DrawCall* drawObject = [[GLK2DrawCall alloc] init ];
    drawObject.mode = GL_LINES;
    
    drawObject.numOfVerticesToDraw = totalLinePoints;
    drawObject.VAO = [[GLKVAObject alloc] init];
    
    [drawObject.VAO addVBOForAttribute:GLKVertexAttribPosition
                        filledWithData:self.bars //addres of the bytes to copy
                           numVertices:drawObject.numOfVerticesToDraw
                           numOfFloats:3 //floats in GLKVector3
                                stride:sizeof(CustomPoint)
                                offset:(void *)offsetof(CustomPoint, positionCoords)];
    
    
    [drawObject.VAO addVBOForAttribute:GLKVertexAttribColor
                        filledWithData:self.bars //addres of the bytes to copy
                           numVertices:drawObject.numOfVerticesToDraw
                           numOfFloats:4
                                stride:sizeof(CustomPoint)
                                offset:(void *)offsetof(CustomPoint, colorCoords) ];
    
    [self.shapes addObject: drawObject];
    
}

-(void) setUpCurves{
    
    GLK2DrawCall* drawObject = [[GLK2DrawCall alloc] init ];
    drawObject.mode = GL_LINE_STRIP;
    
    drawObject.numOfVerticesToDraw = totalCurvePoints;
    drawObject.VAO = [[GLKVAObject alloc] init];
    
    [drawObject.VAO addVBOForAttribute:GLKVertexAttribPosition
                        filledWithData:self.curves //addres of the bytes to copy
                           numVertices:drawObject.numOfVerticesToDraw
                           numOfFloats:3 //floats in GLKVector3
                                stride:sizeof(CustomPoint)
                                offset:(void *)offsetof(CustomPoint, positionCoords)];
    
    
    [drawObject.VAO addVBOForAttribute:GLKVertexAttribColor
                        filledWithData:self.curves //addres of the bytes to copy
                           numVertices:drawObject.numOfVerticesToDraw
                           numOfFloats:4
                                stride:sizeof(CustomPoint)
                                offset:(void *)offsetof(CustomPoint, colorCoords) ];
    
    [self.shapes addObject: drawObject];
    
    
}

-(void) setDelay:(float) val {
    
    delay = val;
}

-(void) resetView{
    
    resetCalled = YES;
    zTranslation = 4.0;
    _rotMatrix = GLKMatrix4Identity;
    velocity = GLKVector3Make(0, 0, 0);
    touchEnded = YES;
    
}

-(void) animateView{
    if(self.viewChanged==NO){
        return;
    }
    
    NSTimeInterval timeElapsedSinceLastUpdate = [self timeSinceLastUpdate];
    NSTimeInterval durationRemaining;
    
    //    NSLog(@"inside animation");
    for(int index =0; index < totalPoints; index++){
        PNT_EarthPoint* location = [self.allLocations objectAtIndex:index];
        TexImgTween* tween = [self.earthTweens objectAtIndex:index];
        float timePassedSinceStart = -[tween.startTime timeIntervalSinceNow];
        durationRemaining = tween.duration - timePassedSinceStart;
        float ratio =  timeElapsedSinceLastUpdate/timePassedSinceStart;
        ratio = [tweenFunction calculateTweenWithTime: timePassedSinceStart-tween.delay duration: tween.duration];
        
        if(timePassedSinceStart > tween.delay){
            BOOL isUpdated = [location updateVertex:tween.targetCenter
                                               mode:self.viewType
                                        timeElapsed: timePassedSinceStart-tween.delay
                                           duration: _duration //durationRemaining
                                              ratio:ratio];
            if(isUpdated==NO){
                toRotate = YES;
            }else {
                toRotate=NO;
            }
        }
        self.locations[index].positionCoords = location.center;
    }
    
    
    for(int index =0; index < totalBars; index++){
        PNT_EarthPoint* location = [self.allLines objectAtIndex:index];
        TexImgTween* tween = [self.barTweens objectAtIndex:index];
        float timePassedSinceStart = -[tween.startTime timeIntervalSinceNow];
        durationRemaining = _duration - timePassedSinceStart;
        float ratio =  timeElapsedSinceLastUpdate/timePassedSinceStart;
        ratio = [tweenFunction calculateTweenWithTime: timePassedSinceStart-tween.delay duration:_duration];
        
        if(timePassedSinceStart > tween.delay){
            BOOL isUpdated = [location updateVertex:tween.targetCenter
                                               mode:self.viewType
                                        timeElapsed: timePassedSinceStart-tween.delay
                                           duration: _duration
                                              ratio:ratio];
            if(isUpdated==NO){
                toRotate = YES;
            }else {
                toRotate=NO;
            }
        }
        self.bars[index*2].positionCoords = location.center;
        
        if(self.viewType==GLOBE){
            GLKVector3 startP = location.center;
            GLKVector3 endP = GLKVector3Normalize(GLKVector3Subtract(location.center,GLKVector3Make(0,0,0)));
            endP = GLKVector3Add(GLKVector3MultiplyScalar(endP,location.length),startP);
            self.bars[index*2+1].positionCoords = endP;
            
        } else if(self.viewType==WALL){
            self.bars[index*2+1].positionCoords = GLKVector3Make(location.center.x, location.center.y, location.length);
        }
        
    }
}


/*called after update loop
 */

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    
    glClearColor(0.1, 0.1, 0.1, 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.001f, 100.0f);
    self.effect.transform.projectionMatrix = projectionMatrix;
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -modelTranslation.z);
	GLKMatrix4 rotymatrix   = GLKMatrix4MakeYRotation(modelrotation.y);
	GLKMatrix4 rotxmatrix  = GLKMatrix4MakeXRotation(modelrotation.x);
	GLKMatrix4 modelViewMatrix = rotxmatrix;
	modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, rotymatrix);
	modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    self.effect.transform.modelviewMatrix = modelViewMatrix;
    
    
    
    if( [EAGLContext currentContext] == nil ) // skip until we have a context
    {
		NSLog(@"We have no gl context; skipping all frame rendering");
		return;
	}
    
    
    [self renderEarth];
    
    //    [self renderBars];
    
    [self renderCurves];
}


-(void) update {
    
    if(self.viewChanged) {
        toRotate=NO;
        [self animateView];// changes the points
        
        //update earth
        //TODO: use function calls from drawcall object rathert han using directly
        glBindBuffer(GL_ARRAY_BUFFER, locationVertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(CustomPoint)*totalPoints, self.locations, GL_DYNAMIC_DRAW);
        
        //update lines if needed
        GLK2DrawCall* drawObject = [self.shapes objectAtIndex:1];
        [drawObject.VAO updateVBOForAttribute:GLKVertexAttribPosition
                               filledWithData:self.bars //addres of the bytes to copy
                                  numVertices:drawObject.numOfVerticesToDraw
                                  numOfFloats:3 //floats in GLKVector3
                                       stride:sizeof(CustomPoint)
                                       offset:(void *)offsetof(CustomPoint, positionCoords)];
        
    }
    
    //    if(self.viewType==GLOBE && toRotate==YES)
    //        modelrotation.y -= 0.2;
    
}

-(void) renderCurves{
    
    if( self.shapes == nil || self.shapes.count < 1 ){
		NSLog(@"no drawcalls specified; rendering nothing");
        return;
    }
    
    //for( GLK2DrawCall* drawCall in self.shapes )
    GLK2DrawCall* drawCall = [self.shapes objectAtIndex:2];
    {
        if( drawCall.VAO != nil ){
            self.effect.texture2d0.enabled = NO;
            [self.effect prepareToDraw];
            glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
            glEnableVertexAttribArray(GLKVertexAttribColor);
            glEnable(GL_BLEND);
            glEnable(GL_LINE_SMOOTH);
            glLineWidth(1.0f);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            
            
            glBindVertexArrayOES( drawCall.VAO.glName );
            for(int i = 0; i < totalCurves; i++){
                glDrawArrays(GL_LINE_STRIP, i*(segmentsPerCurve), segmentsPerCurve+1);
                
            }
            glDisable(GL_LINE_SMOOTH);
            
        }
        else {
            NSLog(@"not available");
        }
    }
    
    
    
    
}


-(void) renderEarth {
    
    if( self.shapes == nil || self.shapes.count < 1 ){
		NSLog(@"no drawcalls specified; rendering nothing");
        return;
    }
    
    GLK2DrawCall* drawCall = [self.shapes objectAtIndex:0];
    
    {
        if( drawCall.VAO != nil ){
            self.effect.texture2d0.enabled = YES;
            //            glDisableVertexAttribArray(GLKVertexAttribColor);
            [self.effect prepareToDraw];
            [drawCall drawWithElements:GL_TRIANGLES];
        }
        else {
            NSLog(@"not available");
        }
    }
    glBindVertexArrayOES(0);
}

-(void) renderBars{
    
    //    glBindVertexArrayOES(0);
    
    if( self.shapes == nil || self.shapes.count < 1 ){
		NSLog(@"no drawcalls specified; rendering nothing");
        return;
    }
    
    //for( GLK2DrawCall* drawCall in self.shapes )
    GLK2DrawCall* drawCall = [self.shapes objectAtIndex:1];
    {
        if( drawCall.VAO != nil ){
            self.effect.texture2d0.enabled = NO;
            [self.effect prepareToDraw];
            glEnableVertexAttribArray(GLKVertexAttribColor);
            [drawCall drawWithMode:GL_LINES];
        }
        else {
            NSLog(@"not available");
        }
    }
    
    
}


-(void) zoomWithPinchGesture:(UIPinchGestureRecognizer*) sender{
    
    GLfloat scale;
	
    if (sender.state==UIGestureRecognizerStateBegan) {
		
	}
	else if (sender.state==UIGestureRecognizerStateChanged) {
		scale = zoomscale * sender.scale;
		if (scale>4.0) scale = 4.0;
		else if (scale<0.25) scale = 0.25;
		modelTranslation.z = zTranslation / scale;
	}
	else if (sender.state==UIGestureRecognizerStateEnded){
		zoomscale *= sender.scale;
		if (zoomscale<0.25) zoomscale = 0.25;
		else if (zoomscale>4) zoomscale = 4;
	}
    
    
}


-(void) rotateWithPanGesture:(UIPanGestureRecognizer*) recognizer {
    
    CGPoint velo = [recognizer velocityInView:self.view];
    CGPoint diff = [recognizer translationInView:self.view];
    
    if( [recognizer numberOfTouches]==1){
        
        if (recognizer.state==UIGestureRecognizerStateBegan) {
            touchEnded = NO;
            velocity.x = 0;
            velocity.y = 0;
            
            currentRotation.x = modelrotation.x;
            currentRotation.y = modelrotation.y;
            
        } else if (recognizer.state==UIGestureRecognizerStateChanged) {
            
            if(touchEnded)
                return;
            modelrotation.x =  currentRotation.x+ (diff.y * 0.01);
            modelrotation.y =  currentRotation.y+ (diff.x * 0.01);
        }
        else if (recognizer.state==UIGestureRecognizerStateEnded) {
            touchEnded = YES;
        }
    }else if (recognizer.state==UIGestureRecognizerStateEnded)  {
        velocity.x = velo.y*0.0025;
        velocity.y = velo.x*0.0025;
        //        NSLog(@"Touch ended ");
        touchEnded = YES;
        
    }
    
}



- (void)doubleTap:(UITapGestureRecognizer *)tap {
    
    self.viewChanged = YES;
    [self resetView];
    
}

static const LatLonBar _country[] = { { 38, -97 }, { 60, -95 }, { 23, -102 }, { -10, -55 }, { 54, -2 }, { 40, -4}, { 46, 2 }, { 20, 77 }, { 35, 105 }, { 60, 100 }, { 36, 138 } };

static const LatLonBar _population[] = {
    6,159,0.001,
    30,99,0.002,
    45,-109,0.001,
    42,115,0.006,
    4,-54,0.000,
    -16,-67,0.018,
    21,-103,0.006,
    -20,-64,0.004,
    -40,-69,0.001,
    32,64,0.001,
    28,67,0.008,
    8,22,0.000,
    -15,133,0.000,
    -16,20,0.000,
    55,42,0.006,
    32,-81,0.011,
    31,36,0.098,
    9,80,0.013,
    42,-91,0.007,
    19,54,0.001,
    21,111,0.186,
    -3,-51,0.001,
    33,119,0.164,
    65,21,0.001,
    46,49,0.010,
    43,77,0.041,
    45,130,0.018,
    4,119,0.007,
    22,59,0.003,
    9,-82,0.003,
    46,-60,0.002,
    -14,15,0.008,
    -15,-76,0.001,
    57,15,0.007,
    52,9,0.060,
    10,120,0.005,24,87,0.168,0,-51,0.008,-5,123,0.018,-24,-53,0.009,-28,-58,0.018,43,0,0.019,24,70,0.029,-9,33,0.016,20,73,0.046,13,104,0.046,43,41,0.009,23,78,0.115,20,-72,0.001,38,-4,0.006,0,-77,0.020,-9,-35,0.062,25,109,0.036,-13,34,0.018,61,18,0.001,58,40,0.002,34,50,0.030,49,88,0.000,48,-99,0.001,-42,176,0.002,20,86,0.178,-18,30,0.009,53,44,0.006,29,18,0.001,5,16,0.004,49,-74,0.000,48,131,0.006,14,121,0.272,63,19,0.001,40,54,0.001,36,57,0.005,16,52,0.000,50,128,0.010,39,30,0.026,54,12,0.007,16,-61,0.012,27,80,0.237,29,101,0.002,14,78,0.075,7,13,0.003,41,125,0.025,-17,23,0.002,54,27,0.009,30,29,0.001,41,142,0.003,12,124,0.029,41,43,0.013,18,98,0.004,36,117,0.203,17,33,0.004,32,109,0.047,-7,23,0.015,27,-101,0.005,45,-73,0.128,21,-83,0.000,55,-131,0.001,52,105,0.024,-40,-65,0.000,32,36,0.132,31,7,0.001,32,-109,0.001,31,120,0.209,9,124,0.046,46,-2,0.001,-2,-50,0.003,18,-13,0.001,42,28,0.015,4,99,0.009,19,-77,0.003,18,38,0.008,33,4,0.006,-5,-75,0.000,-14,51,0.001,-15,-48,0.002,57,-5,0.000,52,37,0.017,13,38,0.017,-10,-41,0.002,-11,36,0.008,-18,-71,0.004,-20,27,0.002,56,89,0.001,33,-94,0.007,44,15,0.001,43,-4,0.006,20,37,0.000,-4,27,0.009,47,8,0.078,44,-98,0.001,23,114,0.481,38,24,0.061,14,10,0.008,10,-3,0.010,47,89,0.002,-34,152,0.087,38,-121,0.073,14,25,0.002,29,5,0.001,-9,-78,0.019,20,98,0.021,-19,-39,0.004,53,0,0.048,-23,150,0.000,49,1,0.029,48,40,0.044,38,97,0.001,35,-99,0.001,16,1,0.004,53,-115,0.000,48,119,0.001,29,-85,0.000,63,39,0.001,40,26,0.002,16,40,0.002,11,120,0.002,-8,14,0.003,26,-98,0.024,-12,-47,0.001,-32,28,0.011,40,-87,0.006,36,-76,0.040,17,82,0.057,50,19,0.091,12,-70,0.002,27,108,0.078,7,49,0.003,41,105,0.000,3,46,0.006,-16,168,0.001,-21,56,0.005,51,83,0.002,50,-122,0.000,30,9,0.001,7,-62,0.002,41,-6,0.004,-17,-52,0.001,-38,-58,0.003,-6,13,0.020,45,6,0.050,60,59,0.000,41,-121,0.000,17,-3,0.001,-6,-64,0.000,-7,35,0.003,-26,-61,0.001,41,-104,0.003,51,30,0.004,32,-8,0.046,27,40,0.002,4,33,0.003,21,98,0.010,-1,122,0.002,32,-89,0.006,31,92,0.001,46,42,0.008,8,-83,0.003,22,36,0.000,19,30,0.001,-10,-64,0.003,-2,22,0.002,-5,40,0.040,69,20,0.001,37,35,0.025,-2,133,0.002,10,93,0.001,-10,36,0.010,-14,-41,0.006,-34,22,0.001,56,46,0.003,37,-108,0.001,52,49,0.003,13,10,0.022,46,91,0.001,-11,24,0.003,-34,-59,0.006,56,93,0.025,-38,-60,0.002,-30,-57,0.004,47,27,0.037,44,11,0.058,-33,-65,0.002,19,106,0.128,-23,-45,0.034,-24,34,0.001,58,45,0.001,20,-96,0.004,35,78,0.002,-38,150,0.000,34,39,0.005,15,27,0.001,10,33,0.003,47,109,0.000,-9,118,0.013,38,-93,0.005,34,-6,0.051,15,-84,0.001,49,16,0.022,25,38,0.002,2,39,0.001,1,28,0.005,16,102,0.028,6,122,0.010,68,65,0.000,49,-99,0.002,48,76,0.000,26,96,0.009,40,111,0.045,2,-70,0.000,38,125,0.004,16,-11,0.004,50,85,0.001,12,-8,0.042,63,75,0.001,-31,28,0.012,-20,-49,0.004,40,-2,0.002,36,1,0.016,35,26,0.010,-31,-55,0.005,6,-67,0.001,3,9,0.004,40,-115,0.001,39,102,0.000,54,68,0.002,50,55,0.001,30,54,0.005,26,49,0.002,60,-135,0.001,6,48,0.004,3,26,0.003,51,111,0.001,12,101,0.007,45,25,0.024,-3,13,0.002,-7,-46,0.002,30,88,0.001,-27,27,0.016,42,144,0.007,60,23,0.012,32,101,0.002,31,-114,0.004,28,40,0.002,8,-13,0.030,-30,-66,0.003,55,69,0.002,51,74,0.001,-3,115,0.015,31,63,0.001,28,-105,0.008,27,68,0.059,42,-78,0.035,22,-83,0.021,21,86,0.064,-1,14,0.001,-2,-57,0.000,-5,-45,0.007,32,-117,0.063,43,120,0.010,45,93,0.000,55,103,0.001,-2,34,0.015,-25,25,0.001,57,70,0.000,37,55,0.013,33,60,0.004,28,100,0.004,9,34,0.005,-9,24,0.003,-4,120,0.047,22,122,0.002,37,-88,0.008,8,101,0.012,46,119,0.001,43,-93,0.005,-11,124,0.017,0,41,0.005,-23,34,0.001,-5,143,0.003,47,47,0.001,43,52,0.006,24,-110,0.003,23,73,0.233,1,105,0.026,-4,-45,0.011,11,35,0.006,14,45,0.072,25,84,0.322,-13,21,0.001,58,17,0.007,37,123,0.051,34,75,0.093,-4,130,0.003,11,-12,0.024,48,-118,0.001,10,21,0.001,5,-58,0.001,1,-57,0.000,53,71,0.002,49,76,0.001,29,45,0.002,14,18,0.001,25,50,0.002,2,11,0.007,-18,-46,0.003,-19,33,0.019,49,-103,0.001,-8,-72,0.001,-12,-69,0.001,25,-97,0.023,40,83,0.002,39,-88,0.009,50,121,0.001,12,20,0.002,-7,114,0.027,14,107,0.004,-37,149,0.001,62,130,0.003,59,36,0.001,39,57,0.001,36,-99,0.001,35,54,0.006,30,-89,0.015,-8,-42,0.003,7,40,0.047,-17,34,0.010,54,32,0.015,-4,-50,0.001,30,66,0.001,26,69,0.078,7,-7,0.023,-20,34,0.019,-3,-60,0.037,-19,-44,0.004,-26,25,0.002,-27,-54,0.008,21,75,0.087,30,100,0.002,42,116,0.005,4,-53,0.000,-16,-66,0.001,21,-100,0.016,-20,-63,0.001,-40,-68,0.002,32,73,0.094,28,68,0.018,-16,13,0.001,-5,-41,0.006,55,41,0.007,32,-80,0.014,31,35,0.103,9,79,0.135,42,-90,0.007,19,53,0.002,-2,-45,0.004,65,24,0.000,46,50,0.001,43,84,0.008,45,129,0.024,4,120,0.003,22,60,0.004,9,-83,0.028,46,-63,0.003,-14,16,0.016,52,10,0.064,24,88,0.204,0,-50,0.004,34,126,0.001,-5,122,0.008,-24,-52,0.016,-28,-57,0.002,43,-1,0.024,24,71,0.014,58,83,0.002,20,74,0.125,-1,11,0.001,13,103,0.031,43,16,0.004,23,77,0.080,38,-7,0.009,0,-76,0.008,47,100,0.000,25,112,0.073,-13,33,0.006,61,17,0.003,58,37,0.002,34,47,0.028,49,87,0.001,48,-98,0.001,20,87,0.188,-33,-56,0.002,-18,35,0.006,53,43,0.005,29,17,0.001,5,15,0.003,48,132,0.001,-19,178,0.001,63,18,0.001,36,58,0.010,16,45,0.017,50,125,0.001,39,29,0.033,54,9,0.005,-55,-66,0.001,27,79,0.311,29,104,0.111,41,128,0.013,-17,22,0.000,54,28,0.009,53,95,0.000,30,30,0.021,41,141,0.016,-21,-53,0.000,64,29,0.001,41,30,0.111,18,95,0.015,36,118,0.278,17,36,0.003,32,110,0.040,-7,26,0.006,27,-102,0.000,45,-78,0.000,41,-69,0.001,21,-80,0.001,52,106,0.001,31,6,0.001,-16,49,0.009,32,-108,0.001,31,119,0.238,9,123,0.026,46,3,0.009,18,-12,0.001,6,-8,0.025,66,15,0.001,6,117,0.013,42,25,0.031,18,35,0.001,33,3,0.004,14,40,0.035,-15,-49,0.004,22,103,0.012,52,38,0.007,13,37,0.006,47,-91,0.001,-10,-40,0.014,-11,35,0.011,56,90,0.002,33,-95,0.005,44,16,0.011,43,-5,0.031,58,103,0.004,-4,28,0.006,-10,161,0.002,47,7,0.029,44,-97,0.002,-13,-44,0.003,23,113,0.154,38,21,0.003,14,-1,0.006,10,-2,0.016,47,88,0.003,38,-120,0.007,6,39,0.113,14,26,0.001,29,8,0.001,-9,-79,0.019,20,99,0.004,53,-1,0.157,49,4,0.023,48,17,0.082,40,140,0.001,38,98,0.001,35,-92,0.006,16,2,0.001,53,-112,0.002,12,-3,0.016,48,120,0.002,29,-90,0.031,40,27,0.012,16,17,0.000,-8,15,0.007,-12,-46,0.001,40,-86,0.017,39,129,0.001,17,81,0.079,50,20,0.092,12,-69,0.003,27,107,0.114,7,48,0.004,41,108,0.017,3,45,0.006,51,82,0.009,50,-125,0.001,-15,50,0.012,30,10,0.001,7,-63,0.006,41,-7,0.015,-17,-53,0.001,-6,14,0.032,30,121,0.338,23,96,0.024,45,5,0.086,60,60,0.002,-4,-41,0.010,17,0,0.001,-6,-67,0.000,28,13,0.001,-26,-60,0.001,41,-105,0.001,-8,132,0.002,51,29,0.006,32,1,0.001,27,39,0.002,4,34,0.003,21,97,0.050,-1,121,0.004,-3,-42,0.003,32,-88,0.005,46,31,0.054,8,-82,0.016,19,29,0.001,-2,27,0.003,-5,39,0.029,69,19,0.001,57,105,0.000,37,30,0.021,-2,134,0.002,-10,33,0.009,-14,-40,0.008,-34,27,0.005,56,47,0.004,52,50,0.005,13,9,0.042,47,-55,0.001,9,6,0.017,46,92,0.000,-11,23,0.003,-14,-57,0.001,-4,134,0.001,-34,-58,0.004,56,94,0.004,-38,-63,0.001,47,26,0.016,44,12,0.057,19,105,0.010,-8,142,0.001,-24,35,0.003,58,46,0.002,38,49,0.034,35,77,0.011,37,98,0.001,34,40,0.006,15,26,0.001,10,34,0.004,47,124,0.051,-33,30,0.001,38,-92,0.010,-8,139,0.000,15,-85,0.006,49,15,0.024,2,40,0.002,1,27,0.001,16,103,0.065,-22,34,0.002,49,-96,0.003,26,93,0.155,25,-106,0.001,40,112,0.050,2,-73,0.001,1,12,0.004,38,126,0.132,16,-10,0.002,50,86,0.000,12,-7,0.016,-31,27,0.002,40,-1,0.003,36,2,0.034,35,25,0.007,-7,150,0.001,-31,-52,0.005,6,-66,0.001,45,-120,0.000,39,101,0.017,54,65,0.002,50,56,0.001,30,59,0.005,26,50,0.002,6,45,0.002,3,25,0.002,17,-66,0.004,-21,19,0.001,51,110,0.001,12,102,0.023,45,28,0.033,-25,-64,0.005,-3,16,0.001,-7,-47,0.004,45,-87,0.004,42,141,0.009,60,24,0.005,-29,-67,0.001,17,-4,0.001,32,102,0.002,31,-115,0.013,28,41,0.002,8,-12,0.029,55,68,0.002,51,73,0.001,31,62,0.007,28,-104,0.001,27,67,0.006,42,-81,0.013,4,-2,0.003,22,-82,0.025,21,85,0.055,-1,13,0.001,-39,-62,0.009,-2,-56,0.001,-5,-46,0.004,32,-116,0.055,46,75,0.003,43,119,0.009,55,102,0.001,-8,-76,0.004,-25,24,0.002,5,9,0.036,57,69,0.000,37,66,0.006,33,59,0.002,28,101,0.003,9,33,0.006,-15,39,0.008,37,-89,0.009,46,120,0.001,43,-94,0.003,-11,123,0.001,0,42,0.002,-23,33,0.001,-5,142,0.002,47,46,0.001,23,72,0.036,-4,-44,0.012,11,34,0.006,-9,-41,0.002,25,83,0.377,-13,28,0.013,58,18,0.002,35,121,0.006,37,118,0.165,34,76,0.020,-4,131,0.002,49,94,0.000,11,-13,0.008,48,-117,0.002,10,22,0.001,-32,153,0.004,53,50,0.025,49,75,0.001,29,48,0.026,5,122,0.007,25,49,0.002,-2,105,0.004,2,12,0.006,-19,36,0.004,68,30,0.000,49,-100,0.001,48,105,0.001,26,129,0.002,-12,-68,0.001,40,84,0.002,39,-89,0.011,36,15,0.011,50,122,0.003,12,21,0.003,-7,113,0.030,18,123,0.003,59,35,0.001,39,56,0.001,36,-98,0.001,35,53,0.010,30,-88,0.021,-8,-41,0.006,7,39,0.087,-17,33,0.007,54,29,0.018,-55,-68,0.001,30,23,0.000,26,70,0.037,7,-8,0.022,6,73,0.000,22,98,0.014,-3,-61,0.001,-26,26,0.018,-27,-55,0.009,45,64,0.000,60,5,0.001,41,65,0.003,21,70,0.025,30,97,0.001,42,113,0.002,4,-52,0.003,-16,-65,0.001,21,-101,0.052,-20,-62,0.000,-41,-62,0.000,32,74,0.179,28,69,0.058,8,24,0.001,-16,14,0.004,55,40,0.013,31,34,0.004,-15,26,0.002,21,121,0.001,33,121,0.112,-6,151,0.002,65,23,0.001,43,83,0.009,45,132,0.032,22,57,0.002,6,2,0.091,9,-80,0.001,46,-62,0.001,-14,13,0.002,-15,-74,0.002,57,17,0.003,52,11,0.052,-43,172,0.001,24,81,0.072,-5,121,0.029,-24,-59,0.000,-28,-56,0.004,43,-2,0.042,24,72,0.047,58,84,0.000,20,75,0.111,-28,23,0.001,23,108,0.064,38,-6,0.013,14,-92,0.018,47,99,0.000,25,111,0.081,58,38,0.002,-46,169,0.001,34,48,0.039,49,90,0.001,48,-97,0.001,-18,36,0.013,53,38,0.009,44,113,0.000,5,26,0.001,48,125,0.020,63,17,0.001,40,56,0.000,36,59,0.016,35,8,0.021,16,46,0.003,50,126,0.005,39,28,0.037,54,10,0.029,27,78,0.233,29,103,0.032,41,127,0.037,-17,21,0.000,54,25,0.012,53,106,0.001,30,35,0.007,6,37,0.019,64,30,0.000,41,29,0.206,18,96,0.067,36,119,0.193,17,35,0.004,32,111,0.059,-7,25,0.018,45,-79,0.002,41,-82,0.016,52,107,0.001,51,24,0.016,31,5,0.001,-13,-43,0.003,-16,50,0.008,55,12,0.015,32,-115,0.014,31,118,0.203,46,4,0.013,42,-121,0.002,18,-15,0.015,-6,123,0.014,66,16,0.000,-44,-74,0.000,42,26,0.023,18,36,0.001,-1,-74,0.000,33,6,0.003,-5,-69,0.001,-14,49,0.007,-15,-46,0.002,22,104,0.023,37,-6,0.027,52,39,0.010,13,40,0.036,-10,-43,0.002,24,117,0.091,-33,118,0.000,56,91,0.008,33,-92,0.004,44,17,0.022,43,-6,0.005,-4,29,0.025,47,6,0.020,44,-96,0.002,-13,-45,0.002,23,112,0.078,38,22,0.016,35,104,0.071,14,0,0.007,10,11,0.026,47,87,0.002,38,-123,0.001,49,118,0.007,29,7,0.001,20,100,0.017,53,10,0.062,49,3,0.057,48,18,0.050,44,77,0.003,38,103,0.024,35,-93,0.005,53,-113,0.031,12,-2,0.031,29,-91,0.004,14,110,0.017,40,28,0.013,-20,-44,0.071,-8,16,0.007,7,94,0.001,40,-85,0.018,39,128,0.056,17,84,0.073,16,-95,0.012,50,17,0.037,12,-68,0.006,27,106,0.103,7,47,0.003,41,107,0.002,51,81,0.002,30,-1,0.001,7,-64,0.002,41,-4,0.020,-17,-54,0.006,-6,27,0.008,-35,-57,0.011,30,122,0.149,45,8,0.069,60,61,0.001,41,-119,0.000,-35,150,0.001,17,-1,0.001,-6,-66,0.001,-26,-63,0.001,8,9,0.032,41,-102,0.000,51,36,0.009,32,2,0.001,28,-3,0.000,27,38,0.003,4,35,0.002,22,-105,0.007,21,100,0.009,-1,120,0.018,46,32,0.010,8,-81,0.007,19,36,0.001,-2,28,0.003,-5,38,0.007,-10,151,0.001,22,-15,0.000,37,29,0.028,-2,139,0.000,-8,-62,0.000,10,107,0.361,-10,34,0.031,-2,12,0.001,-34,28,0.009,56,48,0.033,52,51,0.002,-12,-67,0.000,13,12,0.007,9,5,0.007,46,89,0.001,-14,-56,0.001,-34,-53,0.002,56,95,0.001,-38,-62,0.001,47,25,0.016,19,96,0.040,34,-106,0.004,-36,-61,0.003,-23,-59,0.001,-24,36,0.017,44,-100,0.001,58,59,0.001,37,97,0.001,34,37,0.041,15,25,0.001,10,31,0.009,47,123,0.014,5,-76,0.011,-33,29,0.017,38,-95,0.007,15,-86,0.015,49,18,0.041,25,40,0.004,2,37,0.001,1,30,0.012,16,104,0.064,-22,31,0.004,49,-97,0.024,26,94,0.067,25,-107,0.008,40,105,0.000,2,-72,0.001,1,11,0.004,-18,-69,0.001,16,-9,0.002,50,83,0.006,12,-6,0.012,-31,30,0.024,40,0,0.005,36,3,0.043,29,122,0.142,-31,-53,0.003,6,-61,0.001,39,100,0.009,54,66,0.002,50,53,0.001,30,60,0.004,26,47,0.004,6,46,0.003,3,16,0.002,17,-67,0.001,-21,18,0.000,51,109,0.003,12,103,0.021,45,27,0.022,22,84,0.054,-3,15,0.001,-7,-44,0.002,45,-84,0.003,42,142,0.029,60,25,0.031,32,103,0.003,31,-100,0.004,28,42,0.001,-30,-68,0.000,55,67,0.002,51,64,0.001,-3,109,0.002,31,61,0.001,9,101,0.001,27,66,0.002,42,-80,0.011,4,-1,0.008,21,88,0.114,-1,28,0.002,-39,-63,0.000,-5,-47,0.004,46,76,0.001,43,118,0.005,-48,-67,0.000,55,101,0.001,-10,-63,0.005,46,-101,0.000,57,72,0.001,37,65,0.005,33,62,0.002,28,102,0.010,9,36,0.027,37,-78,0.005,-4,-73,0.008,13,-16,0.037,43,-95,0.003,24,29,0.000,0,43,0.006,-23,36,0.004,-5,141,0.002,13,125,0.009,47,45,0.001,23,71,0.014,15,108,0.007,11,33,0.004,-43,-74,0.001,-9,-42,0.002,25,102,0.042,-13,27,0.003,58,15,0.004,35,112,0.109,37,117,0.171,34,73,0.153,-4,132,0.000,49,93,0.000,11,-14,0.010,48,-116,0.002,-9,113,0.103,5,-56,0.001,1,-55,0.000,53,49,0.008,49,46,0.003,29,47,0.010,25,52,0.019,-19,35,0.004,68,31,0.000,49,-101,0.000,48,106,0.000,40,77,0.003,39,-90,0.005,36,16,0.003,50,119,0.003,12,22,0.004,-7,116,0.003,11,93,0.001,-12,44,0.013,59,34,0.003,39,55,0.004,36,-97,0.006,35,60,0.016,30,-91,0.022,-8,-40,0.010,7,38,0.103,8,99,0.017,54,30,0.005,30,24,0.001,7,-9,0.008,6,74,0.001,17,-71,0.001,-3,-66,0.001,-26,31,0.006,-27,-52,0.013,45,63,0.001,60,6,0.012,41,68,0.002,17,74,0.072,-6,-45,0.004,30,98,0.002,45,-112,0.001,42,114,0.004,-16,-64,0.001,21,-106,0.001,54,79,0.001,32,75,0.262,28,70,0.059,8,17,0.012,-16,15,0.006,55,39,0.056,6,118,0.003,31,33,0.026,9,81,0.023,42,-108,0.000,-2,-47,0.016,-6,152,0.004,5,37,0.009,65,26,0.003,43,82,0.012,45,131,0.047,-4,152,0.001,22,58,0.005,-35,119,0.000,46,-73,0.005,-11,-68,0.005,-14,14,0.007,-15,-75,0.010,0,105,0.005,52,12,0.024,28,130,0.003,24,82,0.099,-24,-58,0.000,-28,-55,0.024,43,-3,0.024,20,76,0.097,-24,-43,0.022,-28,24,0.004,43,14,0.032,23,107,0.044,38,-1,0.017,-25,-68,0.002,14,50,0.004,25,114,0.058,-18,146,0.002,34,45,0.015,49,89,0.000,48,-96,0.001,-18,33,0.013,53,37,0.007,29,19,0.001,44,114,0.000,5,25,0.000,48,126,0.030,63,16,0.001,40,49,0.016,39,10,0.018,36,60,0.043,35,7,0.027,16,47,0.002,39,27,0.015,27,77,0.140,29,98,0.001,41,130,0.027,54,26,0.028,53,105,0.001,-35,-70,0.016,30,36,0.009,6,38,0.060,-25,-55,0.005,-19,-49,0.008,64,31,0.001,41,32,0.015,-29,-58,0.003,36,120,0.186,17,38,0.005,32,112,0.095,-7,28,0.004,45,-76,0.004,41,-83,0.032,52,108,0.001,51,23,0.035,5,27,0.001,-16,51,0.005,55,11,0.015,51,8,0.205,32,-114,0.009,31,117,0.123,46,1,0.015,18,-14,0.001,-8,-69,0.000,-6,124,0.004,42,23,0.020,18,33,0.002,-1,-75,0.001,33,5,0.009,-14,50,0.008,-18,-53,0.001,-15,-47,0.001,22,101,0.022,0,125,0.012,37,-7,0.011,52,40,0.027,13,39,0.029,47,-109,0.000,-10,-42,0.003,24,118,0.140,-33,117,0.004,56,92,0.001,33,-93,0.004,47,36,0.038,44,18,0.022,43,-7,0.008,20,40,0.005,-4,30,0.102,47,5,0.008,44,-95,0.003,62,17,0.003,23,111,0.108,20,-105,0.009,38,27,0.026,35,103,0.020,15,36,0.014,14,-3,0.014,10,12,0.042,47,86,0.001,38,-122,0.036,49,117,0.001,29,2,0.000,-13,-76,0.084,-29,-51,0.009,16,109,0.022,53,9,0.053,-23,151,0.000,49,6,0.019,48,19,0.032,44,78,0.002,38,104,0.008,35,-94,0.011,12,-1,0.060,59,-151,0.000,40,21,0.019,-12,-44,0.002,40,-84,0.015,-28,153,0.022,39,127,0.060,17,83,0.098,16,-94,0.007,50,18,0.029,27,105,0.084,7,46,0.003,41,94,0.001,51,104,0.001,50,-127,0.000,30,0,0.001,7,-65,0.001,41,-5,0.007,3,-60,0.005,21,-16,0.001,-17,-55,0.001,69,89,0.010,30,111,0.049,8,123,0.004,45,7,0.017,-35,149,0.001,17,2,0.000,-26,-62,0.001,64,178,0.000,41,-103,0.002,51,35,0.007,32,3,0.002,28,-2,0.000,27,37,0.002,4,36,0.002,22,-104,0.002,21,99,0.008,-39,-72,0.017,-52,-71,0.001,46,29,0.035,8,-80,0.011,22,39,0.000,19,35,0.001,-2,25,0.002,-5,37,0.008,42,-5,0.012,37,32,0.021,-10,-77,0.014,10,108,0.059,-10,39,0.004,-14,-42,0.006,-34,25,0.001,56,73,0.001,52,52,0.002,-44,-65,0.002,13,11,0.010,9,8,0.028,46,90,0.001,24,26,0.000,-14,-59,0.000,56,96,0.005,47,24,0.026,19,95,0.015,34,-109,0.001,-23,-56,0.003,-24,29,0.010,-43,-63,0.000,58,60,0.007,38,55,0.001,35,83,0.001,37,100,0.001,34,38,0.009,15,24,0.001,14,-23,0.002,10,32,0.003,47,122,0.008,5,-77,0.002,38,-94,0.027,15,-87,0.040,49,17,0.040,48,-72,0.002,-28,-50,0.008,25,39,0.004,2,38,0.001,1,29,0.003,16,81,0.214,-22,32,0.005,49,-94,0.001,48,71,0.001,26,107,0.160,25,-104,0.002,40,106,0.001,2,-75,0.016,36,37,0.053,-18,-68,0.002,16,-8,0.002,50,84,0.005,12,-5,0.023,-21,-48,0.016,-31,29,0.017,40,-7,0.017,36,4,0.157,35,15,0.013,29,121,0.163,40,-112,0.006,39,99,0.012,54,71,0.002,50,54,0.001,30,57,0.007,26,48,0.002,3,15,0.002,8,81,0.041,17,-64,0.002,-21,17,0.001,51,116,0.002,12,104,0.018,-7,-74,0.001,45,22,0.028,6,94,0.000,-3,42,0.000,-7,-45,0.001,30,91,0.001,-27,24,0.003,45,-85,0.001,60,26,0.022,-30,-56,0.005,32,104,0.005,-33,-66,0.000,31,-101,0.001,28,43,0.001,-30,-71,0.003,55,66,0.018,51,63,0.001,-3,112,0.008,31,76,0.222,28,-102,0.002,27,65,0.002,42,-83,0.144,21,87,0.124,-1,27,0.002,-3,-47,0.004,-2,-58,0.000,-5,-40,0.013,43,117,0.003,45,90,0.001,42,64,0.001,-1,12,0.001,46,-100,0.003,57,71,0.001,37,68,0.030,33,61,0.003,28,103,0.033,9,35,0.015,-15,41,0.024,56,13,0.012,37,-79,0.016,-4,-72,0.001,33,-82,0.013,9,-12,0.018,46,118,0.000,43,-88,0.029,-9,37,0.005,-4,139,0.006,0,44,0.005,-23,35,0.003,-30,-52,0.016,23,70,0.012,1,110,0.018,38,-28,0.001,15,107,0.009,11,40,0.066,-9,-43,0.001,25,101,0.069,-13,26,0.003,61,10,0.001,58,16,0.009,35,111,0.111,37,120,0.042,34,74,0.079,15,-4,0.005,49,96,0.000,11,-15,0.016,48,-123,0.016,5,-57,0.002,20,110,0.022,53,52,0.005,49,45,0.002,29,74,0.070,25,51,0.003,2,10,0.001,-19,30,0.012,68,32,0.000,49,-66,0.000,48,107,0.008,26,127,0.000,-32,-71,0.002,40,78,0.004,39,-91,0.006,50,120,0.001,12,23,0.010,-7,115,0.002,11,100,0.009,-12,29,0.005,59,33,0.004,39,54,0.003,36,-96,0.006,35,59,0.009,30,-90,0.024,-8,-47,0.002,7,37,0.051,-18,17,0.006,-17,31,0.010,-20,48,0.052,54,35,0.003,7,-10,0.007,6,15,0.005,-3,-67,0.000,-7,-62,0.000,-26,32,0.029,-27,-53,0.013,60,7,0.001,41,67,0.001,21,72,0.085,36,77,0.001,-6,-44,0.008,42,111,0.002,-16,-55,0.009,54,80,0.001,-40,-73,0.004,32,76,0.118,28,71,0.094,27,-12,0.003,8,18,0.008,-16,16,0.004,55,38,0.468,31,32,0.189,42,-111,0.001,-2,-46,0.006,-6,149,0.001,65,25,0.001,43,81,0.005,45,126,0.051,52,-114,0.001,13,-83,0.001,9,-78,0.001,46,-72,0.011,-11,-69,0.001,-15,-72,0.004,57,19,0.002,52,-3,0.015,-10,-69,0.000,24,83,0.077,34,121,0.024,-24,-57,0.003,-28,-54,0.013,43,4,0.031,-36,-70,0.005,13,100,0.054,-28,25,0.008,43,13,0.034,23,106,0.032,38,0,0.052,25,113,0.096,34,46,0.021,49,92,0.000,-8,113,0.489,-18,34,0.003,53,40,0.008,29,14,0.001,44,115,0.001,5,28,0.001,-20,-51,0.002,48,127,0.018,63,15,0.001,40,50,0.057,39,9,0.015,36,45,0.026,35,6,0.037,16,48,0.000,39,26,0.001,17,122,0.042,50,11,0.038,27,84,0.181,29,97,0.001,0,98,0.010,41,129,0.020,-36,174,0.002,30,33,0.036,6,43,0.004,-30,31,0.118,41,31,0.011,18,94,0.004,36,121,0.194,17,37,0.003,32,121,0.281,-7,27,0.004,27,-97,0.014,45,-77,0.002,42,83,0.004,41,-80,0.029,21,-71,0.000,52,93,0.000,-26,153,0.002,51,22,0.032,27,16,0.002,55,10,0.019,51,7,0.192,32,-113,0.001,31,132,0.023,46,2,0.010,42,-123,0.004,-29,115,0.001,-5,16,0.196,-6,121,0.025,66,14,0.001,42,24,0.057,18,34,0.002,6,11,0.037,33,8,0.005,5,117,0.024,-15,-44,0.003,22,102,0.015,37,-4,0.029,52,41,0.009,13,34,0.032,-10,-37,0.017,24,119,0.156,56,85,0.021,33,-90,0.006,47,35,0.020,44,19,0.025,20,41,0.015,15,146,0.002,44,-94,0.005,62,18,0.003,23,110,0.110,20,-104,0.008,38,28,0.066,35,102,0.005,15,35,0.005,14,-2,0.007,10,9,0.037,47,85,0.001,-9,122,0.015,-33,-59,0.003,61,50,0.001,-18,179,0.007,49,120,0.005,48,-67,0.002,-13,-77,0.086,-19,-43,0.005,53,12,0.018,49,5,0.021,48,20,0.022,44,79,0.004,38,101,0.015,35,-95,0.008,16,-3,0.010,12,0,0.028,29,-89,0.004,-3,12,0.002,62,78,0.002,59,48,0.001,40,22,0.012,11,124,0.020,-32,24,0.001,40,-91,0.005,39,126,0.145,16,-93,0.030,50,15,0.076,27,112,0.203,7,45,0.004,41,93,0.001,-50,-74,0.000,39,143,0.000,51,103,0.001,30,-3,0.001,-33,-70,0.009,7,-66,0.003,-17,-56,0.001,-6,25,0.006,30,112,0.127,-37,-73,0.016,8,124,0.047,45,2,0.018,-35,152,0.006,17,1,0.001,32,77,0.033,-26,-57,0.080,8,11,0.013,41,-100,0.001,51,34,0.015,32,4,0.002,27,44,0.002,4,21,0.005,21,94,0.004,-1,118,0.027,-39,-73,0.002,46,30,0.029,43,128,0.019,-4,143,0.002,22,40,0.014,19,34,0.001,-2,26,0.002,-10,149,0.002,42,-4,0.004,57,94,0.001,37,31,0.019,-2,137,0.004,10,105,0.047,-10,40,0.006,-9,28,0.004,-4,116,0.011,-34,26,0.036,56,74,0.001,37,-112,0.001,52,69,0.002,13,6,0.056,9,7,0.024,-10,-73,0.000,24,27,0.000,-14,-58,0.000,23,-80,0.001,-34,-55,0.002,0,17,0.001,-38,-64,0.000,47,23,0.023,19,94,0.012,-23,-57,0.002,-24,30,0.028,58,57,0.019,38,56,0.002,35,82,0.001,37,99,0.001,-8,121,0.000,15,23,0.002,10,29,0.003,47,121,0.003,38,-89,0.013,15,-88,0.033,49,20,0.045,14,14,0.002,25,42,0.004,2,35,0.008,1,32,0.021,16,82,0.191,-22,29,0.005,26,108,0.071,25,-105,0.001,40,107,0.007,2,-74,0.001,36,38,0.034,38,129,0.013,50,81,0.013,12,-4,0.015,40,-6,0.005,-20,-39,0.002,-7,151,0.001,40,-119,0.000,39,98,0.002,54,72,0.003,50,51,0.001,30,58,0.005,26,45,0.006,3,14,0.003,2,103,0.051,-20,30,0.012,-21,24,0.000,51,115,0.001,-3,-68,0.000,12,105,0.029,-7,-75,0.002,45,21,0.025,-3,41,0.006,-35,-66,0.003,30,92,0.003,45,-90,0.002,60,27,0.005,32,49,0.028,31,-102,0.006,28,44,0.001,-30,-70,0.004,55,65,0.003,51,62,0.001,-3,111,0.003,31,75,0.404,28,-101,0.003,27,72,0.013,42,-82,0.046,22,-79,0.024,-1,26,0.002,-39,-61,0.005,-2,-53,0.001,70,24,0.000,66,67,0.002,43,124,0.035,45,89,0.001,42,61,0.006,55,99,0.002,-11,-62,0.005,57,74,0.001,37,67,0.013,33,64,0.003,10,125,0.042,28,104,0.037,9,22,0.000,56,14,0.007,37,-76,0.019,-4,-71,0.001,33,-83,0.018,9,-13,0.049,46,123,0.017,43,-89,0.018,57,-152,0.000,0,37,0.015,23,69,0.004,1,109,0.002,15,106,0.033,11,39,0.053,-43,-72,0.000,-9,-44,0.001,25,104,0.080,-13,25,0.002,61,9,0.000,58,13,0.007,35,110,0.075,37,119,0.122,34,71,0.048,15,-5,0.001,49,95,0.000,11,-8,0.011,48,-122,0.017,20,111,0.073,1,-53,0.000,53,51,0.038,49,48,0.001,29,73,0.092,25,70,0.068,-19,29,0.010,68,33,0.002,48,108,0.003,26,128,0.040,-32,-70,0.002,40,79,0.002,39,-92,0.004,50,117,0.002,12,24,0.008,11,99,0.006,-12,30,0.006,59,40,0.012,39,53,0.001,36,-95,0.024,35,58,0.009,30,-85,0.009,-8,-46,0.002,7,36,0.022,-17,30,0.006,54,36,0.004,7,-11,0.025,6,16,0.007,-3,-64,0.000,-26,29,0.096,-27,-58,0.006,60,8,0.000,21,71,0.091,36,78,0.003,17,76,0.104,-6,-47,0.014,42,112,0.002,-16,-54,0.002,21,-104,0.015,54,77,0.001,-40,-72,0.006,32,69,0.005,28,72,0.043,27,-13,0.001,8,19,0.007,-15,40,0.013,-16,25,0.003,55,37,0.022,31,31,0.188,42,-110,0.000,-6,150,0.002,43,88,0.070,45,125,0.045,18,27,0.001,52,-113,0.005,9,-79,0.041,46,-75,0.001,-11,-74,0.001,-15,-73,0.002,57,38,0.003,52,-2,0.076,24,84,0.104,-24,-56,0.005,-28,-53,0.013,43,3,0.017,24,67,0.046,13,99,0.015,-28,26,0.006,-28,-64,0.014,43,20,0.024,23,105,0.046,38,-3,0.012,0,-80,0.000,25,116,0.067,61,13,0.000,49,91,0.000,-8,114,0.133,-18,23,0.001,53,39,0.020,29,13,0.001,44,116,0.002,6,-1,0.099,48,128,0.011,40,51,0.019,36,46,0.023,35,5,0.020,-19,146,0.001,-30,-50,0.024,26,-109,0.009,17,121,0.029,50,12,0.041,12,-61,0.004,27,83,0.184,29,100,0.002,6,-7,0.018,-36,175,0.003,54,-128,0.001,30,34,0.002,6,44,0.003,54,-113,0.001,64,41,0.012,-30,32,0.032,41,34,0.009,36,122,0.022,32,122,0.071,-25,153,0.002,-7,14,0.003,27,-98,0.002,42,84,0.006,41,-81,0.088,52,94,0.000,51,21,0.024,32,41,0.004,27,15,0.001,-9,-40,0.005,55,9,0.009,51,6,0.116,32,-112,0.001,31,131,0.052,42,-122,0.006,18,-16,0.004,-1,-46,0.002,-38,141,0.002,-5,15,0.012,-6,122,0.001,42,21,0.049,18,31,0.001,33,7,0.003,-5,-64,0.001,-15,-45,0.001,22,107,0.036,37,-5,0.041,52,42,0.020,13,33,0.026,47,-111,0.003,-10,-36,0.037,-11,31,0.005,-9,14,0.042,56,86,0.003,-3,148,0.001,33,-91,0.004,47,34,0.028,44,20,0.027,23,28,0.000,20,42,0.017,-8,146,0.002,-4,32,0.019,44,-93,0.059,62,39,0.000,23,109,0.094,20,-103,0.148,38,25,0.001,35,101,0.003,-27,154,0.006,15,34,0.015,14,3,0.008,10,10,0.025,47,132,0.014,61,49,0.000,-8,111,0.456,49,119,0.001,48,-66,0.001,29,4,0.001,-19,-40,0.010,53,11,0.074,-3,102,0.013,49,8,0.054,48,13,0.038,44,80,0.003,38,102,0.010,16,-2,0.002,12,1,0.009,29,-94,0.009,59,47,0.001,40,23,0.047,11,123,0.059,40,-90,0.006,39,125,0.021,-44,-73,0.000,16,-92,0.029,50,16,0.040,27,111,0.106,-22,-49,0.013,41,96,0.001,-21,-47,0.023,39,142,0.034,51,102,0.000,30,-2,0.001,7,-67,0.005,-17,-57,0.001,-6,26,0.005,30,109,0.111,45,1,0.016,60,64,0.000,-29,-55,0.005,-35,151,0.020,32,78,0.004,-6,-55,0.000,-26,-56,0.018,8,12,0.020,41,-101,0.000,3,100,0.050,55,60,0.011,51,33,0.008,32,-3,0.002,66,77,0.003,27,43,0.002,4,22,0.006,-16,-47,0.052,21,93,0.071,-1,117,0.007,-39,-70,0.001,46,35,0.006,43,127,0.062,19,33,0.001,-2,15,0.001,48,96,0.000,-25,48,0.003,9,-84,0.047,-10,150,0.002,43,144,0.008,42,-7,0.014,57,93,0.001,37,42,0.027,10,106,0.208,28,77,0.219,-10,37,0.004,-14,-44,0.003,56,75,0.002,37,-113,0.004,52,70,0.002,13,5,0.016,9,10,0.048,46,80,0.000,24,28,0.000,-14,-61,0.001,23,-81,0.008,-34,-54,0.002,0,18,0.001,-38,-67,0.001,47,22,0.034,34,-111,0.002,-23,-54,0.009,-24,31,0.039,62,51,0.001,58,58,0.006,35,81,0.001,37,94,0.000,34,36,0.025,15,22,0.002,10,30,0.011,47,120,0.001,1,-78,0.008,38,-88,0.005,15,-89,0.019,49,19,0.074,25,41,0.002,-2,101,0.016,2,36,0.004,1,31,0.028,16,83,0.051,-22,30,0.005,48,49,0.000,26,105,0.092,25,-102,0.002,40,108,0.014,2,-77,0.007,36,39,0.025,-18,-70,0.006,50,82,0.003,12,29,0.006,-31,31,0.033,40,-5,0.012,29,123,0.022,7,127,0.020,6,-62,0.001,39,97,0.001,54,69,0.002,50,52,0.001,30,47,0.019,26,46,0.005,6,49,0.001,3,13,0.005,2,104,0.012,17,-62,0.002,-21,23,0.000,51,114,0.001,-3,-69,0.000,12,106,0.040,45,24,0.020,6,100,0.010,30,89,0.001,45,-91,0.003,60,28,0.002,32,50,0.017,-17,-41,0.005,31,-103,0.001,28,45,0.001,55,64,0.003,51,61,0.001,31,74,0.259,28,-100,0.008,9,106,0.134,27,71,0.017,22,-78,0.005,-1,25,0.002,-2,-52,0.000,-5,-42,0.016,46,63,0.001,43,123,0.027,45,92,0.001,42,62,0.004,6,-2,0.033,46,-102,0.001,-11,-63,0.002,-15,-66,0.001,57,73,0.000,37,62,0.010,33,63,0.004,10,126,0.012,28,105,0.126,9,21,0.001,56,15,0.007,37,-77,0.036,-4,-70,0.001,33,-80,0.014,46,124,0.019,43,-90,0.004,0,38,0.035,-5,146,0.002,13,122,0.067,1,112,0.008,15,105,0.067,11,38,0.069,-43,-73,0.003,-9,-45,0.001,25,103,0.089,-13,16,0.024,61,12,0.001,58,14,0.006,0,102,0.043,-18,169,0.002,35,109,0.053,37,130,0.007,34,72,0.141,15,-6,0.003,14,75,0.046,11,-9,0.008,48,-121,0.001,-32,149,0.000,53,46,0.018,49,47,0.001,29,76,0.114,-9,126,0.012,25,69,0.121,-19,32,0.016,68,34,0.004,48,101,0.000,40,80,0.004,39,-93,0.003,50,118,0.001,12,25,0.013,-12,31,0.004,59,39,0.002,36,-94,0.015,35,57,0.003,30,-84,0.013,-8,-45,0.001,7,35,0.001,-17,29,0.005,54,33,0.006,7,-12,0.007,6,13,0.003,17,-98,0.018,-3,-65,0.000,-26,30,0.024,-27,-59,0.003,-13,-39,0.022,60,9,0.001,21,50,0.002,36,79,0.002,17,75,0.113,-6,-46,0.003,31,-116,0.001,42,109,0.001,-16,-53,0.000,21,-105,0.009,-20,-58,0.000,54,78,0.001,32,70,0.032,28,73,0.023,8,20,0.001,-16,26,0.003,55,36,0.005,31,30,0.073,42,-113,0.002,19,48,0.003,18,-87,0.001,-3,-48,0.004,65,27,0.000,43,87,0.008,45,128,0.042,18,28,0.001,52,-112,0.001,9,-76,0.002,46,-74,0.002,-11,-75,0.005,-14,41,0.010,-15,-70,0.007,57,37,0.003,52,-1,0.161,-10,-35,0.042,24,77,0.062,34,119,0.232,-24,-63,0.003,-28,-52,0.018,43,2,0.043,24,68,0.283,-9,32,0.013,0,74,0.001,13,94,0.001,-28,27,0.015,43,19,0.021,24,-77,0.001,23,104,0.059,38,-2,0.004,25,115,0.079,-38,177,0.004,61,16,0.001,49,126,0.009,-8,115,0.020,-42,173,0.001,-18,24,0.001,53,18,0.018,44,117,0.002,5,22,0.005,38,79,0.005,49,-68,0.001,48,137,0.000,14,122,0.423,63,13,0.000,36,47,0.023,35,12,0.002,11,126,0.017,26,-108,0.007,-11,30,0.005,39,24,0.002,50,9,0.114,27,82,0.202,29,99,0.002,6,-6,0.034,53,102,0.002,30,-9,0.043,6,41,0.007,17,-102,0.001,54,-112,0.000,64,42,0.000,-30,29,0.021,41,33,0.023,36,123,0.007,17,39,0.007,-3,-44,0.044,-25,152,0.001,-7,13,0.001,27,-99,0.018,45,-83,0.001,42,81,0.004,41,-78,0.006,-17,-48,0.021,51,28,0.006,32,42,0.003,-25,-69,0.003,22,-97,0.021,-16,46,0.001,-20,49,0.014,51,5,0.158,32,-103,0.002,-25,-70,0.001,19,28,0.001,-1,-47,0.006,-5,14,0.015,46,-121,0.001,42,22,0.056,18,32,0.001,33,10,0.008,-5,-65,0.001,-15,-42,0.009,22,108,0.047,0,128,0.010,52,43,0.005,13,36,0.005,-10,-39,0.002,24,113,0.057,56,87,0.005,33,-88,0.007,47,33,0.008,44,21,0.031,23,27,0.000,20,43,0.012,-4,33,0.035,44,-92,0.014,62,40,0.000,20,-102,0.038,35,108,0.061,15,33,0.108,14,4,0.008,10,7,0.015,47,131,0.024,61,52,0.003,38,-119,0.002,49,122,0.004,48,-65,0.001,29,3,0.001,-19,-41,0.012,53,6,0.012,49,7,0.070,48,14,0.030,44,81,0.011,40,129,0.034,38,107,0.047,35,-105,0.004,16,-1,0.002,53,-101,0.000,12,2,0.005,29,-95,0.132,59,46,0.001,40,24,0.009,61,77,0.000,35,40,0.015,11,122,0.002,40,-89,0.016,39,124,0.016,16,-99,0.019,50,13,0.064,-12,-51,0.000,27,110,0.077,41,95,0.002,3,40,0.004,2,129,0.002,39,141,0.035,-21,58,0.039,-21,-64,0.003,30,3,0.002,7,-68,0.001,-17,-58,0.001,-6,23,0.027,30,110,0.068,8,118,0.004,45,4,0.024,60,65,0.002,-35,146,0.001,32,79,0.000,-26,-59,0.002,8,5,0.063,3,99,0.174,55,59,0.003,51,56,0.023,32,-2,0.001,27,42,0.002,4,23,0.003,22,-101,0.021,-16,-46,0.002,21,96,0.093,-1,132,0.003,-39,-71,0.003,46,36,0.010,43,126,0.137,55,125,0.002,-2,16,0.002,-25,47,0.007,9,-85,0.003,43,143,0.020,42,-6,0.007,-11,38,0.005,57,96,0.000,37,41,0.026,28,78,0.779,-10,38,0.003,-14,-47,0.001,56,76,0.001,52,71,0.003,13,8,0.046,9,9,0.055,46,77,0.000,-14,-60,0.001,23,-82,0.071,-34,-65,0.003,0,19,0.004,47,21,0.021,19,100,0.034,34,-110,0.001,-23,-55,0.005,-24,32,0.004,58,55,0.002,35,136,0.061,34,33,0.004,15,21,0.001,10,43,0.006,-9,31,0.004,-9,117,0.104,-40,175,0.004,1,-79,0.001,38,-91,0.006,15,-90,0.031,49,22,0.031,25,44,0.006,2,33,0.039,1,34,0.053,26,106,0.108,25,-103,0.031,40,101,0.000,2,-76,0.028,36,40,0.028,50,79,0.001,12,30,0.007,40,-4,0.014,-52,-70,0.001,29,118,0.066,7,126,0.090,6,-57,0.004,40,-117,0.000,36,-122,0.002,54,70,0.010,53,141,0.001,50,49,0.002,30,48,0.039,26,59,0.004,6,50,0.000,3,20,0.020,2,101,0.011,-21,22,0.000,51,113,0.001,12,107,0.007,45,23,0.014,30,90,0.001,-37,-70,0.001,-27,33,0.028,45,-88,0.002,60,29,0.004,21,-98,0.031,32,51,0.023,28,46,0.001,8,41,0.032,55,63,0.003,51,68,0.001,-3,137,0.001,31,73,0.162,28,-99,0.001,9,105,0.013,27,70,0.053,-1,24,0.004,-2,-55,0.001,-5,-43,0.010,66,65,0.000,46,64,0.000,43,122,0.023,45,91,0.002,42,75,0.042,55,97,0.001,46,-113,0.001,-15,-67,0.001,57,76,0.000,37,61,0.004,33,66,0.007,28,106,0.133,9,24,0.002,-11,-47,0.001,-9,23,0.002,-4,121,0.017,56,16,0.006,37,-82,0.010,-4,-69,0.002,33,-81,0.015,44,62,0.000,46,121,0.005,43,-91,0.007,24,57,0.010,0,39,0.004,-5,145,0.004,13,121,0.021,1,111,0.025,15,104,0.069,11,37,0.026,14,46,0.018,25,106,0.071,-13,15,0.010,61,11,0.002,58,27,0.007,35,116,0.259,37,129,0.027,34,69,0.023,15,-7,0.003,14,76,0.120,11,-10,0.005,-8,144,0.001,-32,150,0.000,-19,-54,0.001,53,45,0.012,49,50,0.001,29,75,0.068,25,72,0.032,-33,-67,0.001,-19,31,0.013,48,102,0.001,-32,-68,0.018,40,73,0.094,39,-94,0.039,50,115,0.001,12,26,0.013,-12,32,0.002,59,38,0.012,36,-93,0.007,35,48,0.019,12,-87,0.010,30,-87,0.018,-8,-44,0.001,29,90,0.005,7,34,0.003,-36,149,0.001,54,34,0.003,30,28,0.002,6,14,0.005,-20,35,0.025,17,-99,0.028,-7,-61,0.000,-27,-56,0.007,60,10,0.001,21,49,0.002,18,85,0.039,36,80,0.005,17,46,0.001,-6,-49,0.004,42,110,0.001,-16,-52,0.002,-20,-57,0.002,54,83,0.007,32,71,0.069,31,-4,0.006,28,74,0.028,27,-15,0.007,8,13,0.013,-16,27,0.003,55,35,0.004,42,-112,0.003,19,47,0.004,65,30,0.000,43,86,0.003,45,127,0.176,18,25,0.001,52,-111,0.000,13,-86,0.027,-30,153,0.001,-18,-57,0.001,-15,-71,0.008,57,40,0.029,56,-3,0.024,52,0,0.061,24,78,0.056,34,120,0.163,-5,132,0.001,-24,-62,0.001,47,-116,0.004,43,1,0.013,-1,10,0.003,67,16,0.001,13,93,0.002,-28,28,0.007,43,18,0.029,23,103,0.045,-37,-60,0.003,0,-70,0.000,15,76,0.092,61,15,0.001,49,125,0.006,-8,116,0.001,29,-6,0.001,20,77,0.093,-18,21,0.000,53,17,0.013,29,15,0.001,44,118,0.003,5,21,0.005,38,80,0.003,48,138,0.000,63,28,0.003,40,45,0.082,36,48,0.013,35,11,0.048,12,54,0.001,11,125,0.050,26,-111,0.000,39,23,0.017,17,123,0.004,-55,-67,0.001,50,10,0.044,27,81,0.228,29,94,0.001,41,118,0.031,54,-130,0.001,53,101,0.001,30,-8,0.018,26,-13,0.001,6,42,0.003,-10,-68,0.003,54,-115,0.001,-21,-54,0.024,64,43,0.000,-30,30,0.011,41,36,0.022,17,42,0.002,-3,-45,0.008,-6,-77,0.004,-25,151,0.000,-7,16,0.007,45,-80,0.000,42,82,0.004,41,-79,0.008,3,118,0.006,51,27,0.010,32,43,0.003,8,49,0.003,-16,47,0.007,51,12,0.044,32,-102,0.003,45,142,0.002,19,27,0.001,6,-11,0.008,33,92,0.000,-5,13,0.019,-6,120,0.090,65,58,0.002,46,-120,0.007,42,3,0.020,18,29,0.001,33,9,0.002,-5,-66,0.000,-29,152,0.001,-15,-43,0.003,22,105,0.036,-20,-50,0.003,52,44,0.006,13,35,0.005,47,-113,0.000,-10,-38,0.008,24,114,0.067,56,88,0.002,33,-89,0.004,47,32,0.011,44,22,0.027,23,26,0.000,20,44,0.009,19,87,0.006,34,-85,0.016,-4,34,0.036,44,-91,0.009,62,37,0.000,20,-101,0.073,38,31,0.019,35,107,0.061,15,32,0.003,14,1,0.007,10,8,0.066,47,130,0.016,61,51,0.005,-33,20,0.001,-18,178,0.009,6,40,0.017,49,121,0.007,48,-64,0.001,29,-2,0.001,-13,-56,0.001,16,121,0.084,53,5,0.000,49,10,0.058,48,15,0.034,26,83,0.289,44,82,0.025,40,130,0.010,38,108,0.002,35,-106,0.024,16,0,0.003,12,3,0.008,29,-92,0.001,48,-113,0.000,59,45,0.001,40,17,0.023,35,39,0.029,11,121,0.001,-8,37,0.012,40,-88,0.013,39,123,0.064,16,-98,0.011,50,14,0.037,27,109,0.059,3,39,0.002,51,108,0.015,30,4,0.001,7,-69,0.002,3,-72,0.001,-17,-59,0.000,-6,24,0.014,30,115,0.298,23,95,0.013,45,3,0.006,-4,-40,0.019,17,6,0.001,-6,-57,0.000,28,19,0.000,-26,-58,0.007,8,6,0.023,3,98,0.013,55,58,0.003,51,55,0.003,32,-1,0.001,31,52,0.011,27,41,0.002,4,24,0.002,22,-100,0.024,-16,-45,0.001,21,95,0.039,-1,131,0.000,-3,-43,0.003,46,33,0.032,43,125,0.080,22,43,0.015,55,92,0.001,-2,13,0.001,-25,46,0.008,43,142,0.074,42,-9,0.002,57,95,0.000,19,-88,0.003,37,44,0.015,-2,128,0.001,10,104,0.009,28,79,0.291,-14,-46,0.001,56,69,0.002,37,-103,0.000,52,72,0.001,13,7,0.034,8,94,0.000,47,-77,0.000,9,12,0.034,46,78,0.000,43,-80,0.034,-11,125,0.003,-34,-64,0.005,0,20,0.003,37,-118,0.001,47,68,0.007,19,99,0.009,-8,143,0.001,-23,-52,0.008,-24,25,0.000,14,38,0.010,58,56,0.005,38,59,0.005,35,135,0.025,34,34,0.009,15,4,0.003,10,44,0.008,14,32,0.006,1,-76,0.012,38,-90,0.079,15,-91,0.057,49,21,0.038,25,43,0.007,2,34,0.022,1,33,0.018,16,77,0.073,-22,44,0.003,48,51,0.000,26,103,0.054,25,-100,0.122,36,41,0.051,-22,-69,0.001,50,80,0.001,12,31,0.009,7,172,0.001,5,126,0.007,-7,156,0.005,29,117,0.097,7,125,0.068,39,95,0.001,36,-121,0.021,54,75,0.003,50,50,0.001,30,45,0.004,26,60,0.003,3,19,0.005,2,102,0.042,12,108,0.015,-7,-70,0.001,45,18,0.012,-25,-65,0.025,36,101,0.002,-3,38,0.014,30,79,0.073,45,-89,0.004,60,30,0.014,-29,-60,0.001,21,-99,0.012,32,52,0.053,31,-105,0.000,28,47,0.002,8,42,0.020,55,62,0.051,51,67,0.001,-3,140,0.001,31,72,0.059,28,-98,0.001,27,69,0.081,42,-71,0.148,-1,23,0.004,-2,-54,0.001,43,121,0.013,45,86,0.006,42,76,0.007,22,71,0.088,56,-117,0.001,55,96,0.001,52,-122,0.001,13,-59,0.009,-25,18,0.000,5,12,0.008,46,-112,0.002,-11,-61,0.003,-15,-64,0.002,57,75,0.000,37,64,0.003,33,65,0.005,28,107,0.097,9,23,0.000,-11,-44,0.002,-18,-63,0.030,-15,13,0.001,56,41,0.026,37,-83,0.006,-4,-68,0.001,33,-78,0.005,44,63,0.001,46,122,0.009,43,-84,0.013,20,53,0.002,0,40,0.002,-5,152,0.002,13,124,0.087,43,53,0.002,1,114,0.001,34,-77,0.013,15,103,0.066,11,44,0.010,10,-83,0.012,-9,-47,0.001,25,105,0.087,-13,14,0.006,61,6,0.002,58,28,0.001,35,115,0.212,34,70,0.118,15,-8,0.004,49,100,0.000,11,-11,0.011,-32,151,0.002,-19,-55,0.001,53,48,0.004,49,49,0.001,29,70,0.018,25,71,0.025,-2,106,0.005,-19,26,0.001,48,103,0.000,40,74,0.017,39,-95,0.008,36,69,0.037,50,116,0.001,12,27,0.005,-7,135,0.001,11,104,0.003,-12,33,0.002,59,37,0.001,5,98,0.015,39,50,0.014,36,-92,0.004,35,47,0.025,12,-86,0.054,30,-86,0.009,-8,-51,0.000,29,89,0.004,7,33,0.005,-36,150,0.013,54,39,0.016,30,25,0.001,6,19,0.002,17,-96,0.029,-27,-57,0.003,60,11,0.013,21,52,0.002,36,81,0.003,17,45,0.002,-6,-48,0.004,42,123,0.041,-16,-59,0.001,-20,-56,0.001,52,85,0.003,54,84,0.027,-41,-63,0.001,32,72,0.061,31,-5,0.008,28,75,0.038,8,14,0.005,-16,28,0.007,55,34,0.004,31,44,0.008,19,46,0.004,18,-89,0.003,33,127,0.019,-5,56,0.003,-36,148,0.002,65,29,0.000,43,85,0.004,45,122,0.013,18,26,0.001,6,7,0.116,52,-110,0.001,13,-87,0.032,46,-68,0.001,-11,-73,0.001,-14,39,0.010,-15,-68,0.001,57,39,0.013,56,-2,0.010,52,1,0.033,24,79,0.074,34,117,0.262,33,-114,0.001,-24,-61,0.000,47,-117,0.015,43,8,0.036,19,122,0.001,67,15,0.001,43,17,0.017,58,-3,0.001,-37,-61,0.002,15,75,0.092,47,93,0.000,62,-7,0.001,61,42,0.001,-46,170,0.001,49,128,0.005,-8,109,0.203,29,-7,0.001,20,78,0.099,-18,22,0.000,53,20,0.017,48,-4,0.018,29,42,0.001,44,119,0.006,5,24,0.001,38,77,0.015,48,139,0.000,63,27,0.001,40,46,0.019,39,5,0.001,36,49,0.016,35,10,0.023,-19,147,0.000,12,55,0.001,39,22,0.010,50,7,0.082,27,88,0.026,29,93,0.002,41,117,0.015,53,104,0.004,26,-12,0.002,-9,143,0.001,17,-100,0.009,54,-114,0.000,-30,27,0.023,41,35,0.011,36,109,0.013,32,117,0.196,-6,-76,0.002,-7,15,0.005,42,79,0.005,41,-76,0.010,3,117,0.001,21,-75,0.002,51,26,0.009,32,44,0.003,8,50,0.002,4,45,0.004,22,-99,0.008,-16,48,0.006,51,11,0.037,32,-101,0.002,8,-63,0.008,19,26,0.001,-1,-49,0.001,33,91,0.000,-5,20,0.019,46,-123,0.004,42,4,0.004,57,86,0.002,18,30,0.001,33,12,0.003,6,0,0.045,-29,151,0.000,-15,-40,0.016,22,106,0.025,37,-8,0.010,52,29,0.006,13,30,0.008,47,-114,0.001,46,103,0.001,24,115,0.049,33,-86,0.034,47,31,0.008,44,23,0.024,19,86,0.037,34,-84,0.035,-4,35,0.018,44,-90,0.004,62,38,0.000,20,-100,0.078,38,32,0.018,35,106,0.065,15,31,0.001,14,2,0.011,10,5,0.012,47,129,0.016,61,46,0.000,-33,19,0.003,49,124,0.003,11,-83,0.001,48,-55,0.001,29,-3,0.001,16,122,0.046,53,8,0.024,49,9,0.134,48,16,0.018,26,84,0.383,44,83,0.005,5,-4,0.083,38,105,0.001,35,-107,0.001,16,9,0.000,12,4,0.023,29,-93,0.004,-37,141,0.000,59,52,0.001,40,18,0.040,-20,-43,0.092,35,38,0.068,16,16,0.001,-8,38,0.015,40,-95,0.003,39,122,0.086,16,-97,0.011,50,43,0.004,27,116,0.081,3,38,0.001,-1,103,0.016,-21,32,0.015,51,107,0.002,30,1,0.000,7,-70,0.004,3,-73,0.008,-13,-38,0.139,-6,21,0.010,-35,-62,0.003,30,116,0.171,-35,148,0.001,17,5,0.000,-6,-56,0.001,-26,-53,0.014,8,7,0.019,41,-112,0.005,3,97,0.004,55,57,0.004,52,125,0.001,51,54,0.002,32,0,0.001,31,51,0.015,27,48,0.002,4,25,0.002,22,-103,0.005,-16,-44,0.005,21,106,0.251,-39,-69,0.004,31,100,0.002,46,34,0.012,43,132,0.017,22,44,0.008,55,91,0.002,-2,14,0.003,-25,45,0.006,-10,153,0.000,43,141,0.004,42,-8,0.043,19,-89,0.003,37,43,0.019,-2,125,0.001,28,80,0.267,-14,-49,0.002,56,70,0.004,37,-100,0.003,52,73,0.001,-12,-66,0.002,13,2,0.013,9,11,0.017,46,83,0.002,43,-81,0.008,-14,-62,0.000,-34,-67,0.001,0,13,0.001,37,-119,0.002,-23,46,0.002,-30,-49,0.004,23,29,0.000,19,98,0.010,34,-112,0.004,-36,-60,0.004,-23,-53,0.003,-24,26,0.005,-43,-64,0.001,62,50,0.001,58,53,0.006,38,60,0.002,35,134,0.025,37,95,0.000,15,3,0.002,11,0,0.030,10,41,0.015,-9,29,0.004,5,-70,0.001,-10,162,0.002,1,-77,0.035,38,-85,0.040,49,24,0.043,2,31,0.053,1,36,0.020,16,78,0.094,48,52,0.001,26,104,0.090,25,-101,0.010,2,-78,0.003,36,42,0.040,-22,-68,0.001,50,77,0.000,12,32,0.010,-42,-73,0.006,-12,22,0.001,59,16,0.008,5,125,0.001,36,-7,0.001,29,120,0.103,7,124,0.029,40,-123,0.001,39,94,0.001,36,-120,0.005,54,76,0.002,53,143,0.001,50,47,0.003,30,46,0.004,26,57,0.002,3,18,0.002,2,99,0.035,17,-61,0.002,-21,28,0.005,12,77,0.176,64,-147,0.002,45,17,0.019,6,103,0.025,57,12,0.013,36,102,0.059,-21,165,0.001,-3,37,0.006,30,80,0.019,45,-94,0.009,60,31,0.016,32,45,0.050,31,-106,0.067,28,48,0.007,8,43,0.008,-16,33,0.003,55,61,0.010,51,66,0.001,-3,139,0.001,31,71,0.043,28,-97,0.004,9,107,0.052,27,76,0.122,42,-70,0.030,-1,22,0.005,-5,-37,0.007,66,63,0.001,46,62,0.001,43,96,0.001,45,85,0.004,42,73,0.004,22,72,0.072,18,51,0.001,55,95,0.003,-29,-50,0.006,-15,-65,0.000,57,62,0.011,56,-5,0.001,37,63,0.006,33,68,0.013,28,108,0.067,9,26,0.000,-11,-45,0.001,-15,16,0.006,56,42,0.016,37,-80,0.011,33,-79,0.008,44,64,0.000,43,-85,0.012,20,54,0.002,-23,26,0.001,13,123,0.029,47,55,0.001,43,60,0.003,20,-155,0.000,1,113,0.002,38,-27,0.002,37,142,0.001,34,-76,0.003,15,102,0.036,11,43,0.011,-9,-48,0.002,25,108,0.036,58,25,0.004,35,114,0.224,37,131,0.000,34,67,0.008,15,-9,0.007,49,99,0.000,11,-4,0.027,-9,112,0.071,-32,152,0.001,-19,-52,0.001,53,47,0.008,49,52,0.001,48,1,0.016,29,69,0.008,25,74,0.059,-19,25,0.000,48,104,0.000,-12,-77,0.062,40,75,0.003,39,-96,0.005,36,70,0.025,-19,170,0.001,50,113,0.001,12,28,0.006,11,103,0.002,-12,34,0.017,59,44,0.001,5,97,0.023,39,49,0.026,36,-107,0.001,35,46,0.029,12,-85,0.019,30,-97,0.040,-8,-50,0.002,29,92,0.014,7,32,0.007,8,100,0.049,54,40,0.024,6,20,0.003,-31,152,0.001,17,-97,0.012,-26,33,0.053,8,105,0.007,60,12,0.005,41,58,0.003,21,51,0.002,18,83,0.048,36,82,0.002,17,48,0.002,-6,-51,0.000,42,124,0.148,-16,-58,0.003,-20,-55,0.001,52,86,0.012,54,81,0.001,31,-6,0.014,28,76,0.089,27,-9,0.001,8,15,0.003,-16,21,0.000,55,33,0.003,31,43,0.003,42,-114,0.003,19,45,0.005,18,-88,0.005,33,130,0.024,43,92,0.001,45,121,0.007,-4,153,0.001,52,-109,0.000,13,-84,0.003,46,-71,0.030,-14,40,0.015,-15,-69,0.003,57,42,0.012,0,103,0.006,52,2,0.033,24,80,0.058,-9,18,0.004,34,118,0.279,33,-115,0.001,-5,130,0.001,47,-118,0.000,43,7,0.024,-13,-47,0.001,-24,-45,0.041,43,24,0.018,23,101,0.021,38,1,0.004,15,74,0.040,47,108,0.010,62,-6,0.001,61,41,0.001,-4,102,0.004,49,127,0.008,-8,110,0.285,29,-4,0.000,20,79,0.078,-18,27,0.004,53,19,0.038,-3,106,0.009,29,41,0.002,44,120,0.011,5,23,0.001,38,78,0.019,-22,-159,0.000,48,140,0.000,29,-102,0.002,63,26,0.001,40,47,0.030,39,4,0.006,36,50,0.019,35,9,0.018,16,53,0.000,39,21,0.012,50,8,0.092,27,87,0.036,29,96,0.000,-22,-45,0.023,41,120,0.047,3,73,0.000,53,103,0.003,-35,-71,0.012,-25,-56,0.009,17,-101,0.005,-21,-44,0.028,8,77,0.114,-30,28,0.029,41,22,0.024,-29,-59,0.005,36,110,0.024,17,44,0.014,32,118,0.156,-6,-79,0.012,-7,18,0.007,42,80,0.002,41,-77,0.006,51,25,0.011,32,37,0.047,4,46,0.004,22,-98,0.014,51,10,0.047,32,-100,0.002,-38,178,0.000,8,-62,0.027,19,25,0.001,-1,-50,0.001,33,94,0.000,-5,19,0.030,5,1,0.011,46,-122,0.008,42,1,0.003,57,85,0.001,33,11,0.010,-5,-60,0.001,-30,150,0.000,-18,-52,0.002,-15,-41,0.008,22,79,0.063,52,30,0.012,13,29,0.005,47,-115,0.000,46,104,0.001,24,116,0.086,-14,-69,0.001,33,-87,0.011,47,30,0.017,44,24,0.029,19,85,0.101,34,-87,0.011,-4,36,0.015,14,44,0.064,44,-89,0.009,62,43,0.000,38,29,0.040,35,105,0.054,15,30,0.001,14,-9,0.005,10,6,0.016,47,128,0.030,61,45,0.000,-33,18,0.001,38,-112,0.001,34,11,0.018,49,123,0.003,48,-54,0.001,29,0,0.000,22,-12,0.002,16,123,0.004,53,7,0.026,49,12,0.055,48,25,0.029,26,81,0.361,44,84,0.004,5,-5,0.022,38,106,0.014,35,-100,0.001,16,10,0.000,53,-104,0.000,12,5,0.045,29,-98,0.057,59,51,0.001,40,19,0.020,35,37,0.099,16,25,0.001,-8,39,0.012,26,-77,0.001,-32,29,0.030,40,-94,0.002,-17,-47,0.014,16,-96,0.017,50,44,0.005,27,115,0.093,3,37,0.001,2,128,0.000,-21,31,0.016,51,106,0.001,50,-101,0.001,30,2,0.000,7,-71,0.006,3,-74,0.055,-6,22,0.010,30,113,0.161,-35,147,0.001,17,8,0.000,-26,-52,0.008,8,8,0.020,55,56,0.005,52,126,0.001,51,53,0.002,32,9,0.003,31,50,0.023,27,47,0.002,4,26,0.001,22,-102,0.024,-16,-51,0.001,21,105,0.034,-1,129,0.000,-36,139,0.011,31,99,0.002,46,23,0.010,43,131,0.009,22,41,0.011,55,90,0.004,-2,19,0.005,-25,44,0.001,57,97,0.001,19,-90,0.009,37,38,0.037,-10,-76,0.017,-2,126,0.001,28,81,0.109,-14,-48,0.002,-34,19,0.062,56,71,0.001,37,-101,0.001,34,107,0.051,52,74,0.001,-44,-64,0.001,13,1,0.009,47,-79,0.001,9,-2,0.007,46,84,0.006,43,-82,0.004,-34,-66,0.004,-22,167,0.001,0,14,0.001,-23,45,0.003,43,63,0.000,19,97,0.030,34,-115,0.000,-24,27,0.003,-43,-65,0.002,58,54,0.002,38,57,0.004,35,133,0.012,37,106,0.023,15,2,0.002,11,-1,0.014,10,42,0.005,5,-71,0.001,1,-74,0.001,38,-84,0.019,49,23,0.020,-28,-49,0.012,2,32,0.020,1,35,0.049,16,79,0.064,48,45,0.052,26,101,0.034,36,43,0.019,12,33,0.016,-42,-72,0.005,-21,-49,0.024,-12,23,0.001,59,15,0.004,39,76,0.017,36,-6,0.022,-7,142,0.001,29,119,0.057,7,123,0.033,6,-58,0.012,40,-122,0.007,36,-119,0.041,54,73,0.003,50,48,0.002,30,51,0.015,26,58,0.007,7,12,0.006,3,17,0.002,2,100,0.063,8,82,0.014,-21,27,0.001,50,-97,0.001,12,78,0.142,45,20,0.026,36,103,0.047,-3,40,0.001,30,77,0.232,-27,30,0.016,45,-95,0.003,60,32,0.000,21,-97,0.009,32,46,0.018,31,-107,0.001,28,49,0.004,8,44,0.006,-16,34,0.005,55,28,0.005,51,65,0.001,-3,134,0.001,31,70,0.009,28,-96,0.004,27,75,0.064,42,-73,0.033,18,-63,0.003,-1,21,0.004,-5,-38,0.020,66,64,0.001,43,95,0.001,45,88,0.003,42,74,0.007,22,69,0.001,18,52,0.000,55,94,0.001,46,-114,0.003,-11,-67,0.002,-28,152,0.005,-15,-62,0.001,57,61,0.013,56,-4,0.003,52,-9,0.006,33,67,0.007,28,109,0.066,9,25,0.003,-11,-50,0.000,-15,15,0.006,56,43,0.007,37,-81,0.011,34,79,0.000,44,65,0.001,-52,-69,0.001,43,-86,0.009,-9,36,0.012,20,55,0.002,-30,-55,0.003,47,54,0.001,43,59,0.002,-12,21,0.001,37,141,0.067,34,-79,0.015,15,101,0.052,11,42,0.004,10,-69,0.041,-9,-49,0.002,25,107,0.039,-13,20,0.001,61,8,0.001,58,26,0.004,35,113,0.113,37,126,0.010,34,68,0.011,15,-10,0.004,49,102,0.000,11,-5,0.018,14,33,0.034,-19,-53,0.001,53,58,0.001,49,51,0.000,48,2,0.034,29,72,0.146,44,125,0.045,25,73,0.043,-19,28,0.004,48,81,0.001,-12,-76,0.031,40,76,0.001,39,-97,0.001,36,71,0.008,50,114,0.001,-38,147,0.001,-12,35,0.011,59,43,0.001,39,48,0.021,36,-106,0.001,35,45,0.033,12,-84,0.005,30,-96,0.009,-8,-49,0.003,29,91,0.004,14,79,0.078,7,31,0.006,-17,41,0.001,54,37,0.016,53,110,0.001,30,15,0.001,-22,-43,0.031,6,17,0.004,17,-94,0.016,-26,34,0.009,8,106,0.008,41,57,0.001,21,46,0.005,18,84,0.127,36,83,0.001,17,47,0.001,-6,-50,0.004,42,121,0.024,-16,-57,0.002,-20,-54,0.001,52,87,0.001,54,82,0.002,31,-7,0.028,27,-10,0.001,8,16,0.016,-16,22,0.001,55,32,0.002,31,42,0.002,-2,-49,0.005,19,52,0.002,18,-91,0.003,-29,32,0.032,43,91,0.002,45,124,0.025,52,-108,0.001,13,-85,0.013,5,7,0.130,46,-70,0.005,-14,37,0.001,57,41,0.019,0,104,0.010,-43,148,0.007,24,105,0.045,34,115,0.251,33,-112,0.058,47,-119,0.002,44,29,0.023,43,6,0.078,23,-13,0.000,-36,-69,0.000,-24,-44,0.003,43,23,0.024,24,-81,0.002,23,100,0.027,20,-78,0.001,38,2,0.002,0,-75,0.002,47,107,0.008,61,44,0.001,35,141,0.148,-4,103,0.050,49,130,0.003,48,-89,0.004,29,-5,0.001,20,80,0.068,-18,28,0.005,53,14,0.016,29,44,0.001,44,121,0.006,5,34,0.002,38,83,0.001,48,133,0.004,63,25,0.001,40,48,0.028,39,3,0.018,36,51,0.033,35,0,0.062,16,54,0.001,26,-112,0.001,59,7,0.001,39,20,0.004,17,96,0.096,50,5,0.123,27,86,0.140,29,95,0.001,41,119,0.039,54,-127,0.000,53,82,0.003,30,-5,0.006,-21,-45,0.012,8,78,0.195,-30,25,0.002,41,21,0.031,36,111,0.021,17,43,0.019,32,119,0.179,-6,-78,0.014,-7,17,0.007,42,77,0.005,41,-90,0.015,51,16,0.027,32,38,0.005,4,47,0.002,51,9,0.058,32,-107,0.001,8,-61,0.001,45,143,0.000,-1,-51,0.002,33,93,0.000,-5,18,0.012,46,-117,0.003,42,2,0.008,-34,149,0.001,6,12,0.011,-44,-71,0.001,-5,-61,0.000,22,80,0.064,52,31,0.019,13,32,0.013,47,-100,0.000,-10,-67,0.002,24,109,0.054,20,-16,0.001,56,83,0.000,33,-84,0.105,47,29,0.045,44,25,0.029,34,-86,0.022,-4,37,0.030,44,-88,0.020,62,44,0.000,38,30,0.023,35,96,0.000,15,29,0.001,14,-8,0.003,10,-13,0.016,47,127,0.043,-9,121,0.023,61,48,0.002,34,12,0.001,49,30,0.011,48,-53,0.001,29,-1,0.001,-13,-59,0.000,-19,-45,0.002,6,123,0.010,49,11,0.044,48,26,0.032,26,82,0.257,44,85,0.009,40,125,0.070,38,111,0.030,35,-101,0.009,53,-105,0.002,12,6,0.034,29,-99,0.002,59,50,0.001,40,20,0.024,-11,150,0.001,35,44,0.026,16,26,0.001,-8,40,0.020,-32,30,0.025,40,-93,0.002,39,120,0.033,50,41,0.007,27,114,0.157,26,35,0.001,3,44,0.010,-21,30,0.008,51,105,0.001,50,-100,0.000,23,81,0.086,7,-72,0.044,3,-75,0.019,-6,35,0.010,30,114,0.218,18,81,0.018,45,0,0.017,17,7,0.000,-26,-55,0.010,8,1,0.016,41,-110,0.001,55,55,0.006,52,127,0.000,51,60,0.002,32,10,0.002,31,49,0.039,28,5,0.000,27,46,0.002,4,27,0.001,-16,-50,0.003,21,108,0.030,-1,128,0.003,31,98,0.003,46,24,0.030,43,130,0.027,-4,144,0.002,22,42,0.015,55,89,0.001,-2,20,0.003,46,-89,0.001,57,100,0.000,37,37,0.036,-2,131,0.000,28,82,0.070,-9,27,0.008,-34,20,0.012,56,72,0.001,37,-106,0.001,34,108,0.099,52,75,0.001,13,4,0.020,9,-3,0.004,46,81,0.001,43,-83,0.022,-34,-61,0.008,0,15,0.000,-23,48,0.018,13,145,0.005,43,62,0.001,23,59,0.026,34,-114,0.003,-24,28,0.002,-42,146,0.001,44,-124,0.001,38,58,0.003,35,140,0.978,37,105,0.014,15,1,0.002,11,-2,0.014,10,39,0.054,1,-75,0.012,38,-87,0.009,49,26,0.027,14,19,0.002,2,29,0.007,1,38,0.001,16,80,0.081,48,46,0.002,26,102,0.045,40,97,0.002,36,44,0.019,38,139,0.002,-22,-70,0.001,50,107,0.001,12,34,0.006,-12,24,0.001,59,14,0.005,40,-8,0.039,39,75,0.001,36,-5,0.023,35,72,0.022,-7,141,0.001,29,114,0.128,7,122,0.003,40,-121,0.001,36,-118,0.001,54,74,0.025,50,45,0.004,30,52,0.012,26,55,0.001,7,11,0.015,2,97,0.001,-20,31,0.010,-21,26,0.001,-3,-78,0.020,50,-96,0.002,12,79,0.154,-7,-69,0.000,45,19,0.019,6,101,0.055,18,109,0.012,36,104,0.083,-3,39,0.005,-35,-67,0.001,30,78,0.125,-27,29,0.119,45,-92,0.008,60,33,0.000,21,-86,0.005,32,47,0.011,31,-92,0.007,8,37,0.033,-16,35,0.026,55,27,0.011,-3,133,0.002,31,69,0.006,28,-95,0.001,9,93,0.002,27,74,0.042,42,-72,0.032,-1,36,0.078,-5,-39,0.008,66,61,0.000,5,-6,0.031,43,94,0.001,45,87,0.003,42,71,0.007,22,70,0.033,18,49,0.002,55,93,0.009,-11,-64,0.001,-15,-63,0.001,57,64,0.004,37,73,0.002,52,-8,0.011,33,70,0.028,28,110,0.069,9,28,0.004,-11,-51,0.001,-15,18,0.001,56,44,0.065,34,80,0.000,-4,-65,0.001,44,66,0.006,46,109,0.001,43,-87,0.023,24,53,0.000,20,56,0.000,-20,147,0.005,-23,28,0.003,47,53,0.002,-47,-68,0.000,1,115,0.001,34,-78,0.009,14,-83,0.002,11,41,0.012,10,-68,0.043,-9,-50,0.001,25,94,0.041,-13,19,0.004,61,7,0.001,58,23,0.001,37,125,0.001,34,65,0.003,15,-11,0.004,49,101,0.000,11,-6,0.014,-19,-58,0.001,53,57,0.014,49,54,0.001,48,3,0.340,29,71,0.074,44,126,0.088,25,76,0.072,-19,27,0.002,48,82,0.001,-12,-59,0.001,40,69,0.041,39,-98,0.001,36,72,0.004,50,111,0.000,-7,140,0.002,-12,36,0.006,59,42,0.001,39,47,0.015,36,-105,0.002,35,52,0.364,30,-99,0.002,-8,-48,0.005,29,86,0.000,7,30,0.007,-17,40,0.015,54,38,0.037,30,16,0.001,6,18,0.004,17,-95,0.011,64,19,0.000,41,60,0.010,21,45,0.005,57,-1,0.001,-6,-37,0.014,42,122,0.052,4,-75,0.084,-16,-56,0.018,-20,-53,0.001,52,88,0.001,54,87,0.020,31,-8,0.051,27,-11,0.001,-16,23,0.003,55,31,0.014,31,41,0.001,19,51,0.002,18,-90,0.004,33,132,0.045,66,33,0.000,-29,31,0.023,43,90,0.004,45,123,0.032,42,43,0.028,4,114,0.003,13,-90,0.005,46,-81,0.003,-14,38,0.002,57,44,0.002,0,113,0.005,24,106,0.029,34,116,0.265,33,-113,0.001,-5,136,0.000,47,-120,0.004,43,5,0.030,23,-14,0.000,19,111,0.080,-24,-51,0.047,44,-83,0.002,43,22,0.033,58,12,0.005,20,-77,0.017,-37,-56,0.002,0,-74,0.001,47,106,0.000,61,43,0.001,-4,104,0.031,49,129,0.002,-8,112,0.261,29,-10,0.002,20,81,0.044,-18,25,0.003,53,13,0.012,29,43,0.001,44,122,0.011,5,33,0.003,-28,-59,0.011,48,134,0.002,29,-100,0.002,63,24,0.003,40,41,0.025,39,2,0.001,36,52,0.036,35,-1,0.013,59,6,0.005,39,19,0.005,17,95,0.021,54,-9,0.001,50,6,0.072,27,85,0.110,41,122,0.087,53,81,0.002,30,-4,0.002,54,-111,0.000,23,99,0.015,-30,26,0.001,41,24,0.015,36,112,0.090,32,120,0.273,-6,-81,0.001,-7,20,0.008,42,78,0.002,41,-91,0.011,51,15,0.034,32,39,0.002,8,45,0.006,4,48,0.002,-3,-39,0.001,51,0,0.331,32,-106,0.006,-29,-70,0.002,-38,142,0.000,-5,17,0.009,46,-116,0.002,42,-1,0.017,57,87,0.000,-2,120,0.009,-5,-62,0.001,-15,-39,0.029,22,77,0.089,52,32,0.014,13,31,0.012,47,-101,0.001,46,102,0.000,24,110,0.099,-14,-71,0.017,20,-15,0.001,56,84,0.001,-3,147,0.001,33,-85,0.012,47,44,0.002,44,26,0.040,34,-89,0.008,-4,38,0.044,44,-87,0.007,62,41,0.001,38,35,0.019,35,95,0.000,-27,153,0.004,15,44,0.074,49,144,0.001,10,-12,0.018,47,126,0.037,61,47,0.003,34,9,0.014,15,-83,0.001,49,29,0.023,-19,-50,0.004,-3,101,0.001,48,27,0.026,26,79,0.148,44,86,0.016,40,126,0.021,38,112,0.031,35,-102,0.001,12,7,0.039,29,-96,0.004,59,49,0.001,35,43,0.018,16,27,0.001,-8,33,0.003,14,98,0.001,-31,-70,0.003,-32,31,0.001,40,-92,0.003,39,119,0.154,16,-86,0.001,50,42,0.006,27,113,0.184,-22,-48,0.032,41,86,0.009,3,43,0.003,2,126,0.002,-54,-68,0.001,-21,29,0.086,50,-103,0.001,-35,-72,0.000,45,42,0.022,7,-73,0.042,-6,36,0.015,45,-1,0.003,41,-124,0.001,-29,-64,0.004,-35,141,0.001,17,10,0.001,32,92,0.001,-26,-54,0.030,8,2,0.013,41,-111,0.012,55,54,0.004,52,128,0.001,51,59,0.017,32,11,0.001,31,48,0.017,28,6,0.000,27,45,0.002,4,28,0.002,-16,-49,0.008,21,107,0.117,18,-69,0.094,-20,18,0.001,31,97,0.002,46,21,0.024,43,129,0.012,55,88,0.001,-2,17,0.003,-8,-79,0.011,5,0,0.140,46,-88,0.001,43,146,0.002,37,40,0.025,-39,142,0.001,-2,132,0.004,28,83,0.037,-10,15,0.007,-14,-50,0.001,-18,-67,0.009,56,65,0.002,37,-107,0.002,34,105,0.040,52,76,0.001,13,3,0.020,9,0,0.022,46,82,0.001,43,-76,0.020,-14,-67,0.000,-34,-60,0.045,0,16,0.001,37,-122,0.130,-23,47,0.005,43,61,0.001,23,58,0.016,-23,-64,0.003,44,-123,0.019,58,68,0.000,38,63,0.003,35,139,0.091,37,108,0.011,15,0,0.001,11,-3,0.015,10,40,0.057,1,-72,0.001,38,-86,0.008,49,25,0.040,-2,102,0.017,2,30,0.007,1,37,0.003,48,47,0.002,26,115,0.068,40,98,0.004,36,29,0.008,38,140,0.015,50,108,0.002,12,35,0.011,-12,25,0.004,59,13,0.003,39,74,0.003,36,-4,0.036,35,71,0.005,-7,144,0.006,29,113,0.157,40,-120,0.001,54,47,0.006,50,46,0.008,30,49,0.033,26,56,0.003,7,10,0.037,2,98,0.006,-21,25,0.000,-3,-79,0.044,50,-99,0.001,12,80,0.189,45,14,0.031,6,102,0.054,18,110,0.049,36,105,0.037,-3,34,0.041,-27,32,0.020,45,-93,0.038,42,131,0.016,60,34,0.001,21,-87,0.004,32,48,0.010,-17,-42,0.005,31,-93,0.004,28,51,0.002,8,38,0.053,-16,36,0.084,55,26,0.006,31,20,0.001,27,73,0.017,42,-75,0.011,4,-8,0.003,18,-65,0.025,-1,35,0.127,-36,144,0.001,66,62,0.000,43,93,0.001,45,82,0.002,42,72,0.015,22,75,0.099,18,50,0.001,6,3,0.099,9,-66,0.005,-10,124,0.002,-11,-65,0.001,-15,-60,0.000,57,63,0.002,37,76,0.001,52,-7,0.010,33,69,0.060,28,111,0.055,9,27,0.003,-11,-48,0.008,-33,148,0.000,-15,17,0.003,56,37,0.015,34,77,0.003,-4,-64,0.001,44,67,0.001,43,-112,0.003,24,54,0.001,-23,27,0.002,1,118,0.002,34,-81,0.019,11,16,0.009,10,-71,0.080,25,93,0.045,-13,18,0.008,-32,116,0.024,58,24,0.001,37,128,0.352,34,66,0.005,49,104,0.000,11,-7,0.010,10,76,0.023,-19,-59,0.001,53,60,0.012,49,53,0.001,48,4,0.014,29,66,0.001,44,127,0.085,25,75,0.075,-19,22,0.001,48,83,0.001,-12,-58,0.000,-32,-63,0.006,40,70,0.055,39,-99,0.001,36,73,0.009,50,112,0.000,-7,139,0.001,11,108,0.047,59,41,0.003,39,46,0.016,36,-104,0.000,35,51,0.047,30,-98,0.004,29,85,0.000,7,29,0.005,-17,39,0.006,54,43,0.004,30,13,0.001,-9,147,0.002,6,23,0.001,8,79,0.021,17,-92,0.031,64,20,0.001,-13,-48,0.001,41,59,0.005,21,48,0.005,18,82,0.028,17,49,0.000,-6,-36,0.007,-44,173,0.014,42,119,0.037,4,-74,0.231,-20,-52,0.001,52,89,0.001,54,88,0.001,31,-9,0.019,-16,24,0.005,55,30,0.007,31,40,0.001,19,50,0.002,18,-93,0.021,-3,-49,0.006,33,131,0.201,-29,30,0.015,43,89,0.007,45,118,0.001,42,44,0.013,4,115,0.016,13,-91,0.001,46,-80,0.003,-28,-65,0.011,-14,35,0.020,57,43,0.007,0,114,0.001,52,21,0.055,24,107,0.028,34,113,0.231,33,-110,0.001,-24,-65,0.003,47,-121,0.004,43,12,0.055,23,-15,0.000,19,110,0.064,-24,-50,0.014,-30,-58,0.002,43,21,0.034,-28,-60,0.004,23,98,0.015,20,-76,0.048,-37,-57,0.002,11,76,0.165,47,105,0.000,-13,46,0.005,61,38,0.000,-4,105,0.077,49,132,0.000,-42,174,0.003,20,82,0.068,-18,26,0.005,53,16,0.012,29,38,0.001,44,123,0.015,5,36,0.002,38,81,0.006,48,135,0.002,29,-101,0.002,63,23,0.002,40,42,0.012,39,1,0.000,-20,-47,0.008,35,-2,0.008,39,18,0.003,17,98,0.025,54,-8,0.004,50,3,0.056,27,92,0.018,41,121,0.070,53,84,0.028,30,-7,0.011,41,10,0.003,54,-110,0.001,-35,-58,0.436,64,40,0.007,-30,23,0.001,41,23,0.015,36,113,0.048,32,129,0.002,-6,-80,0.020,-7,19,0.005,42,91,0.002,41,-88,0.055,52,117,0.001,51,14,0.045,32,40,0.003,8,46,0.005,51,-1,0.053,32,-105,0.002,8,-67,0.003,-2,-44,0.002,33,95,0.000,-5,24,0.005,65,61,0.000,46,-119,0.008,42,0,0.004,-1,-52,0.000,-2,117,0.022,-5,-63,0.000,22,78,0.057,52,33,0.010,13,26,0.010,-10,-61,0.001,24,111,0.059,-14,-70,0.001,56,77,0.001,-20,170,0.000,47,43,0.010,44,27,0.101,20,33,0.001,34,-88,0.009,-4,39,0.008,47,-4,0.004,44,-86,0.001,62,42,0.000,38,36,0.021,15,43,0.008,49,143,0.001,47,125,0.036,61,74,0.010,-34,150,0.003,38,-109,0.000,34,10,0.018,49,32,0.017,-19,-51,0.002,-22,49,0.005,48,28,0.019,26,80,0.176,44,87,0.021,40,127,0.022,38,109,0.003,35,-103,0.000,16,5,0.001,12,8,0.082,-42,-65,0.000,29,-97,0.006,-36,-68,0.001,59,56,0.001,40,14,0.002,35,42,0.021,16,28,0.001,-8,34,0.005,26,-78,0.001,-31,-71,0.008,40,-99,0.003,39,118,0.305,50,39,0.009,-12,-50,0.000,27,120,0.063,26,33,0.071,41,85,0.002,3,42,0.006,51,95,0.003,-21,-65,0.002,50,-102,0.001,45,41,0.017,7,-74,0.007,-6,33,0.007,17,9,0.001,28,24,0.001,8,3,0.012,55,53,0.028,51,58,0.004,32,12,0.010,31,47,0.021,28,7,0.000,27,52,0.001,4,13,0.005,-16,-48,0.024,21,102,0.010,18,-68,0.012,-20,19,0.001,31,96,0.002,46,22,0.023,55,87,0.023,-10,-66,0.001,-2,18,0.005,46,-91,0.001,43,145,0.011,-11,37,0.005,57,54,0.004,37,39,0.026,-17,-50,0.004,28,84,0.041,-10,16,0.007,-34,18,0.001,56,66,0.003,37,-104,0.001,34,106,0.070,52,61,0.002,13,-2,0.026,9,-1,0.007,46,135,0.001,43,-77,0.029,-14,-66,0.001,-34,-63,0.003,0,25,0.008,-38,-56,0.001,47,63,0.000,43,68,0.001,23,57,0.006,-22,150,0.003,15,110,0.001,-23,-65,0.002,44,-122,0.007,58,65,0.000,38,64,0.004,35,138,0.084,37,107,0.024,15,-1,0.002,11,4,0.015,10,37,0.027,-9,116,0.097,-40,176,0.002,5,-74,0.023,1,-73,0.001,38,-81,0.013,49,28,0.017,25,34,0.000,2,27,0.003,1,40,0.002,48,48,0.000,26,116,0.073,40,99,0.005,36,30,0.017,35,-75,0.001,50,105,0.001,12,36,0.004,-12,26,0.007,62,114,0.001,-32,-51,0.001,39,73,0.004,35,70,0.025,-7,143,0.002,30,-105,0.000,29,116,0.108,36,-116,0.001,54,48,0.005,50,75,0.001,30,50,0.016,7,9,0.048,50,-98,0.000,12,81,0.071,-27,-70,0.001,45,13,0.062,8,125,0.065,36,106,0.031,-3,33,0.038,-7,-34,0.001,-37,-71,0.009,-27,31,0.011,45,-98,0.001,42,132,0.004,60,35,0.001,21,-84,0.001,32,57,0.001,31,-94,0.007,28,52,0.007,8,39,0.093,-16,29,0.048,55,25,0.012,-3,135,0.001,42,-74,0.007,4,-7,0.008,18,-64,0.003,-1,34,0.000,45,81,0.002,42,69,0.003,22,76,0.116,56,-120,0.001,18,47,0.001,-35,118,0.000,13,-60,0.003,14,-11,0.008,9,-67,0.018,46,-111,0.001,-11,-54,0.001,-15,-61,0.000,57,66,0.022,37,75,0.000,52,-6,0.007,33,72,0.102,28,112,0.111,9,14,0.018,-11,-49,0.001,-9,22,0.001,-4,122,0.006,56,38,0.016,34,78,0.000,-4,-63,0.000,44,68,0.001,43,-113,0.000,24,55,0.003,20,58,0.000,1,117,0.000,34,-80,0.016,15,82,0.001,11,15,0.024,10,-70,0.009,25,96,0.003,-13,17,0.015,37,127,0.413,34,63,0.025,49,103,0.000,10,73,0.001,53,59,0.010,49,56,0.001,48,-3,0.013,29,65,0.001,44,128,0.036,25,62,0.003,-1,167,0.000,35,-120,0.009,-19,21,0.001,48,84,0.001,-12,-57,0.001,-32,-62,0.005,40,71,0.047,39,-100,0.000,36,74,0.018,50,109,0.001,11,107,0.076,-12,154,0.000,39,45,0.018,35,50,0.021,30,-93,0.011,29,88,0.002,7,28,0.003,-17,38,0.013,54,44,0.005,53,111,0.001,30,14,0.001,-25,-52,0.009,17,-93,0.019,12,109,0.046,64,13,0.000,45,49,0.001,41,46,0.024,21,47,0.005,18,79,0.123,36,134,0.001,51,-104,0.000,-6,-39,0.009,45,-62,0.002,42,120,0.030,4,-73,0.023,52,90,0.001,54,85,0.002,32,13,0.016,55,29,0.008,31,39,0.001,9,139,0.000,42,-102,0.001,19,49,0.002,18,-92,0.016,33,134,0.035,66,31,0.000,-29,29,0.024,45,117,0.001,42,41,0.000,4,116,0.004,22,29,0.000,13,-88,0.060,46,-83,0.000,-14,36,0.010,57,30,0.002,0,115,0.000,52,22,0.059,33,36,0.102,24,108,0.045,-15,48,0.001,-38,148,0.001,34,114,0.324,33,-111,0.051,-24,-64,0.005,47,-122,0.110,46,143,0.004,43,11,0.046,19,109,0.011,-1,9,0.000,-24,-49,0.013,44,-81,0.003,43,28,0.026,23,97,0.010,-37,-58,0.001,47,104,0.000,-46,-68,0.001,-13,45,0.010,61,37,0.000,-4,106,0.009,49,131,0.001,29,-8,0.006,20,83,0.052,-18,15,0.003,53,15,0.029,48,33,0.018,29,37,0.001,44,124,0.027,5,35,0.002,38,82,0.002,48,136,0.019,29,-106,0.014,63,22,0.002,40,43,0.011,39,0,0.074,35,-3,0.010,16,33,0.023,-17,169,0.001,-7,106,0.035,26,-101,0.008,-19,-42,0.010,59,12,0.008,39,17,0.027,36,-75,0.003,17,97,0.065,50,4,0.118,27,91,0.012,41,124,0.284,-33,-53,0.003,53,83,0.003,-17,180,0.003,30,-6,0.006,41,9,0.003,-21,-40,0.055,-21,-55,0.002,-30,24,0.001,41,26,0.018,36,114,0.116,32,130,0.023,-17,-49,0.065,-7,38,0.016,42,92,0.002,41,-89,0.008,52,118,0.001,51,13,0.057,8,47,0.003,-15,14,0.003,-1,105,0.002,51,-2,0.074,32,-104,0.002,24,-13,0.000,8,-66,0.003,6,-10,0.024,33,98,0.001,-5,23,0.007,-33,116,0.017,46,-118,0.002,42,-3,0.009,37,14,0.027,-5,-56,0.001,-29,154,0.014,22,83,0.076,52,34,0.007,13,25,0.010,24,112,0.067,-14,-73,0.010,20,-13,0.001,56,78,0.001,47,42,0.006,44,28,0.018,0,10,0.018,61,-149,0.011,20,34,0.001,34,-91,0.003,-4,40,0.030,-23,-42,0.053,44,-85,0.006,62,31,0.001,38,33,0.018,37,82,0.002,14,-5,0.007,10,-14,0.008,-9,20,0.002,61,73,0.004,38,-108,0.001,34,7,0.008,49,31,0.021,11,-72,0.010,48,-58,0.001,-19,-48,0.017,48,21,0.028,26,77,0.098,44,88,0.013,40,128,0.029,2,-57,0.002,38,110,0.019,35,-112,0.000,16,6,0.001,-22,-63,0.002,12,9,0.107,63,58,0.001,59,55,0.002,40,15,0.145,35,41,0.017,-8,35,0.010,26,-81,0.024,-31,-68,0.001,40,-98,0.004,39,117,0.312,50,40,0.010,27,119,0.041,26,34,0.002,41,88,0.001,3,41,0.003,-21,35,0.005,51,94,0.001,50,-105,0.001,45,44,0.005,7,-75,0.008,6,80,0.063,21,34,0.001,-6,34,0.007,-33,-58,0.006,-4,-39,0.015,-35,143,0.002,28,25,0.001,8,4,0.029,45,-118,0.002,41,-109,0.001,55,52,0.011,51,57,0.002,32,5,0.002,31,46,0.016,-9,-46,0.001,4,14,0.003,-8,147,0.005,-16,-39,0.009,21,101,0.013,18,-71,0.030,-3,-40,0.004,31,95,0.002,46,27,0.035,43,135,0.001,55,86,0.004,-2,39,0.013,46,-90,0.001,57,53,0.003,37,50,0.055,-39,144,0.001,28,85,0.025,-4,-46,0.003,22,111,0.158,56,67,0.004,37,-105,0.001,34,103,0.003,52,62,0.003,13,-3,0.012,9,2,0.024,46,136,0.000,43,-78,0.022,-4,136,0.003,-34,-62,0.004,0,26,0.019,37,-120,0.020,-23,49,0.001,47,62,0.001,43,67,0.001,23,56,0.005,-26,-48,0.011,15,109,0.077,-23,-62,0.000,10,-61,0.043,47,143,0.006,44,-121,0.004,62,75,0.002,58,66,0.002,38,61,0.003,35,137,0.220,37,102,0.018,-20,-48,0.012,15,-2,0.003,11,3,0.008,10,38,0.060,14,29,0.001,5,-75,0.053,1,-70,0.000,38,-80,0.003,53,66,0.002,49,27,0.020,25,33,0.057,2,28,0.012,1,39,0.001,-18,-41,0.009,-3,100,0.000,26,113,0.169,40,100,0.003,36,31,0.013,16,-22,0.001,50,106,0.001,12,37,0.011,-12,27,0.011,59,19,0.034,39,72,0.004,35,69,0.012,-7,146,0.014,29,115,0.076,7,119,0.000,-1,100,0.003,54,45,0.006,50,76,0.001,30,71,0.050,26,54,0.001,7,8,0.049,2,96,0.001,51,138,0.000,-3,-77,0.001,-7,-80,0.002,45,16,0.017,-25,-66,0.000,36,107,0.027,-3,36,0.006,-7,-35,0.031,30,81,0.004,45,-99,0.000,42,129,0.010,60,36,0.001,-29,-61,0.001,32,58,0.000,31,-95,0.004,28,53,0.009,8,40,0.053,-16,30,0.006,55,24,0.013,-3,130,0.001,42,-93,0.005,4,-6,0.006,18,-67,0.015,-1,33,0.002,-2,-60,0.001,-22,33,0.003,66,60,0.000,46,55,0.001,45,84,0.002,42,70,0.024,22,73,0.204,18,48,0.002,13,-61,0.005,9,-64,0.014,-11,-55,0.002,57,65,0.002,37,70,0.033,33,71,0.047,28,113,0.230,9,13,0.029,-11,-38,0.011,-18,-62,0.011,-15,19,0.000,56,39,0.018,34,139,0.029,-4,-62,0.001,43,-114,0.001,24,56,0.025,20,59,0.001,23,92,0.277,34,-83,0.017,15,81,0.049,11,14,0.046,10,-73,0.022,25,95,0.028,-13,40,0.004,37,138,0.003,34,64,0.006,49,106,0.001,10,74,0.001,-19,-57,0.002,53,54,0.003,49,55,0.001,48,-2,0.015,29,68,0.011,44,129,0.017,25,61,0.003,5,74,0.001,39,-118,0.001,35,-121,0.000,-19,24,0.001,49,-56,0.000,48,77,0.000,-12,-56,0.000,-32,-61,0.007,40,72,0.094,39,-101,0.001,36,75,0.016,50,110,0.000,11,106,0.103,5,96,0.030,39,44,0.016,36,-102,0.000,35,49,0.021,30,-92,0.014,29,87,0.001,7,27,0.001,-17,37,0.010,54,41,0.004,53,122,0.001,30,19,0.001,6,21,0.001,17,-90,0.002,12,110,0.036,-27,-51,0.008,41,45,0.068,21,58,0.000,18,80,0.116,51,-105,0.000,-21,-69,0.001,-6,-38,0.009,45,-63,0.003,42,117,0.007,4,-72,0.003,52,91,0.001,54,86,0.003,-41,-64,0.001,32,14,0.060,55,-4,0.066,31,38,0.007,-11,32,0.005,9,126,0.022,42,-105,0.000,18,-95,0.021,33,133,0.038,66,32,0.000,45,120,0.005,42,42,0.015,4,101,0.021,6,8,0.143,13,-89,0.130,46,-82,0.001,-14,33,0.018,57,29,0.010,0,116,0.002,52,23,0.016,47,-92,0.002,24,101,0.039,34,111,0.088,47,-123,0.003,-4,13,0.004,-24,-48,0.012,44,-80,0.005,43,27,0.021,58,7,0.002,-37,-59,0.002,-38,-57,0.014,47,103,0.001,-46,-71,0.001,61,40,0.001,58,-134,0.001,-4,107,0.001,49,134,0.001,48,-109,0.001,29,-9,0.014,20,84,0.074,-18,16,0.013,53,26,0.014,48,34,0.020,29,40,0.002,44,93,0.001,5,30,0.002,29,-107,0.002,63,21,0.002,40,44,0.021,39,-1,0.006,35,4,0.018,16,34,0.007,26,-100,0.003,59,11,0.034,39,16,0.003,17,100,0.026,50,1,0.014,27,90,0.016,41,123,0.121,53,78,0.002,-9,142,0.001,-21,-41,0.022,60,45,0.001,41,25,0.014,36,115,0.299,32,131,0.075,-7,37,0.018,42,89,0.003,41,-86,0.022,52,119,0.001,51,20,0.059,8,48,0.003,-1,104,0.014,51,-3,0.063,32,-95,0.012,8,-65,0.003,18,5,0.000,33,97,0.002,-5,22,0.007,42,-2,0.020,37,13,0.013,-1,-54,0.001,-2,123,0.005,-29,153,0.002,-4,113,0.001,57,9,0.001,37,-2,0.006,52,35,0.005,13,28,0.005,47,-104,0.001,46,105,0.000,-11,18,0.006,-14,-72,0.012,-33,138,0.001,-34,-69,0.004,47,41,0.027,20,35,0.000,19,80,0.056,34,-90,0.006,-4,41,0.006,-23,-43,0.361,44,-84,0.004,62,32,0.000,38,34,0.017,35,100,0.001,37,81,0.005,15,41,0.000,14,-4,0.013,-9,19,0.002,-46,-67,0.002,61,76,0.002,38,-111,0.000,34,8,0.013,49,34,0.023,11,-73,0.008,48,-57,0.001,5,8,0.222,14,15,0.002,-13,-55,0.002,1,14,0.001,16,120,0.009,-22,47,0.012,48,22,0.034,26,78,0.111,44,89,0.006,40,121,0.060,38,115,0.236,35,-113,0.001,16,7,0.001,-22,-62,0.001,12,10,0.070,60,77,0.011,59,54,0.001,40,16,0.025,-20,-42,0.027,-8,36,0.010,26,-80,0.090,7,82,0.044,6,-77,0.001,40,-97,0.002,39,116,0.145,16,-91,0.010,50,37,0.049,27,118,0.035,41,87,0.004,3,32,0.025,-1,102,0.015,-21,34,0.006,51,93,0.001,50,-104,0.007,45,43,0.009,7,-76,0.010,3,-71,0.000,21,33,0.001,-6,31,0.010,-35,-63,0.001,60,73,0.002,17,11,0.001,-39,-66,0.001,8,-3,0.007,45,-119,0.002,55,51,0.007,51,48,0.006,32,6,0.001,31,45,0.015,27,50,0.000,4,15,0.004,-16,-38,0.001,21,104,0.025,18,-70,0.068,31,94,0.001,65,-18,0.001,46,28,0.024,43,134,0.002,55,85,0.006,-2,40,0.001,69,34,0.008,46,-85,0.000,57,56,0.004,19,-87,0.001,37,49,0.016,-39,143,0.002,33,46,0.019,10,79,0.177,28,86,0.010,-10,14,0.032,-2,10,0.002,22,112,0.109,56,68,0.001,37,-94,0.008,34,104,0.012,52,63,0.003,-12,-65,0.002,13,0,0.018,47,-68,0.002,9,1,0.014,46,133,0.012,43,-79,0.189,0,27,0.001,37,-121,0.084,-30,-51,0.092,67,64,0.001,43,66,0.001,23,55,0.006,-36,-59,0.004,-23,-63,0.003,-24,24,0.000,44,-120,0.001,25,86,0.470,58,63,0.001,38,62,0.005,35,128,0.062,37,101,0.002,15,-3,0.007,11,2,0.007,10,19,0.003,5,-72,0.013,1,-71,0.000,38,-83,0.007,53,65,0.002,14,103,0.046,2,25,0.003,1,42,0.004,-18,-40,0.006,48,58,0.001,26,114,0.078,25,-111,0.001,39,-74,0.035,36,32,0.008,50,103,0.000,12,38,0.049,-42,-71,0.004,-12,28,0.040,59,18,0.035,39,71,0.006,35,76,0.022,-7,145,0.010,30,-107,0.003,29,110,0.054,7,118,0.001,54,46,0.018,-10,-75,0.003,50,73,0.005,-12,-45,0.002,30,72,0.156,26,67,0.006,7,7,0.061,51,137,0.000,-27,-68,0.001,45,15,0.013,22,82,0.049,36,108,0.021,-3,35,0.020,30,82,0.001,64,-22,0.001,45,-96,0.001,42,130,0.035,60,37,0.001,17,-25,0.001,54,95,0.001,32,59,0.003,31,-96,0.003,28,54,0.013,8,33,0.007,-16,31,0.003,55,23,0.008,-3,129,0.001,42,-92,0.008,18,-66,0.091,-1,32,0.052,46,56,0.000,45,83,0.003,22,74,0.203,18,45,0.002,9,-65,0.006,-11,-52,0.000,-15,-59,0.001,57,68,0.001,37,69,0.034,52,-4,0.004,33,74,0.148,28,114,0.140,9,16,0.019,43,-124,0.002,-11,-39,0.008,-15,22,0.001,56,40,0.006,34,140,0.005,-4,-61,0.001,43,-115,0.001,24,49,0.002,-23,16,0.000,-5,153,0.003,-28,-67,0.000,23,91,0.844,1,119,0.001,34,-82,0.031,15,80,0.062,11,13,0.009,10,-72,0.013,25,98,0.010,-13,39,0.001,58,35,0.003,37,137,0.003,34,61,0.006,14,37,0.007,49,105,0.003,-9,111,0.016,-19,-62,0.001,53,53,0.005,49,58,0.001,48,-1,0.030,29,67,0.011,44,130,0.042,25,64,0.005,5,73,0.000,39,-119,0.015,-19,23,0.000,49,-57,0.000,-12,-55,0.003,-32,-60,0.025,40,65,0.012,39,-102,0.000,36,76,0.010,50,139,0.000,11,105,0.107,-24,-47,0.070,39,43,0.016,36,-101,0.001,54,-1,0.073,30,-95,0.026,29,82,0.022,-17,20,0.000,54,42,0.006,53,121,0.000,6,22,0.001,17,-91,0.010,-27,-48,0.024,41,48,0.012,21,57,0.001,18,77,0.105,17,54,0.003,-6,-41,0.002,27,-112,0.000,45,-60,0.002,42,118,0.014,4,-71,0.001,55,-118,0.002,52,92,0.001,54,91,0.001,32,15,0.016,31,4,0.002,55,-5,0.001,51,-8,0.011,31,37,0.025,9,125,0.021,42,-104,0.001,18,-94,0.018,33,136,0.011,45,119,0.001,4,102,0.035,19,-72,0.078,-14,34,0.065,57,32,0.002,0,109,0.007,52,24,0.016,33,38,0.018,47,-93,0.002,24,102,0.026,-9,17,0.006,-4,127,0.003,34,112,0.084,-3,151,0.001,33,-109,0.000,-5,140,0.004,-24,-70,0.002,44,34,0.018,43,9,0.002,-25,-63,0.001,-4,14,0.003,44,-79,0.020,43,26,0.022,58,8,0.003,15,52,0.001,11,73,0.001,47,102,0.001,61,39,0.000,-4,108,0.001,49,133,0.000,-8,140,0.001,20,101,0.012,-18,13,0.000,53,25,0.014,-3,105,0.051,-23,167,0.003,48,35,0.036,29,39,0.001,44,94,0.001,5,29,0.002,29,-104,0.001,63,36,0.000,-2,100,0.000,40,37,0.027,39,-2,0.006,35,3,0.022,16,35,0.005,50,143,0.001,-7,108,0.464,-8,25,0.005,26,-103,0.002,59,10,0.007,17,99,0.010,54,-5,0.024,-1,-90,0.000,50,2,0.018,12,-83,0.001,27,89,0.033,-22,-44,0.010,41,110,0.006,54,-122,0.000,53,77,0.001,-35,-68,0.002,-25,-57,0.001,-21,-42,0.021,60,46,0.001,41,28,0.021,-29,-52,0.015,36,116,0.237,32,132,0.022,14,125,0.000,-7,40,0.091,42,90,0.003,41,-87,0.188,51,19,0.025,55,-1,0.019,51,4,0.042,32,-94,0.011,8,-64,0.007,18,6,0.001,33,100,0.001,-5,21,0.006,48,93,0.000,42,11,0.004,37,16,0.033,-1,-55,0.001,-2,124,0.004,-5,-58,0.001,22,81,0.041,56,57,0.003,37,-3,0.030,52,36,0.008,13,27,0.005,-10,-62,0.002,-11,17,0.007,-14,-75,0.004,-34,-68,0.008,-5,104,0.021,47,40,0.056,-11,162,0.001,20,36,0.000,19,79,0.057,34,-93,0.004,-24,45,0.007,-9,161,0.002,62,29,0.002,38,39,0.023,-38,145,0.041,15,40,0.016,14,-7,0.003,47,138,0.000,-33,28,0.028,34,5,0.013,49,33,0.019,11,-74,0.016,-9,-61,0.000,1,13,0.001,46,-108,0.000,16,97,0.159,-22,48,0.029,48,23,0.031,26,91,0.132,44,90,0.004,40,122,0.009,38,116,0.246,35,-114,0.003,16,8,0.000,-22,-65,0.003,12,11,0.043,59,53,0.001,40,9,0.013,-8,29,0.004,7,81,0.166,-31,-66,0.001,6,-76,0.007,40,-96,0.011,39,115,0.046,16,-90,0.006,50,38,0.008,27,117,0.069,26,32,0.133,41,90,0.002,3,31,0.033,-21,33,0.016,50,-107,0.001,45,38,0.008,7,-77,0.002,21,36,0.000,-14,-43,0.005,-3,26,0.004,-6,32,0.008,8,-2,0.010,45,-116,0.000,55,50,0.039,51,47,0.023,32,7,0.001,31,60,0.001,27,49,0.002,4,16,0.005,21,103,0.006,18,-73,0.034,-20,22,0.000,-36,140,0.001,31,93,0.002,46,25,0.027,43,133,0.013,-34,139,0.001,55,84,0.011,-2,37,0.123,69,33,0.002,46,-84,0.004,57,55,0.006,19,-96,0.066,-39,146,0.018,33,45,0.230,10,80,0.148,28,87,0.002,-10,19,0.002,14,100,0.031,22,109,0.107,56,61,0.059,37,-95,0.004,34,101,0.001,52,64,0.003,-36,-67,0.002,13,-1,0.025,47,-69,0.002,9,4,0.008,46,134,0.008,43,-72,0.007,0,28,0.002,67,63,0.000,0,7,0.004,23,54,0.006,-23,-60,0.001,10,-63,0.022,25,85,0.357,58,64,0.001,38,67,0.016,35,127,0.090,37,104,0.021,-4,117,0.006,11,1,0.011,10,20,0.003,5,-73,0.037,38,-82,0.016,53,68,0.002,14,104,0.046,29,58,0.005,-28,-48,0.036,25,35,0.002,2,26,0.003,1,41,0.003,-18,-43,0.003,49,-114,0.001,48,59,0.000,26,111,0.066,63,-21,0.001,25,-108,0.019,40,94,0.002,39,-75,0.102,36,33,0.019,50,104,0.001,12,39,0.027,-21,-50,0.014,59,17,0.011,39,70,0.013,35,75,0.023,-7,148,0.003,30,-106,0.000,29,109,0.060,40,-124,0.003,54,51,0.005,51,143,0.000,50,74,0.006,30,69,0.010,26,68,0.036,7,6,0.108,51,128,0.000,-7,-78,0.022,-27,-69,0.001,36,93,0.000,-3,30,0.139,30,103,0.012,64,-21,0.005,45,-97,0.001,42,127,0.039,60,38,0.001,54,96,0.001,32,60,0.003,31,-97,0.019,28,55,0.008,8,34,0.006,-16,32,0.002,55,22,0.016,9,100,0.017,42,-95,0.003,18,-101,0.005,-1,31,0.069,-17,-44,0.007,66,58,0.002,45,78,0.001,22,47,0.005,18,46,0.001,9,-62,0.007,-11,-53,0.001,-14,27,0.002,-15,-56,0.002,57,67,0.001,-16,-61,0.000,37,72,0.004,33,73,0.108,28,115,0.073,9,15,0.018,-11,-36,0.013,-15,21,0.001,56,33,0.002,37,-75,0.002,34,137,0.075,-4,-60,0.006,-33,-52,0.007,44,71,0.000,43,-108,0.001,24,50,0.002,-9,35,0.016,20,45,0.005,-23,15,0.002,-30,-54,0.004,43,29,0.006,23,90,0.386,1,122,0.003,15,79,0.066,11,20,0.001,10,-75,0.039,25,97,0.008,-4,-49,0.004,58,36,0.002,37,140,0.044,34,62,0.005,49,108,0.001,14,34,0.041,-19,-63,0.009,53,56,0.009,49,57,0.001,48,0,0.016,29,62,0.002,44,131,0.012,25,63,0.005,39,-120,0.003,-19,18,0.001,49,-54,0.001,14,123,0.018,-12,-54,0.001,25,-80,0.086,-32,-67,0.001,40,66,0.018,-36,-64,0.001,36,61,0.027,50,140,0.000,11,80,0.200,39,42,0.014,36,-100,0.001,54,0,0.010,50,-5,0.008,30,-94,0.010,29,81,0.042,14,80,0.072,-17,19,0.000,53,124,0.001,30,17,0.001,-22,-42,0.023,6,27,0.001,17,-88,0.004,-35,-54,0.005,-27,-49,0.029,45,46,0.001,41,47,0.014,21,60,0.001,18,78,0.098,36,137,0.060,51,-107,0.000,-6,-40,0.006,27,-113,0.001,45,-61,0.001,55,-119,0.001,52,77,0.007,54,92,0.001,32,16,0.004,31,3,0.001,55,-6,0.004,51,-9,0.002,31,116,0.089,-2,-48,0.074,18,-97,0.047,33,135,0.009,-24,134,0.001,66,30,0.000,4,103,0.004,19,-73,0.007,-1,-76,0.003,33,-8,0.012,-14,31,0.003,57,31,0.002,0,110,0.024,52,25,0.009,33,37,0.028,47,-94,0.002,24,103,0.084,23,-100,0.005,-15,49,0.006,-48,-68,0.000,34,109,0.219,33,-106,0.000,-5,139,0.002,-24,-69,0.001,44,35,0.022,46,142,0.001,-10,160,0.003,-4,15,0.002,47,4,0.011,44,-78,0.010,43,25,0.023,23,94,0.009,15,51,0.003,47,101,0.001,-13,50,0.005,61,34,0.001,49,136,0.000,48,-115,0.001,20,102,0.007,-18,14,0.000,53,28,0.065,48,36,0.041,29,34,0.000,44,95,0.000,5,32,0.003,29,-105,0.001,63,35,0.001,40,38,0.032,39,-3,0.012,35,2,0.025,16,36,0.010,50,144,0.000,-7,107,0.833,-8,26,0.005,26,-102,0.002,-12,-43,0.002,59,9,0.001,40,-75,0.110,5,120,0.004,17,102,0.021,54,-4,0.003,50,-1,0.053,27,96,0.082,41,109,0.009,51,87,0.003,53,80,0.002,41,-2,0.003,-21,-43,0.022,60,47,0.002,41,27,0.016,-7,39,0.014,42,87,0.005,41,-84,0.011,3,109,0.001,52,121,0.001,51,18,0.036,-3,11,0.001,28,-17,0.003,4,37,0.002,55,-2,0.009,51,3,0.013,32,-93,0.015,8,-71,0.025,33,99,0.001,-5,28,0.004,-6,125,0.000,42,12,0.012,-11,41,0.007,37,15,0.034,6,9,0.067,-2,121,0.008,-5,-59,0.000,-25,-46,0.010,61,130,0.002,57,11,0.006,56,58,0.004,37,0,0.010,52,53,0.006,13,22,0.003,-11,20,0.001,-14,-74,0.009,-34,-71,0.036,56,105,0.001,-5,103,0.007,47,39,0.028,44,-1,0.004,19,78,0.106,34,-92,0.021,-23,-41,0.009,-24,46,0.004,-9,160,0.000,62,30,0.003,-33,-54,0.002,38,40,0.022,37,83,0.001,15,39,0.045,14,-6,0.004,47,137,0.000,-9,120,0.003,61,70,0.001,-33,27,0.007,38,-105,0.002,34,6,0.009,26,-11,0.000,49,36,0.011,48,-79,0.002,-9,-62,0.000,1,16,0.001,16,98,0.064,-22,45,0.002,-9,125,0.006,48,24,0.022,26,92,0.177,44,91,0.003,40,123,0.116,38,113,0.075,35,-115,0.002,16,-15,0.007,-22,-64,0.008,12,12,0.011,63,55,0.001,60,79,0.002,59,60,0.002,40,10,0.008,36,5,0.077,30,-81,0.036,-8,30,0.006,26,-82,0.005,7,80,0.060,-31,-67,0.000,40,-103,0.002,39,114,0.047,16,-89,0.006,50,35,0.021,-22,-41,0.025,41,89,0.001,3,30,0.005,45,37,0.008,21,35,0.000,-17,-68,0.030,-3,25,0.004,-6,29,0.005,-7,-42,0.005,32,97,0.002,8,-1,0.008,45,-117,0.001,-35,25,0.002,55,49,0.017,51,46,0.027,32,8,0.004,31,59,0.002,28,11,0.000,27,56,0.009,4,17,0.004,21,82,0.144,18,-72,0.124,-20,23,0.000,31,108,0.135,46,26,0.014,-4,145,0.000,55,83,0.026,-2,38,0.065,69,36,0.001,-21,-46,0.009,46,-87,0.002,57,58,0.002,19,-97,0.057,37,51,0.012,-39,145,0.008,33,48,0.018,10,77,0.325,28,88,0.001,9,38,0.038,-10,20,0.001,-9,26,0.005,22,110,0.131,56,62,0.013,37,-92,0.005,34,102,0.002,52,65,0.001,13,-6,0.017,47,-70,0.002,9,3,0.010,43,-73,0.010,0,21,0.003,43,72,0.003,-11,149,0.000,23,53,0.005,15,122,0.027,-24,18,0.001,10,-62,0.005,14,47,0.008,25,88,0.293,58,61,0.005,38,68,0.026,37,103,0.026,11,8,0.093,10,17,0.009,38,-77,0.088,53,67,0.002,14,101,0.111,29,57,0.005,14,20,0.002,2,23,0.014,1,44,0.007,-18,-42,0.007,-22,17,0.001,49,-115,0.001,26,112,0.114,63,-22,0.001,25,-109,0.005,40,95,0.002,39,-76,0.103,36,34,0.028,38,141,0.082,12,40,0.036,-8,148,0.002,-12,14,0.001,59,24,0.001,39,69,0.013,35,74,0.030,-7,147,0.007,29,112,0.116,54,52,0.003,50,71,0.001,30,70,0.010,26,65,0.005,7,5,0.137,-20,32,0.014,51,127,0.001,-3,-80,0.068,-19,-46,0.008,-7,-79,0.040,41,70,0.138,36,94,0.000,-3,29,0.063,-35,-64,0.001,30,104,0.189,42,128,0.017,60,39,0.001,21,-88,0.003,54,93,0.001,32,53,0.040,31,-98,0.002,28,56,0.005,8,35,0.015,-26,-51,0.009,-16,41,0.008,31,15,0.001,9,99,0.009,42,-94,0.004,18,-100,0.017,-1,30,0.040,33,110,0.043,5,-7,0.007,46,54,0.001,45,77,0.001,42,49,0.005,22,48,0.005,18,75,0.100,9,-63,0.012,-11,-58,0.000,-14,28,0.005,-15,-57,0.003,57,22,0.002,37,71,0.012,33,76,0.050,28,116,0.185,9,18,0.009,-11,-37,0.036,-15,24,0.003,56,34,0.001,34,138,0.091,-4,-59,0.006,44,72,0.000,24,51,0.002,20,46,0.005,-20,148,0.001,-23,18,0.007,23,89,0.386,1,121,0.002,15,78,0.095,14,-89,0.050,11,19,0.002,10,-74,0.071,25,100,0.034,-13,37,0.001,58,33,0.002,37,139,0.044,34,59,0.005,49,107,0.003,-18,39,0.002,-19,-60,0.001,53,55,0.003,49,60,0.000,48,9,0.079,29,61,0.006,44,132,0.006,25,66,0.003,39,-121,0.014,-19,17,0.002,49,-55,0.001,48,80,0.000,29,-82,0.018,25,-81,0.001,-32,-66,0.001,40,67,0.013,39,-104,0.044,36,62,0.005,50,137,0.004,11,79,0.173,39,41,0.010,36,-115,0.043,54,-3,0.011,50,-4,0.021,29,84,0.001,-17,18,0.001,54,16,0.004,53,123,0.001,30,18,0.001,6,28,0.002,17,-89,0.003,50,-66,0.001,64,25,0.002,45,45,0.002,41,50,0.001,21,59,0.002,18,107,0.009,36,138,0.048,51,-100,0.001,-6,-43,0.006,45,-66,0.005,55,-120,0.001,52,78,0.009,54,89,0.000,31,2,0.001,4,74,0.003,55,-7,0.003,-4,140,0.002,32,-64,0.002,31,115,0.164,9,127,0.005,46,7,0.055,42,-106,0.002,18,-96,0.047,66,27,0.000,-29,33,0.010,4,104,0.011,-15,-170,0.002,-1,-77,0.004,-5,-80,0.019,46,-79,0.003,-14,32,0.008,57,34,0.004,0,111,0.012,52,26,0.010,33,40,0.004,47,-95,0.001,9,46,0.004,14,41,0.008,24,104,0.060,23,-101,0.002,34,110,0.252,33,-107,0.000,-5,138,0.001,44,36,0.001,-4,16,0.026,47,3,0.016,44,-77,0.006,62,23,0.004,23,93,0.028,38,9,0.000,0,-60,0.000,15,50,0.006,47,84,0.002,-46,-72,0.001,-13,49,0.000,61,33,0.001,15,-61,0.004,49,135,0.001,48,-114,0.002,20,103,0.008,-18,19,0.001,53,27,0.010,48,29,0.013,29,33,0.013,5,31,0.002,35,-88,0.009,29,-110,0.003,63,34,0.000,-13,132,0.000,40,39,0.021,39,-4,0.008,35,1,0.045,16,29,0.001,-8,27,0.008,26,-105,0.002,-12,-42,0.003,40,-74,0.251,17,101,0.024,54,-7,0.010,50,0,0.030,12,-81,0.002,27,95,0.061,41,112,0.019,51,86,0.002,53,79,0.004,41,-3,0.003,54,-101,0.000,58,9,0.005,60,48,0.001,41,14,0.033,42,88,0.002,41,-85,0.027,3,116,0.001,52,122,0.001,51,17,0.041,28,-16,0.024,4,38,0.002,55,-3,0.039,51,2,0.020,32,-92,0.008,8,-70,0.014,55,110,0.001,33,102,0.001,-5,27,0.010,42,9,0.001,37,26,0.002,-2,122,0.003,-13,-40,0.006,-25,-47,0.008,-2,99,0.000,61,129,0.001,57,-2,0.014,56,59,0.003,37,-1,0.022,52,54,0.003,13,21,0.003,-10,-56,0.001,-11,19,0.003,23,-97,0.000,-34,-70,0.196,56,106,0.002,-3,142,0.000,47,38,0.054,44,0,0.037,19,77,0.088,34,-95,0.003,-24,47,0.004,10,-85,0.009,62,35,0.001,38,37,0.024,37,78,0.004,15,38,0.005,14,-17,0.099,47,136,0.001,62,-114,0.001,-33,26,0.002,38,-104,0.022,34,3,0.008,49,35,0.021,11,-68,0.001,48,-78,0.001,-9,-63,0.005,-13,-66,0.001,1,15,0.001,-18,47,0.003,16,99,0.016,-22,46,0.001,-3,104,0.013,26,89,0.222,44,92,0.001,40,124,0.046,-12,41,0.004,38,114,0.060,35,-108,0.002,16,-14,0.007,63,54,0.002,59,59,0.002,5,116,0.008,36,6,0.055,-8,31,0.004,-31,-64,0.004,40,-102,0.001,39,113,0.044,16,-88,0.002,50,36,0.010,-22,-51,0.011,41,92,0.001,3,29,0.003,45,40,0.031,-25,-62,0.001,-17,-69,0.010,-3,28,0.005,-6,30,0.005,-39,-68,0.007,-7,-43,0.004,-45,172,0.002,-29,-65,0.007,17,-16,0.001,32,98,0.002,8,0,0.011,45,-122,0.065,55,48,0.012,51,45,0.003,-3,122,0.005,31,58,0.004,28,12,0.000,27,55,0.005,4,18,0.004,5,6,0.058,21,81,0.081,-20,24,0.001,-39,-58,0.002,31,107,0.182,46,15,0.034,55,82,0.001,-8,-78,0.021,69,35,0.001,-25,36,0.007,5,-1,0.052,46,-86,0.000,57,57,0.015,19,-98,0.272,37,46,0.044,-39,148,0.001,33,47,0.014,10,78,0.136,28,89,0.002,9,37,0.023,-10,17,0.006,-18,-66,0.034,22,115,0.449,56,63,0.007,37,-93,0.013,52,66,0.001,13,-7,0.012,47,-71,0.001,9,-10,0.008,43,-74,0.003,-22,-55,0.002,0,22,0.003,43,71,0.003,23,52,0.002,15,121,0.169,10,-65,0.002,44,-117,0.001,25,87,0.348,58,62,0.001,38,65,0.004,37,114,0.053,15,10,0.001,11,7,0.028,10,18,0.006,38,-76,0.047,53,62,0.002,14,102,0.039,29,60,0.005,-2,107,0.003,2,24,0.005,1,43,0.005,49,-112,0.004,48,53,0.000,26,109,0.045,40,96,0.001,39,-77,0.053,36,35,0.013,38,142,0.029,35,-80,0.051,50,102,0.000,12,41,0.018,-12,15,0.007,39,68,0.038,35,73,0.056,29,111,0.056,54,49,0.022,50,72,0.001,30,75,0.139,-33,-63,0.007,26,66,0.002,7,4,0.118,51,126,0.001,-7,-76,0.013,45,76,0.000,41,69,0.011,36,95,0.000,-21,148,0.000,-3,32,0.023,30,101,0.002,42,125,0.042,60,40,0.001,21,-89,0.017,54,94,0.001,32,54,0.006,-17,-43,0.010,31,-99,0.001,28,57,0.004,8,36,0.033,-22,-46,0.024,-3,126,0.001,31,14,0.001,42,-97,0.003,18,-103,0.006,-1,29,0.011,33,109,0.041,-6,147,0.002,45,80,0.002,-11,34,0.006,22,45,0.005,18,76,0.069,6,4,0.299,-11,-59,0.000,-14,25,0.002,-15,-54,0.001,-10,-74,0.001,33,75,0.085,28,117,0.136,9,17,0.014,-11,-42,0.002,-15,23,0.002,56,35,0.005,34,135,0.112,-4,-58,0.002,43,-110,0.001,24,52,0.002,20,47,0.005,-23,17,0.001,13,110,0.045,23,88,0.238,15,77,0.107,14,-88,0.029,11,18,0.004,25,99,0.034,-13,44,0.001,58,34,0.002,-46,171,0.005,34,60,0.006,-37,143,0.001,-19,-61,0.001,53,34,0.007,49,59,0.001,48,10,0.111,29,64,0.001,44,133,0.005,25,65,0.003,39,-122,0.003,35,-117,0.002,-19,20,0.002,68,14,0.000,48,89,0.002,29,-83,0.001,-32,-65,0.002,40,68,0.017,39,-105,0.037,36,63,0.003,16,74,0.044,50,138,0.008,11,78,0.166,-20,17,0.001,-13,-49,0.001,39,40,0.007,36,-114,0.003,54,-2,0.014,-41,-70,0.000,29,83,0.005,7,23,0.000,-17,17,0.002,54,13,0.013,53,118,0.001,30,39,0.001,8,80,0.006,64,26,0.004,45,48,0.002,-31,150,0.000,41,49,0.018,21,54,0.002,36,139,0.068,17,55,0.003,51,-101,0.000,-6,-42,0.027,45,-67,0.001,52,79,0.002,54,90,0.001,31,1,0.001,55,-8,0.000,31,114,0.133,46,8,0.034,19,76,0.108,18,-99,0.066,33,137,0.001,66,28,0.000,-29,24,0.002,45,116,0.000,-15,-171,0.000,19,-75,0.007,-1,-78,0.080,33,-6,0.068,-5,-81,0.004,-24,151,0.003,-14,29,0.012,-4,109,0.000,57,33,0.001,19,-154,0.000,0,112,0.009,52,27,0.010,33,39,0.005,47,-96,0.001,9,45,0.007,24,97,0.015,23,-102,0.006,-15,51,0.005,33,-104,0.002,-5,137,0.003,-9,30,0.006,-4,17,0.003,47,2,0.023,44,-76,0.008,62,24,0.002,15,49,0.005,47,83,0.001,62,7,0.004,14,35,0.007,-30,154,0.001,29,-13,0.001,-9,-68,0.001,20,104,0.006,-18,20,0.001,53,22,0.012,48,30,0.012,29,36,0.002,5,42,0.003,35,-89,0.030,48,109,0.000,29,-111,0.008,63,33,0.000,-37,144,0.001,-13,131,0.003,40,40,0.026,39,-5,0.005,-20,-46,0.006,16,30,0.001,-8,28,0.006,26,-104,0.001,-12,-41,0.010,40,-73,0.362,39,140,0.003,17,104,0.048,54,-6,0.024,50,-3,0.025,27,94,0.014,14,81,0.020,41,111,0.006,51,85,0.001,53,90,0.002,41,0,0.019,-35,-59,0.016,60,49,0.001,41,13,0.111,-1,133,0.000,-6,-70,0.000,42,85,0.002,41,-98,0.001,3,115,0.001,52,123,0.002,51,40,0.045,28,-15,0.017,4,39,0.003,-1,116,0.003,51,1,0.154,32,-99,0.006,8,-69,0.009,33,101,0.001,-5,26,0.002,-6,139,0.001,42,10,0.004,37,25,0.002,-1,-58,0.000,-2,111,0.007,-5,-53,0.000,-8,-56,0.001,-25,-48,0.008,61,132,0.000,22,88,0.312,56,60,0.007,37,10,0.012,52,55,0.002,13,24,0.009,46,93,0.000,-11,14,0.002,-14,-76,0.013,23,-98,0.002,47,37,0.008,44,1,0.016,-11,163,0.000,19,84,0.046,34,-94,0.002,-36,-63,0.003,-24,48,0.009,10,-84,0.035,-9,158,0.001,62,36,0.000,20,-90,0.004,38,38,0.021,37,77,0.007,15,37,0.010,14,-16,0.064,10,-5,0.013,47,135,0.003,-33,25,0.002,38,-107,0.002,34,4,0.010,49,38,0.012,11,-69,0.012,48,-77,0.001,-9,-64,0.001,1,18,0.001,-18,48,0.004,16,100,0.032,53,-6,0.052,26,90,0.196,40,117,0.257,2,-60,0.003,38,119,0.014,35,-109,0.001,16,-13,0.006,-22,-66,0.001,49,-124,0.005,63,53,0.001,59,58,0.002,36,7,0.075,35,36,0.019,30,-83,0.007,-8,32,0.007,-31,-65,0.001,6,-73,0.018,40,-101,0.000,39,112,0.024,50,33,0.012,27,122,0.004,26,43,0.004,41,91,0.001,3,36,0.004,-17,-151,0.001,-21,-66,0.001,45,39,0.023,7,-80,0.007,6,81,0.198,-17,-70,0.002,-3,27,0.006,-7,-40,0.004,60,13,0.001,32,99,0.002,8,-7,0.006,45,-123,0.006,55,47,0.008,51,52,0.010,-3,121,0.019,31,57,0.005,27,54,0.006,4,19,0.028,-8,107,0.030,-16,-42,0.005,21,84,0.094,18,-74,0.014,-1,136,0.001,-39,-59,0.003,31,106,0.150,46,16,0.065,-34,138,0.001,55,81,0.001,69,30,0.000,-25,35,0.012,46,-97,0.001,-11,40,0.026,57,60,0.012,19,-99,0.543,37,45,0.029,-39,147,0.003,33,50,0.018,28,90,0.003,9,40,0.043,-10,18,0.004,-47,170,0.000,-15,30,0.003,22,116,0.042,56,64,0.006,37,-98,0.001,34,100,0.001,52,67,0.002,13,-4,0.015,47,-72,0.001,9,-11,0.008,46,137,0.000,43,-75,0.013,24,41,0.004,0,23,0.004,43,70,0.003,-11,151,0.002,23,51,0.002,15,120,0.003,-24,20,0.000,10,-64,0.029,44,-116,0.001,25,90,0.372,38,66,0.024,37,113,0.148,15,9,0.001,11,6,0.023,10,15,0.044,-9,115,0.068,38,-79,0.004,53,61,0.003,49,66,0.000,29,59,0.005,25,56,0.027,5,49,0.000,2,21,0.011,1,46,0.001,6,125,0.060,49,-113,0.001,48,54,0.000,26,110,0.044,39,-78,0.010,36,36,0.017,-18,-149,0.006,35,-81,0.031,16,-25,0.001,50,99,0.000,12,42,0.003,-12,16,0.012,39,67,0.063,35,64,0.005,30,-103,0.000,39,84,0.001,54,50,0.006,50,69,0.001,30,76,0.166,26,63,0.006,7,3,0.034,51,125,0.001,-3,-54,0.006,-26,-50,0.015,-7,-77,0.006,-33,-61,0.007,45,75,0.000,41,72,0.035,-36,-66,0.001,8,126,0.040,36,96,0.000,-21,147,0.000,-3,31,0.080,30,102,0.003,-37,-64,0.004,45,-100,0.000,42,126,0.055,60,41,0.001,-35,138,0.000,54,99,0.001,32,55,0.003,31,-84,0.007,28,58,0.005,8,29,0.015,31,13,0.002,42,-96,0.007,18,-102,0.012,33,112,0.064,-6,148,0.001,65,14,0.000,46,60,0.000,45,79,0.005,42,47,0.009,22,46,0.005,18,73,0.075,-35,117,0.000,14,-10,0.005,9,-61,0.002,-11,-56,0.002,-14,26,0.001,-15,-55,0.001,57,24,0.001,-38,175,0.005,28,118,0.103,9,20,0.006,-11,-43,0.002,-9,21,0.001,-4,123,0.011,56,36,0.016,34,136,0.551,-4,-57,0.002,44,74,0.000,-17,32,0.014,43,-111,0.003,24,45,0.005,20,48,0.005,67,32,0.001,13,109,0.030,23,87,0.253,14,-91,0.080,11,17,0.007,25,118,0.071,58,31,0.002,34,57,0.001,49,77,0.000,10,51,0.001,-33,-62,0.004,-18,37,0.017,-19,-66,0.007,53,33,0.007,48,11,0.055,29,63,0.001,44,134,0.003,25,68,0.076,39,-123,0.003,1,74,0.000,35,-118,0.007,-19,19,0.001,68,15,0.001,48,90,0.001,29,-80,0.002,63,12,0.002,-32,-64,0.058,40,61,0.001,39,-106,0.003,36,64,0.004,16,75,0.210,50,135,0.000,11,77,0.166,39,39,0.010,-20,64,0.001,-41,-71,0.002,29,78,0.315,7,22,0.001,-17,16,0.002,54,14,0.009,30,40,0.002,-25,-53,0.017,-26,47,0.004,64,27,0.001,45,47,0.000,-29,-56,0.002,21,53,0.002,18,105,0.006,36,140,0.188,51,-102,0.001,27,-108,0.001,45,-64,0.003,52,80,0.002,31,0,0.001,51,-4,0.011,31,113,0.092,46,5,0.025,42,-124,0.001,19,75,0.110,18,-98,0.053,66,25,0.001,5,-8,0.012,42,19,0.010,57,115,0.001,-1,-79,0.025,33,-7,0.147,-24,152,0.001,-14,30,0.002,-18,-59,0.000,57,36,0.004,19,-155,0.004,0,121,0.010,52,28,0.010,33,42,0.004,47,-97,0.003,9,48,0.001,24,98,0.019,23,-103,0.008,33,-105,0.001,44,38,0.014,-4,18,0.010,13,81,0.205,47,1,0.028,44,-75,0.007,-13,-42,0.004,38,15,0.004,15,48,0.002,47,82,0.001,62,8,0.002,61,35,0.008,14,36,0.009,48,-112,0.000,-9,-69,0.000,-13,-72,0.003,20,105,0.014,-10,120,0.014,53,21,0.018,48,31,0.017,29,35,0.001,5,41,0.003,35,-90,0.015,29,-108,0.001,40,33,0.034,39,-6,0.009,16,31,0.001,-17,168,0.001,-8,21,0.003,26,-107,0.003,-12,-40,0.010,-32,19,0.002,40,-72,0.010,17,103,0.065,-55,-65,0.000,50,-2,0.014,27,93,0.005,41,114,0.030,51,92,0.001,53,89,0.004,-17,179,0.001,26,-9,0.000,41,-1,0.011,-30,18,0.002,60,50,0.000,41,16,0.027,-6,-73,0.001,27,-80,0.018,42,86,0.004,41,-99,0.001,3,114,0.005,52,124,0.001,51,39,0.007,32,-17,0.001,28,-14,0.001,4,40,0.002,22,-84,0.003,-1,115,0.004,32,-98,0.003,8,-68,0.002,6,-5,0.037,33,104,0.003,-5,25,0.004,-6,140,0.001,46,-124,0.000,19,-104,0.012,37,28,0.024,-2,112,0.002,-5,-54,0.000,-25,-49,0.008,61,131,0.000,-11,22,0.001,22,85,0.074,56,53,0.006,52,56,0.007,13,23,0.014,47,-61,0.000,-10,-58,0.000,23,-99,0.012,-38,-69,0.000,47,20,0.089,44,2,0.011,5,119,0.008,0,11,0.001,19,83,0.073,34,-97,0.005,-36,-57,0.007,62,33,0.000,20,-89,0.028,38,43,0.014,37,80,0.011,15,20,0.002,10,-4,0.010,47,134,0.009,38,-106,0.001,34,1,0.008,-38,146,0.064,49,37,0.049,11,-70,0.008,-8,108,0.153,-13,-60,0.001,1,17,0.000,-18,45,0.001,53,-7,0.008,26,87,0.245,40,118,0.086,-18,-64,0.003,35,-110,0.001,16,-12,0.004,-22,-53,0.001,49,-125,0.002,59,57,0.008,36,8,0.058,35,35,0.001,30,-82,0.005,-31,-62,0.002,6,-72,0.012,40,-100,0.001,39,111,0.017,50,34,0.011,27,121,0.141,26,44,0.007,41,78,0.001,3,35,0.007,2,118,0.004,51,120,0.000,50,-111,0.001,45,34,0.015,7,-81,0.002,6,82,0.027,3,-76,0.118,-17,-71,0.030,-3,22,0.001,-7,-41,0.004,58,6,0.007,60,14,0.001,-4,-38,0.098,17,-14,0.001,32,100,0.002,28,31,0.108,8,-6,0.007,-30,-59,0.005,-35,22,0.001,55,46,0.005,51,51,0.002,-33,-55,0.002,31,56,0.002,28,-114,0.001,27,53,0.004,4,20,0.006,-16,-41,0.006,21,83,0.089,18,-77,0.034,-1,135,0.001,-3,-41,0.004,-5,12,0.012,31,105,0.187,46,13,0.013,45,102,0.001,55,80,0.001,-2,41,0.003,-25,34,0.023,46,-96,0.007,57,59,0.001,37,48,0.014,33,49,0.028,28,91,0.002,9,39,0.111,-10,23,0.003,-47,169,0.003,-15,29,0.012,22,113,0.137,56,25,0.025,37,-99,0.001,34,97,0.001,52,68,0.001,13,-5,0.018,9,-8,0.009,46,138,0.000,24,42,0.004,-14,-171,0.004,-4,137,0.003,0,24,0.005,43,69,0.008,24,-103,0.009,23,50,0.002,1,98,0.014,-22,-40,0.001,10,-67,0.093,25,89,0.297,38,71,0.004,37,116,0.187,15,8,0.001,11,5,0.029,10,16,0.024,14,30,0.001,38,-78,0.015,53,64,0.013,14,108,0.011,29,54,0.026,2,22,0.010,1,45,0.024,-18,-39,0.008,48,55,0.000,39,-79,0.010,35,-82,0.019,16,-24,0.002,50,100,0.000,12,43,0.002,-12,17,0.012,39,66,0.018,35,63,0.004,30,-102,0.000,39,83,0.002,-1,99,0.001,54,55,0.007,50,70,0.000,30,73,0.197,26,64,0.006,7,2,0.026,-3,-55,0.001,41,71,0.013,36,97,0.000,30,107,0.254,60,42,0.001,-29,-62,0.002,54,100,0.001,32,56,0.001,31,-85,0.009,28,59,0.005,8,30,0.007,31,28,0.001,-1,43,0.020,33,111,0.045,-6,145,0.015,65,13,0.001,42,48,0.018,4,127,0.002,22,51,0.002,18,74,0.212,9,-74,0.017,-11,-57,0.001,-14,23,0.002,-15,-52,0.001,57,23,0.002,-39,178,0.001,28,119,0.089,9,19,0.007,43,-121,0.001,-11,-40,0.008,-15,25,0.003,56,29,0.003,34,133,0.086,-4,-56,0.001,-5,115,0.000,39,-103,0.000,44,75,0.001,24,46,0.005,20,49,0.002,-36,-72,0.004,-23,19,0.001,67,31,0.001,-28,29,0.004,24,-99,0.004,23,86,0.166,1,126,0.008,14,-90,0.141,11,24,0.006,25,117,0.054,61,26,0.003,58,32,0.010,-10,125,0.030,34,58,0.002,49,80,0.000,-8,157,0.000,-18,38,0.017,-19,-67,0.003,53,36,0.004,48,12,0.096,44,135,0.001,25,67,0.008,35,-119,0.015,68,16,0.001,49,-82,0.000,48,91,0.001,29,-81,0.017,63,11,0.007,-32,-55,0.003,40,62,0.001,39,-107,0.002,36,65,0.008,16,76,0.100,50,136,0.000,5,102,0.010,39,38,0.009,-41,-72,0.005,29,77,0.174,-17,15,0.002,54,19,0.044,53,120,0.000,30,37,0.001,6,31,0.007,64,28,0.001,-19,179,0.005,21,56,0.001,18,106,0.089,51,-103,0.000,-21,-70,0.004,27,-109,0.012,45,-65,0.003,42,95,0.002,-16,-71,0.002,52,81,0.002,-41,-65,0.000,31,-1,0.001,51,-5,0.001,31,112,0.053,46,6,0.017,19,74,0.203,66,26,0.002,-29,22,0.003,42,20,0.017,-11,29,0.005,19,-69,0.011,6,5,0.042,33,-4,0.018,57,35,0.005,0,122,0.005,52,13,0.021,33,41,0.004,13,46,0.021,47,-98,0.000,9,47,0.002,-10,-49,0.001,24,99,0.037,23,-104,0.008,33,-102,0.002,-28,-70,0.002,44,39,0.010,-4,19,0.009,47,0,0.027,44,-74,0.003,62,22,0.002,23,122,0.013,38,16,0.028,34,-117,0.086,15,47,0.003,11,52,0.000,47,81,0.001,-9,124,0.008,61,30,0.002,49,140,0.000,48,-103,0.001,-9,-70,0.001,-13,-73,0.003,20,106,0.178,-18,18,0.001,53,24,0.024,48,32,0.010,5,44,0.002,35,-91,0.005,-19,50,0.008,29,-109,0.001,63,31,0.000,40,34,0.022,39,-7,0.006,16,32,0.016,-8,22,0.006,26,-106,0.001,-12,-39,0.013,-32,20,0.000,40,-79,0.053,17,106,0.007,50,27,0.026,27,100,0.010,41,113,0.015,-21,48,0.024,51,91,0.001,53,92,0.016,-33,-68,0.028,-9,141,0.003,41,2,0.043,3,-57,0.001,-17,-60,0.000,-13,-46,0.002,60,51,0.000,41,15,0.043,-26,-69,0.001,27,-81,0.011,41,-96,0.016,3,113,0.000,52,109,0.001,51,38,0.016,32,-16,0.007,28,-13,0.003,27,32,0.058,4,41,0.003,-53,-72,0.000,-1,114,0.002,32,-97,0.064,8,-75,0.027,-4,141,0.001,19,38,0.011,33,103,0.002,-5,32,0.011,19,-105,0.001,37,27,0.002,-5,-55,0.001,-25,-50,0.008,-4,114,0.001,22,86,0.077,56,54,0.031,37,12,0.000,52,57,0.003,13,18,0.002,-10,-53,0.000,43,-65,0.001,-11,16,0.006,56,101,0.001,-38,-68,0.001,47,19,0.045,44,3,0.011,19,82,0.031,34,-96,0.003,-42,147,0.003,62,34,0.000,20,-88,0.006,38,44,0.013,37,79,0.002,15,19,0.001,10,-7,0.005,47,133,0.013,61,66,0.000,-33,23,0.001,38,-101,0.000,34,2,0.010,15,-92,0.027,49,40,0.006,11,-71,0.002,14,16,0.001,-13,-61,0.001,2,47,0.000,1,20,0.003,-18,46,0.002,53,-4,0.003,26,88,0.198,40,119,0.078,38,117,0.183,35,-111,0.003,-22,-52,0.002,12,-16,0.017,49,-122,0.043,63,67,0.001,36,9,0.034,35,34,0.012,-31,-63,0.001,6,-75,0.130,40,-107,0.001,39,110,0.011,14,43,0.007,53,159,0.009,50,31,0.120,26,41,0.002,41,77,0.002,3,34,0.008,2,115,0.001,-1,101,0.098,51,119,0.000,50,-110,0.002,12,93,0.003,45,33,0.001,3,-77,0.005,-17,-72,0.003,-3,21,0.001,-7,-38,0.018,-27,19,0.001,60,15,0.002,17,-15,0.004,32,93,0.001,28,32,0.002,8,-5,0.008,45,-121,0.002,-35,21,0.002,55,45,0.005,51,50,0.002,31,55,0.005,28,-113,0.002,27,60,0.002,-16,-40,0.008,21,78,0.067,18,-76,0.028,-1,134,0.002,-39,-57,0.008,31,104,0.055,46,14,0.020,43,112,0.001,55,79,0.004,-2,42,0.003,69,32,0.000,-25,33,0.006,46,-99,0.000,57,46,0.003,37,47,0.046,33,52,0.012,28,92,0.002,9,42,0.054,-10,24,0.003,-15,32,0.007,22,114,0.444,56,26,0.005,37,-96,0.002,34,98,0.000,-12,-64,0.001,13,-10,0.003,9,-9,0.010,46,127,0.068,43,-69,0.002,24,43,0.005,0,33,0.129,67,66,0.001,43,76,0.003,24,-102,0.001,23,49,0.003,10,-66,0.151,25,92,0.079,38,72,0.002,35,130,0.158,37,115,0.186,15,7,0.001,11,12,0.021,10,13,0.024,53,63,0.002,14,105,0.037,29,53,0.045,25,58,0.000,2,19,0.009,-41,177,0.001,68,37,0.001,39,-80,0.010,36,22,0.001,35,-83,0.014,12,44,0.002,5,5,0.001,-12,18,0.007,59,28,0.003,5,81,0.011,39,65,0.025,36,-91,0.003,35,62,0.005,39,82,0.006,54,56,0.014,50,67,0.003,30,74,0.199,26,61,0.006,7,1,0.025,-3,-52,0.001,-27,-62,0.001,41,74,0.010,22,87,0.152,36,98,0.000,30,108,0.173,42,140,0.001,60,43,0.001,-35,140,0.001,32,65,0.006,31,-86,0.004,28,60,0.003,8,31,0.005,-16,37,0.011,31,27,0.001,42,-98,0.001,22,-159,0.001,21,114,0.002,18,-104,0.000,-1,42,0.024,33,114,0.220,-6,146,0.005,42,45,0.019,22,52,0.002,9,-75,0.035,-14,24,0.002,-15,-53,0.001,57,26,0.005,-39,177,0.004,-26,154,0.001,10,109,0.010,28,120,0.060,43,-122,0.001,-11,-41,0.002,-15,28,0.007,56,30,0.002,34,134,0.099,-4,-55,0.001,44,76,0.001,24,47,0.005,-11,122,0.002,20,50,0.002,67,30,0.000,-28,30,0.006,-28,-66,0.001,43,40,0.008,24,-98,0.002,23,85,0.074,1,125,0.037,14,-85,0.006,11,23,0.004,25,120,0.111,-13,41,0.006,-32,117,0.004,61,25,0.005,58,29,0.001,34,55,0.002,-8,158,0.000,10,49,0.002,-37,148,0.001,-19,-64,0.003,53,35,0.025,48,5,0.014,29,25,0.001,44,136,0.002,68,17,0.001,48,92,0.000,63,10,0.001,25,-77,0.007,-32,-54,0.006,40,63,0.007,39,-108,0.004,36,66,0.012,-35,-60,0.007,-24,-46,0.695,5,101,0.079,39,37,0.012,36,-111,0.001,-21,-62,0.000,-41,-73,0.010,29,80,0.081,7,20,0.002,-17,14,0.002,54,20,0.012,53,119,0.000,-6,28,0.006,30,38,0.001,60,-151,0.001,6,32,0.007,-26,45,0.001,64,21,0.003,-31,151,0.001,41,38,0.004,21,55,0.002,18,103,0.021,51,-112,0.001,27,-110,0.005,64,12,0.001,45,-70,0.001,42,96,0.002,-16,-70,0.014,52,82,0.002,32,21,0.004,31,-2,0.001,31,111,0.035,46,11,0.008,19,73,0.473,18,-4,0.001,33,78,0.001,66,23,0.001,-29,21,0.001,42,17,0.000,19,-70,0.062,18,43,0.009,33,-5,0.032,-5,-76,0.001,22,95,0.026,0,123,0.016,37,-25,0.004,52,14,0.142,33,44,0.014,13,45,0.079,-44,172,0.001,47,-99,0.000,9,50,0.002,-10,-48,0.003,24,100,0.045,-9,16,0.008,23,-105,0.006,-4,128,0.004,8,10,0.028,-28,-69,0.001,44,40,0.016,-4,20,0.003,47,-1,0.038,44,-73,0.010,62,27,0.001,23,121,0.165,38,13,0.002,34,-116,0.004,15,46,0.005,14,7,0.021,11,51,0.002,47,80,0.001,-36,146,0.001,62,6,0.001,59,152,0.000,61,29,0.003,49,139,0.000,11,-60,0.002,-8,130,0.000,-9,-71,0.001,-13,-74,0.013,20,107,0.293,-37,176,0.001,53,23,0.014,-3,108,0.004,48,41,0.015,5,43,0.002,35,-84,0.018,-19,49,0.011,29,-114,0.002,63,30,0.001,40,35,0.015,39,-8,0.027,-8,23,0.009,-45,-67,0.001,14,99,0.010,-12,-38,0.013,40,-78,0.016,36,-83,0.014,17,105,0.037,50,28,0.014,27,99,0.004,-22,-47,0.037,41,116,0.016,-17,50,0.008,-21,47,0.009,51,90,0.001,53,91,0.002,-35,-69,0.001,-28,-51,0.011,41,1,0.013,3,-58,0.000,-25,-58,0.001,-17,-61,0.000,41,18,0.002,-29,-53,0.010,-6,-75,0.001,-7,30,0.005,-26,-68,0.001,27,-82,0.065,41,-97,0.003,3,104,0.013,52,110,0.000,51,37,0.020,32,-7,0.032,27,31,0.086,4,42,0.002,-1,113,0.003,32,-96,0.088,46,39,0.009,8,-74,0.010,19,37,0.001,33,106,0.039,-5,31,0.025,-34,148,0.001,37,22,0.009,-2,110,0.003,-25,-51,0.008,-18,-54,0.001,22,91,0.316,-26,-49,0.095,56,55,0.010,37,11,0.005,52,58,0.001,13,17,0.001,43,-66,0.000,-11,15,0.006,56,102,0.010,-38,-71,0.003,-5,106,0.051,47,18,0.025,44,4,0.005,23,44,0.005,19,81,0.018,34,-99,0.002,-23,-50,0.013,44,-109,0.000,62,55,0.001,20,-87,0.006,38,41,0.023,15,18,0.001,14,-13,0.004,10,-6,0.009,61,65,0.001,38,-100,0.001,34,-1,0.029,15,-93,0.004,49,39,0.009,-9,-67,0.000,-13,-62,0.001,-2,103,0.017,1,19,0.002,-10,121,0.004,16,95,0.035,-9,149,0.001,26,85,0.379,40,120,0.073,38,118,0.083,53,-116,0.000,12,-15,0.021,49,-123,0.037,36,10,0.040,35,33,0.001,-4,-47,0.002,-31,-60,0.002,6,-74,0.008,40,-106,0.001,39,109,0.002,50,32,0.012,26,42,0.002,41,80,0.006,3,33,0.011,51,118,0.001,50,-113,0.006,45,36,0.007,21,42,0.015,-3,24,0.004,-7,-39,0.013,64,-51,0.000,60,16,0.005,17,-12,0.002,32,94,0.001,-17,-39,0.010,28,33,0.001,8,-4,0.005,-30,-61,0.001,-35,24,0.002,55,76,0.002,51,49,0.004,31,54,0.011,28,-112,0.000,27,59,0.003,-15,20,0.001,4,6,0.013,21,77,0.069,-20,28,0.006,-2,-80,0.026,31,103,0.005,46,19,0.026,45,104,0.000,55,78,0.001,-2,31,0.071,69,31,0.000,-25,32,0.017,46,-98,0.001,57,45,0.002,37,58,0.012,-10,-78,0.007,33,51,0.018,28,93,0.002,9,41,0.018,-10,21,0.001,-15,31,0.006,56,27,0.004,37,-97,0.019,13,-11,0.002,9,-6,0.007,46,128,0.045,43,-70,0.020,24,44,0.005,0,34,0.095,67,65,0.002,43,75,0.005,24,-101,0.008,23,48,0.005,1,100,0.029,-4,12,0.001,-23,-70,0.000,25,91,0.086,38,69,0.058,35,129,0.202,37,110,0.028,15,6,0.002,11,11,0.050,10,14,0.053,5,-67,0.002,53,74,0.001,14,106,0.021,29,56,0.005,-9,128,0.002,25,57,0.006,5,46,0.004,2,20,0.013,-18,-49,0.005,-41,176,0.007,68,38,0.000,-8,-71,0.001,26,121,0.004,39,-81,0.010,36,23,0.002,35,-76,0.003,12,13,0.009,-7,121,0.002,-21,-51,0.007,-12,19,0.007,59,27,0.002,39,64,0.014,36,-90,0.006,35,61,0.022,30,-112,0.002,39,81,0.006,54,53,0.014,53,126,0.001,50,68,0.001,30,63,0.001,26,62,0.003,7,0,0.010,51,130,0.000,-3,-53,0.001,-37,-62,0.002,-7,-56,0.001,-27,-63,0.001,-13,-37,0.001,41,73,0.017,36,99,0.001,30,105,0.365,60,44,0.001,49,98,0.000,-35,139,0.030,55,-97,0.001,32,66,0.008,31,-87,0.004,28,61,0.004,8,32,0.005,-16,38,0.015,55,16,0.000,32,-79,0.006,42,-85,0.037,-20,25,0.001,21,113,0.019,-1,41,0.002,-3,-50,0.001,33,113,0.143,-6,143,0.005,46,47,0.001,42,46,0.008,22,49,0.003,-20,45,0.002,9,-72,0.004,-14,21,0.001,57,25,0.012,13,76,0.082,28,121,0.169,43,-123,0.004,24,89,0.375,-15,27,0.002,56,31,0.006,34,131,0.006,-4,-54,0.003,44,45,0.008,24,48,0.004,-9,34,0.012,20,51,0.002,13,106,0.005,-28,31,0.021,24,-97,0.001,23,84,0.044,1,128,0.004,14,-84,0.002,11,22,0.002,25,119,0.192,-13,32,0.002,61,28,0.003,58,30,0.002,34,56,0.001,49,82,0.001,10,50,0.004,-42,175,0.011,-37,147,0.004,-19,-65,0.010,53,30,0.011,48,6,0.010,5,18,0.003,-19,16,0.001,68,18,0.001,48,85,0.001,14,124,0.002,63,9,0.001,-32,-53,0.002,40,64,0.005,-36,-58,0.013,36,67,0.025,5,104,0.013,39,36,0.017,36,-110,0.001,-21,-63,0.001,29,79,0.191,14,77,0.089,7,19,0.002,-17,13,0.001,54,17,0.010,30,43,0.001,60,-150,0.000,6,29,0.004,-16,-43,0.006,-21,-29,0.001,-35,-55,0.013,-26,46,0.005,64,22,0.000,-31,154,0.001,41,37,0.015,21,-158,0.008,18,104,0.020,36,127,0.042,51,-113,0.007,45,-71,0.008,42,93,0.002,41,-74,0.037,-16,-69,0.009,52,83,0.003,-40,-63,0.000,32,22,0.005,31,-3,0.003,51,-7,0.000,31,110,0.058,9,118,0.001,46,12,0.025,-2,-51,0.001,33,77,0.003,-6,115,0.001,66,24,0.001,-29,28,0.008,42,18,0.003,19,-71,0.039,18,44,0.007,33,-2,0.004,-5,-77,0.001,22,96,0.072,0,124,0.017,52,15,0.019,33,43,0.004,13,48,0.001,9,49,0.002,-10,-51,0.000,24,93,0.163,23,-106,0.014,-28,-68,0.001,44,41,0.018,-52,-72,0.000,-4,21,0.001,13,78,0.161,47,-2,0.020,44,-72,0.006,62,28,0.005,23,120,0.003,38,14,0.033,0,-55,0.001,34,-119,0.022,15,45,0.075,14,8,0.019,11,50,0.002,10,3,0.008,-28,154,0.042,62,11,0.001,59,151,0.004,61,32,0.001,-28,-63,0.002,14,23,0.007,48,-101,0.002,-9,-72,0.001,25,-12,0.000,-13,-75,0.014,20,108,0.006,-37,175,0.035,48,42,0.004,29,32,0.238,40,141,0.038,35,-85,0.016,48,121,0.002,29,-115,0.001,63,29,0.001,40,36,0.020,39,-9,0.010,35,-4,0.008,16,42,0.001,11,110,0.010,-8,24,0.015,-12,-37,0.021,40,-77,0.015,36,-82,0.020,17,108,0.002,50,25,0.021,27,98,0.003,41,115,0.024,-17,49,0.004,-21,46,0.002,51,89,0.000,53,86,0.002,30,7,0.001,26,-10,0.000,41,4,0.003,-17,-62,0.001,-6,19,0.018,60,53,0.000,41,17,0.038,-6,-74,0.001,31,-80,0.000,-7,29,0.005,-44,147,0.000,41,-94,0.003,3,103,0.017,52,111,0.000,51,44,0.007,32,-6,0.039,-36,118,0.001,28,-11,0.001,4,43,0.003,-1,112,0.009,32,-87,0.004,46,40,0.010,8,-73,0.017,19,44,0.008,33,105,0.020,-5,30,0.021,-6,135,0.001,57,84,0.001,37,21,0.001,6,10,0.035,-2,115,0.004,10,99,0.007,22,92,0.297,56,56,0.004,52,59,0.004,13,20,0.002,47,-64,0.001,-10,-55,0.001,-11,26,0.008,56,103,0.001,-38,-70,0.000,-5,105,0.061,47,17,0.027,44,5,0.028,23,43,0.006,19,104,0.006,34,-98,0.006,-23,-51,0.016,-24,44,0.007,44,-108,0.001,58,51,0.007,20,-86,0.006,38,42,0.025,15,17,0.001,14,-12,0.005,10,-9,0.006,-9,119,0.024,38,-103,0.001,34,0,0.019,49,42,0.003,48,-81,0.001,-13,-63,0.001,2,45,0.009,1,22,0.004,16,96,0.104,6,121,0.003,26,86,0.391,40,113,0.038,-18,-61,0.001,53,-117,0.000,50,91,0.001,12,-14,0.014,49,-120,0.000,48,141,0.001,59,62,0.001,36,11,0.082,35,24,0.002,-31,-61,0.003,6,-69,0.001,40,-105,0.016,39,108,0.002,50,29,0.023,26,39,0.003,41,79,0.003,3,24,0.003,2,113,0.004,51,117,0.002,50,-112,0.000,45,35,0.015,21,41,0.015,-3,23,0.002,-6,39,0.016,-7,-36,0.012,60,17,0.005,17,-13,0.001,32,95,0.001,31,-108,0.001,28,34,0.001,8,-11,0.023,-30,-60,0.001,-34,151,0.043,-35,23,0.004,55,75,0.003,51,72,0.011,-3,117,0.003,31,53,0.021,28,-111,0.009,27,58,0.006,4,7,0.073,21,80,0.123,18,-78,0.005,-1,20,0.003,31,102,0.004,46,20,0.019,45,103,0.001,-38,143,0.001,55,77,0.002,-2,32,0.029,-6,107,0.007,-25,31,0.015,46,-93,0.001,57,48,0.002,37,57,0.010,33,54,0.001,28,94,0.001,9,44,0.008,-10,22,0.001,-9,25,0.003,-4,119,0.005,56,28,0.005,37,-86,0.007,5,-10,0.001,13,-8,0.009,9,-7,0.005,46,125,0.047,43,-71,0.013,-14,-172,0.001,0,35,0.172,-23,44,0.005,43,74,0.004,24,-100,0.005,23,47,0.005,1,99,0.011,15,100,0.024,14,48,0.004,25,78,0.047,38,70,0.020,35,120,0.108,37,109,0.013,15,5,0.001,11,10,0.060,48,-124,0.000,10,27,0.006,38,-75,0.013,53,73,0.001,49,70,0.000,29,55,0.005,14,17,0.001,44,142,0.001,25,60,0.002,5,45,0.003,2,17,0.001,-18,-48,0.005,-22,27,0.001,-41,175,0.000,-8,-70,0.001,-12,-75,0.021,40,85,0.001,39,-82,0.026,35,-77,0.020,50,95,0.000,12,14,0.012,-12,20,0.002,-37,150,0.001,59,26,0.002,39,63,0.003,36,-89,0.006,35,68,0.007,30,-115,0.003,39,80,0.006,54,54,0.013,53,125,0.001,30,64,0.001,26,75,0.083,7,-1,0.028,-20,33,0.021,51,129,0.004,-3,-58,0.001,-19,-47,0.006,-27,-60,0.006,41,76,0.002,36,100,0.002,-35,-65,0.002,30,106,0.228,6,119,0.001,54,103,0.001,32,67,0.005,31,-88,0.003,28,62,0.003,8,25,0.001,-16,39,0.010,55,15,0.003,31,25,0.001,42,-84,0.026,-1,40,0.005,33,116,0.296,-6,144,0.009,46,48,0.009,42,59,0.006,22,50,0.002,52,-107,0.000,9,-73,0.012,46,-65,0.001,-11,-76,0.012,-14,22,0.001,57,28,0.004,56,9,0.009,-39,179,0.001,13,75,0.051,10,123,0.079,28,122,0.139,43,-116,0.016,24,90,0.449,-33,153,0.001,56,32,0.002,34,132,0.034,-4,-53,0.001,-5,120,0.034,44,46,0.003,24,73,0.083,20,52,0.002,13,105,0.013,-28,32,0.018,44,-67,0.001,23,83,0.051,38,-9,0.082,14,-87,0.053,11,21,0.001,25,122,0.198,-13,31,0.002,61,27,0.002,58,43,0.002,34,53,0.005,15,-23,0.006,49,81,0.001,10,47,0.001,-37,146,0.003,-19,-70,0.007,53,29,0.008,48,7,0.029,5,17,0.003,1,-50,0.000,-19,15,0.001,48,86,0.001,63,8,0.001,-32,-52,0.016,40,57,0.001,39,-110,0.001,36,68,0.025,50,131,0.001,-31,-50,0.004,5,103,0.025,39,35,0.015,36,-109,0.001,-21,-56,0.001,29,106,0.240,7,18,0.003,-20,-41,0.008,-17,28,0.011,54,18,0.012,30,44,0.007,6,30,0.006,-21,-52,0.001,-31,153,0.003,41,40,0.002,21,-159,0.001,18,101,0.022,36,128,0.123,17,30,0.001,51,-114,0.017,-17,-46,0.002,27,-104,0.001,45,-68,0.001,42,94,0.002,41,-75,0.023,-16,-68,0.006,21,-78,0.019,52,84,0.002,-40,-62,0.001,32,23,0.002,31,12,0.001,31,109,0.100,46,9,0.015,-4,-43,0.007,6,-9,0.011,-29,27,0.007,42,15,0.022,33,-3,0.009,-5,-78,0.003,22,93,0.077,0,117,0.002,52,16,0.017,13,47,0.005,-10,-50,0.001,24,94,0.062,33,-101,0.009,44,42,0.020,58,93,0.004,1,174,0.001,-4,22,0.002,13,77,0.096,47,-3,0.013,44,-71,0.003,62,25,0.002,34,-118,0.192,14,5,0.014,11,49,0.001,10,4,0.007,62,12,0.000,61,31,0.001,14,24,0.005,48,-100,0.001,-9,-73,0.003,25,-13,0.000,2,74,0.001,20,93,0.034,53,1,0.004,49,-2,0.005,48,43,0.003,29,31,0.084,44,102,0.000,40,142,0.024,35,-86,0.017,53,-110,0.001,48,122,0.005,29,-112,0.001,63,44,0.000,40,29,0.028,35,-5,0.066,16,43,0.007,11,109,0.045,-8,17,0.007,7,101,0.037,40,-76,0.045,36,-81,0.010,17,107,0.028,50,26,0.023,27,97,0.005,5,-3,0.070,-17,48,0.005,-21,45,0.004,51,80,0.001,53,85,0.006,50,-119,0.004,30,8,0.001,41,3,0.143,-17,-63,0.004,36,141,0.081,-6,20,0.015,-33,-60,0.014,30,119,0.077,58,10,0.001,60,54,0.000,41,20,0.036,17,26,0.001,31,-81,0.009,-7,32,0.004,-44,148,0.001,41,-95,0.014,3,102,0.164,51,43,0.008,32,-5,0.021,28,-10,0.003,4,44,0.004,-1,111,0.008,32,-86,0.014,46,37,0.006,8,-72,0.026,19,43,0.008,33,108,0.053,-5,29,0.009,57,83,0.000,19,-100,0.035,37,24,0.078,-2,116,0.005,10,100,0.010,-10,31,0.004,22,89,0.919,56,49,0.005,52,60,0.002,33,-118,0.128,13,19,0.002,47,-65,0.003,-10,-54,0.001,-11,25,0.008,56,104,0.001,-38,-73,0.008,-3,141,0.010,47,16,0.028,44,6,0.008,23,42,0.009,19,103,0.010,34,-101,0.002,-23,-48,0.022,44,-107,0.001,58,52,0.002,38,47,0.022,15,16,0.001,14,-15,0.024,10,-8,0.008,14,42,0.001,14,31,0.003,38,-102,0.001,34,-3,0.025,15,-95,0.000,49,41,0.004,48,-80,0.001,2,46,0.046,1,21,0.004,-18,49,0.020,16,105,0.044,-22,56,0.020,-3,103,0.016,26,99,0.006,40,114,0.072,5,11,0.082,-18,-60,0.001,16,-16,0.007,53,-122,0.002,50,92,0.001,12,-13,0.007,49,-121,0.002,59,61,0.007,40,1,0.008,36,12,0.002,-31,-58,0.003,6,-68,0.001,40,-104,0.006,39,107,0.034,54,63,0.002,50,30,0.012,26,40,0.003,-22,-50,0.020,41,82,0.007,3,23,0.007,2,114,0.001,51,124,0.001,45,30,0.007,21,44,0.010,-3,18,0.005,-6,40,0.024,-7,-37,0.013,30,131,0.001,60,18,0.005,17,-10,0.001,32,96,0.001,31,-109,0.002,28,35,0.001,-29,-48,0.006,8,-10,0.028,-30,-63,0.001,55,74,0.023,51,71,0.002,-3,120,0.013,31,68,0.008,28,-110,0.005,27,57,0.013,4,8,0.110,21,79,0.101,-1,19,0.011,-5,-48,0.002,31,101,0.003,46,17,0.038,22,27,0.000,-2,29,0.035,-8,-77,0.005,-6,108,0.001,-25,30,0.026,5,10,0.030,46,-92,0.007,-34,116,0.003,57,47,0.003,37,60,0.009,33,53,0.003,28,95,0.004,9,43,0.037,-10,27,0.005,-15,33,0.006,22,117,0.010,37,-87,0.015,-4,-80,0.010,13,-9,0.004,9,-4,0.004,46,126,0.049,43,-96,0.008,24,38,0.002,-22,-54,0.002,0,36,0.063,67,55,0.001,47,52,0.006,43,73,0.002,24,-107,0.029,23,46,0.005,1,102,0.017,15,99,0.006,-23,-68,0.003,11,32,0.004,25,77,0.061,38,75,0.001,35,119,0.213,37,112,0.073,15,-12,0.008,11,9,0.156,10,28,0.004,38,-74,0.001,53,76,0.001,49,69,0.000,44,143,0.004,25,59,0.001,5,48,0.001,2,18,0.000,-18,-51,0.004,-22,28,0.004,48,99,0.000,26,119,0.062,-12,-74,0.005,40,86,0.000,39,-83,0.023,35,-78,0.044,12,15,0.011,-12,37,0.004,59,25,0.018,39,62,0.003,36,-88,0.008,35,67,0.009,30,-114,0.001,-8,-39,0.022,39,79,0.006,54,59,0.006,53,128,0.001,50,66,0.000,30,61,0.004,-39,176,0.002,26,76,0.142,7,-2,0.032,57,-4,0.004,17,-76,0.011,-3,-59,0.006,-26,24,0.001,-27,-61,0.002,45,66,0.001,60,-1,0.001,41,75,0.002,30,95,0.001,4,-58,0.001,-16,-63,0.001,32,68,0.008,31,-89,0.010,28,63,0.002,8,26,0.000,-16,40,0.027,-39,-60,0.002,55,14,0.019,31,24,0.001,28,-82,0.048,42,-87,0.058,21,115,0.001,-1,39,0.008,33,115,0.294,-6,141,0.001,46,45,0.004,45,134,0.006,42,60,0.026,-11,33,0.003,22,55,0.004,6,1,0.043,52,-106,0.008,9,-70,0.027,46,-64,0.006,-11,-77,0.008,-14,19,0.001,57,27,0.003,56,10,0.017,52,5,0.127,10,124,0.138,43,-117,0.000,24,91,0.452,-33,152,0.013,34,129,0.014,-4,-52,0.001,44,47,0.002,43,-100,0.000,24,74,0.080,67,35,0.001,13,108,0.010,-28,33,0.010,44,-66,0.000,23,82,0.052,20,-156,0.004,38,-8,0.013,14,-86,0.015,11,28,0.005,-13,30,0.004,61,22,0.005,58,44,0.001,34,54,0.002,49,84,0.002,48,-95,0.001,10,48,0.001,-37,145,0.004,53,32,0.005,48,8,0.059,5,20,0.003,1,-51,0.000,48,87,0.002,-12,-62,0.003,-32,-59,0.009,40,58,0.003,39,-111,0.002,36,53,0.050,12,75,0.029,-31,-51,0.058,39,34,0.035,36,-108,0.003,-8,-35,0.066,29,105,0.214,7,17,0.007,-17,27,0.005,54,23,0.010,30,41,0.002,6,35,0.002,12,120,0.001,18,102,0.008,36,129,0.046,17,29,0.001,51,-115,0.001,32,113,0.194,27,-105,0.004,45,-69,0.001,41,-72,0.068,-16,-75,0.000,21,-79,0.010,32,24,0.000,31,11,0.001,-25,-60,0.001,46,10,0.014,33,79,0.001,66,22,0.001,-29,26,0.001,-48,-66,0.000,19,-81,0.001,18,42,0.009,33,0,0.002,-5,-79,0.011,22,94,0.007,0,118,0.006,52,17,0.038,13,42,0.006,9,51,0.001,-10,-45,0.001,24,95,0.017,-35,-61,0.005,33,-98,0.005,44,43,0.018,43,-8,0.024,1,173,0.001,-4,23,0.003,13,80,0.127,47,12,0.032,44,-70,0.007,62,26,0.006,23,118,0.030,14,6,0.029,10,1,0.022,62,9,0.001,14,21,0.002,11,-63,0.005,29,9,0.000,-9,-74,0.005,-13,-69,0.001,20,94,0.023,48,44,0.003,44,103,0.000,5,40,0.006,35,-87,0.007,-19,46,0.004,53,-111,0.001,48,123,0.007,29,-113,0.000,14,109,0.028,63,43,0.000,40,30,0.080,-20,-45,0.007,35,-6,0.008,16,44,0.045,-8,18,0.007,7,100,0.038,40,-83,0.022,36,-80,0.021,17,78,0.105,50,23,0.030,27,104,0.073,-17,47,0.008,51,79,0.001,53,88,0.028,50,-118,0.001,30,5,0.001,7,-58,0.001,6,127,0.006,-17,-64,0.003,-6,17,0.010,-35,-56,0.058,30,120,0.102,45,10,0.209,17,25,0.001,32,133,0.003,31,-82,0.006,-7,31,0.006,-26,-65,0.006,41,-92,0.005,3,101,0.003,52,113,0.000,51,42,0.006,32,-4,0.008,28,-9,0.002,27,36,0.001,4,29,0.002,-1,110,0.033,-36,147,0.001,32,-85,0.010,31,80,0.001,46,38,0.001,8,-79,0.011,19,42,0.014,33,107,0.037,-5,36,0.021,-6,133,0.003,65,73,0.001,19,-101,0.047,37,23,0.013,52,-66,0.000,-2,113,0.003,-10,32,0.006,-2,11,0.001,22,90,0.260,56,50,0.006,37,8,0.001,52,45,0.005,13,14,0.005,47,-66,0.001,46,87,0.001,-11,28,0.004,56,97,0.001,-38,-72,0.014,47,15,0.013,44,7,0.005,24,-14,0.000,23,41,0.004,19,102,0.008,34,-100,0.001,-36,-62,0.002,-23,-49,0.028,44,-106,0.001,62,54,0.001,58,49,0.003,38,48,0.018,34,43,0.005,15,15,0.001,14,-14,0.006,10,-11,0.011,61,62,0.000,38,-97,0.007,34,-2,0.028,15,-96,0.005,49,44,0.004,48,-71,0.007,2,43,0.007,-28,-62,0.001,1,24,0.003,-18,50,0.015,16,106,0.017,53,-8,0.006,26,100,0.023,40,115,0.060,38,121,0.001,16,-7,0.002,-22,-56,0.002,12,-12,0.005,49,-118,0.001,48,143,0.001,5,121,0.011,36,-3,0.007,-31,-59,0.003,6,-71,0.004,40,-111,0.044,39,106,0.001,54,64,0.002,50,59,0.002,26,37,0.002,41,81,0.006,3,22,0.006,-21,16,0.000,51,123,0.002,50,-114,0.007,45,29,0.033,21,43,0.015,57,10,0.005,-3,17,0.006,-6,37,0.010,-7,-50,0.002,30,132,0.001,60,19,0.001,17,-11,0.001,32,105,0.019,31,-110,0.008,28,36,0.002,8,-9,0.014,-30,-62,0.001,-15,34,0.031,55,73,0.003,51,70,0.001,-3,119,0.002,31,67,0.006,28,-109,0.004,27,64,0.003,4,9,0.033,21,90,0.012,-1,18,0.002,-2,-77,0.002,-5,-49,0.003,-8,141,0.001,46,18,0.018,43,116,0.001,22,28,0.000,-17,-45,0.002,-2,30,0.127,-6,105,0.041,-25,29,0.010,46,-95,0.003,-11,39,0.013,57,50,0.003,37,59,0.009,33,56,0.001,28,96,0.004,9,30,0.006,-10,28,0.003,-33,-71,0.026,-15,36,0.035,56,22,0.008,37,-84,0.016,-4,-79,0.025,13,-14,0.015,9,-5,0.017,46,131,0.052,43,-97,0.002,24,39,0.004,0,29,0.018,-23,30,0.002,47,51,0.001,43,48,0.014,24,-106,0.003,23,45,0.005,1,101,0.016,15,98,0.011,-23,-69,0.001,14,-61,0.008,11,31,0.007,-9,-36,0.031,25,80,0.095,62,66,0.003,58,69,0.004,38,76,0.002,35,118,0.216,37,111,0.048,15,-13,0.005,11,-16,0.001,10,25,0.005,-9,114,0.113,5,-54,0.001,53,75,0.002,49,72,0.001,29,49,0.033,44,144,0.002,25,46,0.005,5,47,0.002,2,15,0.002,-18,-50,0.005,-19,37,0.008,48,100,0.000,26,120,0.158,-12,-73,0.001,40,87,0.000,39,-84,0.089,36,26,0.001,35,-79,0.021,12,16,0.007,-7,110,0.119,-12,38,0.004,59,32,0.003,39,61,0.002,36,-87,0.012,35,66,0.006,30,-109,0.001,-8,-38,0.014,7,44,0.005,39,78,0.012,54,60,0.007,30,62,0.010,18,111,0.020,26,73,0.042,7,-3,0.014,17,-77,0.011,-3,-56,0.003,12,125,0.025,-7,-55,0.000,-27,-66,0.001,45,65,0.000,41,62,0.008,-21,149,0.001,30,96,0.001,-37,-65,0.000,45,-110,0.001,-16,-62,0.001,-35,136,0.001,-20,-67,0.000,54,101,0.002,32,61,0.003,31,-90,0.006,28,64,0.002,8,27,0.002,-16,17,0.002,55,13,0.065,31,23,0.002,28,-81,0.071,42,-86,0.009,21,110,0.090,-1,38,0.087,33,118,0.185,-6,142,0.001,65,20,0.000,46,46,0.000,43,80,0.002,45,133,0.010,22,56,0.002,52,-105,0.001,9,-71,0.004,46,-67,0.003,-14,20,0.001,57,14,0.006,56,11,0.017,52,6,0.088,-38,176,0.009,24,92,0.290,-33,151,0.001,34,130,0.001,44,48,0.000,24,75,0.082,67,34,0.002,13,107,0.003,44,-65,0.002,43,44,0.025,58,-6,0.001,20,-75,0.040,1,129,0.001,11,27,0.005,14,49,0.007,-13,29,0.034,49,109,0.000,58,41,0.002,-37,-63,0.002,34,51,0.024,49,83,0.009,11,-84,0.008,-8,122,0.000,10,45,0.002,-18,31,0.021,-19,-68,0.001,53,31,0.015,5,19,0.002,48,88,0.003,-12,-61,0.007,-32,-58,0.006,40,59,0.004,39,-112,0.000,36,54,0.024,16,49,0.001,50,129,0.005,12,76,0.133,-20,26,0.001,39,33,0.049,-8,-34,0.066,29,108,0.096,7,16,0.006,3,-51,0.000,-17,26,0.003,-20,46,0.003,54,24,0.021,30,42,0.001,6,36,0.010,-25,-54,0.007,12,121,0.002,41,42,0.018,-29,-57,0.001,21,-157,0.023,18,99,0.031,36,130,0.020,17,32,0.001,32,114,0.097,-6,-35,0.043,-7,22,0.014,27,-106,0.001,45,-74,0.014,42,108,0.001,4,-77,0.002,41,-73,0.081,-16,-74,0.001,21,-76,0.010,52,102,0.000,31,10,0.001,-25,-61,0.001,9,119,0.007,46,-1,0.020,-1,74,0.001,5,-9,0.008,-29,25,0.009,42,13,0.047,4,96,0.004,18,39,0.001,33,-1,0.002,-5,-72,0.001,-30,152,0.001,-1,-80,0.015,-18,-58,0.000,22,99,0.009,52,18,0.027,13,41,0.012,-10,-44,0.001,24,96,0.011,23,-109,0.003,33,-99,0.001,44,44,0.025,43,-9,0.001,-4,24,0.014,13,79,0.101,47,11,0.026,44,-69,0.009,62,15,0.000,23,117,0.369,38,17,0.023,0,-52,0.000,34,-120,0.007,14,11,0.002,10,2,0.012,47,92,0.000,62,10,0.001,14,22,0.002,29,12,0.001,-9,-75,0.002,-13,-70,0.001,20,95,0.041,49,0,0.016,48,37,0.011,5,39,0.026,35,-96,0.006,-19,45,0.002,-22,-175,0.002,48,124,0.010,63,42,0.000,40,31,0.041,16,37,0.012,-8,19,0.004,26,-97,0.010,7,99,0.008,-32,25,0.001,40,-82,0.027,36,-79,0.027,17,77,0.089,-33,-64,0.005,50,24,0.020,27,103,0.043,-17,46,0.002,51,78,0.001,53,87,0.011,50,-121,0.000,30,6,0.001,7,-59,0.001,21,-14,0.000,-17,-65,0.004,-6,18,0.012,30,117,0.110,64,53,0.001,45,9,0.083,60,56,0.000,41,-122,0.001,17,28,0.001,-17,-51,0.002,31,-83,0.008,-7,34,0.005,-26,-64,0.002,41,-93,0.019,52,114,0.012,51,41,0.007,28,-8,0.001,4,30,0.002,-20,36,0.006,32,-84,0.012,31,79,0.005,46,43,0.003,8,-78,0.001,-34,117,0.001,19,41,0.002,6,-4,0.019,-2,23,0.004,-5,35,0.020,-6,134,0.001,57,101,0.000,19,-102,0.031,37,34,0.016,-2,114,0.007,-10,29,0.006,-11,21,0.001,0,101,0.018,-34,23,0.007,56,51,0.005,37,7,0.001,52,46,0.004,33,-116,0.019,13,13,0.007,47,-67,0.001,46,88,0.001,-11,27,0.006,56,98,0.001,47,14,0.022,44,8,0.030,0,12,0.001,23,40,0.005,19,101,0.024,34,-103,0.002,-23,-46,0.040,44,-105,0.001,58,50,0.020,20,-99,0.033,38,45,0.021,34,44,0.011,10,-10,0.005,-9,40,0.002,38,-96,0.002,34,-5,0.078,15,-97,0.000,49,43,0.002,48,-70,0.001,-9,132,0.000,2,44,0.007,1,23,0.003,16,107,0.009,53,-9,0.005,26,97,0.001,40,116,0.061,38,122,0.034,16,-6,0.001,12,-11,0.005,49,-119,0.007,-31,23,0.000,23,102,0.025,36,-2,0.012,7,135,0.001,-31,-56,0.003,6,-70,0.002,3,12,0.036,40,-110,0.001,39,105,0.001,54,61,0.006,50,60,0.002,30,55,0.003,26,38,0.003,41,84,0.007,3,21,0.011,2,112,0.010,51,122,0.002,12,98,0.000,-13,-41,0.005,-3,20,0.003,-6,38,0.010,-7,-51,0.002,-27,26,0.008,42,145,0.002,60,20,0.001,32,106,0.060,31,-111,0.004,28,37,0.002,8,-8,0.013,-30,-65,0.002,-35,20,0.004,55,72,0.002,51,69,0.002,-3,114,0.006,31,66,0.023,28,-108,0.001,27,63,0.004,42,-77,0.010,4,10,0.036,21,89,0.055,-1,17,0.001,-3,-46,0.002,-5,-50,0.001,43,115,0.000,-2,35,0.039,-6,106,0.113,-25,28,0.003,46,-94,0.003,-4,-51,0.001,57,49,0.003,37,54,0.001,33,55,0.001,-9,148,0.002,28,97,0.001,9,29,0.009,-10,25,0.003,-15,35,0.048,56,23,0.007,37,-85,0.010,34,91,0.000,-4,-78,0.004,13,-15,0.022,46,132,0.034,43,-98,0.001,24,40,0.004,-4,138,0.003,0,30,0.049,-23,29,0.003,-30,-53,0.014,47,50,0.001,43,47,0.019,24,-105,0.005,23,76,0.101,1,104,0.195,-4,-48,0.002,14,-60,0.006,11,30,0.007,-9,-37,0.009,25,79,0.102,-13,24,0.001,38,73,0.001,35,117,0.260,37,122,0.098,15,-14,0.004,10,26,0.003,5,-55,0.011,1,-58,0.000,53,70,0.007,29,52,0.019,44,145,0.001,25,45,0.005,2,16,0.001,-18,-45,0.001,-8,-75,0.001,26,117,0.051,-12,-72,0.001,25,-98,0.015,40,88,0.000,39,-85,0.016,36,27,0.000,50,94,0.000,12,17,0.007,-7,109,0.219,-12,39,0.006,62,131,0.000,59,31,0.082,39,60,0.002,36,-86,0.036,35,65,0.014,30,-108,0.001,-8,-37,0.015,7,43,0.005,39,77,0.027,-20,47,0.021,54,57,0.036,30,67,0.032,26,74,0.065,7,-4,0.021,-3,-57,0.001,12,126,0.010,45,68,0.000,41,61,0.043,21,74,0.105,30,93,0.001,45,-111,0.002,42,133,0.005,-29,-63,0.002,-20,-66,0.004,54,102,0.001,-40,-71,0.002,32,62,0.002,31,-91,0.004,28,65,0.002,8,28,0.007,-16,18,0.001,55,44,0.012,32,-83,0.015,31,22,0.008,28,-80,0.016,9,78,0.146,42,-89,0.019,21,109,0.026,-1,37,0.078,33,117,0.210,-6,155,0.002,43,79,0.003,45,136,0.000,42,58,0.001,4,117,0.003,22,53,0.002,52,-104,0.001,9,-68,0.018,46,-66,0.001,-14,17,0.011,57,13,0.021,0,100,0.022,52,7,0.059,10,122,0.005,-33,-57,0.002,24,85,0.181,-33,150,0.001,34,127,0.022,-5,117,0.001,-24,-55,0.003,43,-102,0.001,24,76,0.069,-10,-71,0.000,20,71,0.026,-36,-71,0.018,67,33,0.003,13,102,0.049,44,-64,0.003,43,43,0.012,23,80,0.084,20,-74,0.009,0,-79,0.014,11,26,0.009,-13,36,0.002,61,24,0.011,58,42,0.003,-10,126,0.006,34,52,0.021,49,86,0.001,11,-85,0.009,48,-93,0.001,10,46,0.001,-18,32,0.039,-19,-69,0.004,53,42,0.006,29,24,0.001,5,118,0.010,5,14,0.003,14,39,0.034,48,129,0.006,-12,-60,0.002,-32,-57,0.003,40,60,0.003,36,55,0.026,16,50,0.003,50,130,0.002,12,45,0.012,-45,-68,0.000,39,32,0.020,29,107,0.298,7,15,0.003,-17,25,0.001,54,21,0.025,53,94,0.001,30,31,0.197,6,33,0.004,12,122,0.019,64,34,0.000,41,41,0.002,18,100,0.040,17,31,0.001,51,-109,0.000,32,115,0.139,-7,21,0.015,27,-107,0.003,45,-75,0.039,4,-76,0.020,41,-70,0.018,3,127,0.001,-16,-73,0.001,21,-77,0.017,52,103,0.001,-40,-67,0.001,31,9,0.002,32,-111,0.010,31,122,0.593,46,0,0.018,18,-11,0.001,-36,151,0.002,42,14,0.027,4,97,0.017,6,6,0.062,33,2,0.001,-5,-73,0.008,-15,-50,0.001,22,100,0.018,0,120,0.001,52,19,0.028,13,44,0.063,47,-88,0.001,-10,-47,0.001,24,121,0.108,23,-110,0.003,33,-96,0.028,-13,38,0.001,44,13,0.026,-4,25,0.005,47,10,0.055,44,-68,0.005,62,16,0.001,23,116,0.130,38,18,0.000,-38,-59,0.004,14,12,0.001,-36,145,0.001,10,-1,0.014,47,91,0.001,-9,123,0.012,-40,177,0.005,14,27,0.001,48,-105,0.000,29,11,0.000,-9,-76,0.004,-13,-71,0.001,20,96,0.064,53,-2,0.203,49,-1,0.011,48,38,0.063,38,99,0.001,35,-97,0.037,-19,48,0.071,53,-109,0.001,48,117,0.000,63,41,0.000,40,32,0.028,16,38,0.004,-4,-42,0.009,-8,20,0.002,-12,-49,0.001,-4,31,0.043,-32,26,0.001,40,-81,0.027,36,-78,0.012,17,80,0.111,50,21,0.045,27,102,0.019,26,15,0.001,3,48,0.000,-17,45,0.001,51,77,0.001,50,-120,0.003,30,11,0.001,-33,-69,0.006,7,-60,0.000,41,-8,0.097,21,-15,0.001,-17,-66,0.003,-6,15,0.021,30,118,0.100,-37,-72,0.021,64,54,0.000,45,12,0.085,60,57,0.000,41,-123,0.001,17,27,0.001,-7,33,0.005,3,107,0.001,52,115,0.001,51,32,0.021,27,34,0.003,4,31,0.006,-53,-70,0.000,-1,124,0.002,32,-91,0.004,31,78,0.057,46,44,0.002,8,-77,0.002,-4,142,0.002,-34,118,0.000,19,32,0.001,-2,24,0.004,-5,34,0.019,69,18,0.000,57,104,0.001,19,-103,0.023,37,33,0.018,-2,135,0.001,-10,30,0.005,-14,-39,0.021,-4,115,0.052,-34,24,0.002,56,52,0.005,52,47,0.004,33,-117,0.158,13,16,0.004,-27,152,0.001,47,-52,0.006,46,85,0.004,24,125,0.002,-14,-52,0.001,-34,-57,0.003,56,99,0.001,47,13,0.024,44,9,0.050,24,-12,0.000,23,39,0.003,34,-102,0.002,-23,-47,0.108,-42,148,0.003,44,-104,0.000,58,47,0.001,20,-98,0.042,38,46,0.022,35,80,0.001,34,41,0.008,14,-24,0.001,10,35,0.007,-9,39,0.004,61,64,0.001,38,-99,0.001,34,-4,0.047,49,14,0.023,48,-69,0.001,2,41,0.003,1,26,0.002,16,108,0.051,-22,35,0.003,48,74,0.000,26,98,0.001,40,109,0.004,38,127,0.065,16,-5,0.000,50,87,0.000,12,-10,0.003,49,-116,0.001,-31,26,0.002,40,4,0.000,-20,-40,0.015,-31,-57,0.003,6,-65,0.001,3,11,0.010,40,-109,0.001,39,104,0.003,54,62,0.012,50,57,0.002,30,56,0.007,26,51,0.021,41,83,0.005,3,28,0.004,-20,29,0.005,51,121,0.001,12,99,0.010,45,31,0.000,21,37,0.000,18,121,0.015,-3,19,0.007,-7,-48,0.003,-27,25,0.004,17,-9,0.000,54,111,0.000,32,107,0.068,31,-112,0.001,28,38,0.002,-30,-64,0.001,-35,19,0.040,55,71,0.001,52,143,0.000,51,76,0.005,-3,113,0.009,31,65,0.012,28,-107,0.004,27,62,0.003,42,-76,0.018,4,11,0.011,22,-81,0.015,21,92,0.025,-1,16,0.002,-39,-67,0.005,-2,-79,0.034,-5,-51,0.000,43,114,0.001,42,67,0.001,22,26,0.000,-2,36,0.008,-25,27,0.003,46,-105,0.000,57,52,0.002,33,58,0.001,28,98,0.001,9,32,0.004,-10,26,0.004,-15,38,0.006,56,24,0.012,37,-90,0.005,34,92,0.000,-12,-63,0.001,13,-12,0.002,46,129,0.016,43,-99,0.001,24,33,0.030,-14,-176,0.000,0,31,0.056,-23,32,0.002,47,49,0.001,43,46,0.032,24,-104,0.008,23,75,0.105,1,103,0.015,15,96,0.009,11,29,0.003,-43,-70,0.000,-9,-38,0.005,25,82,0.255,-13,23,0.001,38,74,0.000,37,121,0.127,15,-15,0.007,10,23,0.001,-32,142,0.001,5,-52,0.001,53,69,0.002,49,74,0.015,29,51,0.009,44,146,0.000,25,48,0.003,2,13,0.003,-18,-44,0.006,-29,-49,0.021,-8,-74,0.003,26,118,0.048,-12,-71,0.000,25,-99,0.006,40,81,0.006,39,-86,0.049,36,28,0.003,50,123,0.002,12,18,0.004,-7,112,0.079,-12,40,0.009,59,30,0.037,39,59,0.003,36,-85,0.007,35,56,0.002,-7,157,0.000,30,-111,0.001,-8,-36,0.010,7,42,0.002,-17,36,0.039,54,58,0.003,50,61,0.000,30,68,0.019,26,71,0.008,7,-5,0.025,-26,27,0.007,-27,-64,0.004,45,67,0.001,41,64,0.000,21,73,0.164,57,-3,0.003,30,94,0.001,45,-108,0.004,42,134,0.000,-16,-60,0.000,21,-102,0.037,-20,-65,0.010,-40,-70,0.000,32,63,0.006,28,66,0.002,8,21,0.000,-16,19,0.000,55,43,0.013,32,-82,0.006,31,21,0.018,9,77,0.260,42,-88,0.053,19,55,0.000,21,112,0.080,33,120,0.235,-6,156,0.001,65,22,0.002,43,78,0.015,45,135,0.001,4,118,0.012,22,54,0.003,52,-103,0.000,9,-69,0.032,-14,18,0.008,57,16,0.003,52,8,0.045,10,119,0.002,24,86,0.192,-33,149,0.002,34,128,0.027,-5,124,0.002,-24,-54,0.004,47,-124,0.000,43,-103,0.001,24,69,0.047,-11,121,0.001,20,72,0.008,13,101,0.354,44,-63,0.012,43,42,0.007,23,79,0.070,38,-5,0.005,0,-78,0.017,11,25,0.008,-9,-34,0.056,25,110,0.042,-13,35,0.007,61,23,0.003,58,39,0.001,34,49,0.042,49,85,0.003,11,-86,0.028,20,85,0.052,-18,29,0.009,53,41,0.005,5,13,0.004,48,130,0.013,63,20,0.001,-32,-56,0.003,40,53,0.002,36,56,0.004,16,51,0.001,50,127,0.005,12,46,0.008,39,31,0.017,54,11,0.022,16,-62,0.000,29,102,0.004,7,14,0.005,41,126,0.027,-17,24,0.002,54,22,0.009,53,93,0.001,30,32,0.714,6,34,0.002,12,123,0.008,64,35,0.001,41,44,0.015,18,97,0.036,17,34,0.004,-21,119,0.000,32,116,0.195,-7,24,0.063,27,-100,0.001,45,-72,0.014,41,-71,0.052,3,126,0.005,-16,-72,0.002,21,-82,0.002,52,104,0.014,-40,-66,0.001,32,35,0.070,31,8,0.001,32,-110,0.022,31,121,0.303,-29,-66,0.002,-38,144,0.004,42,27,0.015,4,98,0.021,19,-76,0.001,18,37,0.006,33,1,0.001,-5,-74,0.001,22,97,0.047,0,129,0.001,52,20,0.027,13,43,0.001,-10,-46,0.001,24,122,0.161,-9,15,0.006,-4,129,0.016,33,-97,0.013,44,14,0.001,-8,145,0.001,-4,26,0.002,47,9,0.103,-13,-50,0.001,23,115,0.122,38,23,0.010,14,9,0.013,10,0,0.032,47,90,0.001,14,28,0.001,5,-53,0.000,-8,128,0.000,29,6,0.001,-9,-77,0.009,20,97,0.038,53,-3,0.032,-3,107,0.011,49,2,0.040,48,39,0.079,38,100,0.001,35,-98,0.003,-19,47,0.010,53,-114,0.002,48,118,0.000,40,25,0.004,16,39,0.012,26,-99,0.003,-12,-48,0.003,-32,27,0.006,40,-80,0.046,36,-77,0.006,17,79,0.290,50,22,0.037,12,-71,0.001,27,101,0.013,7,50,0.002,41,106,0.001,3,47,0.004,-16,167,0.001,-21,49,0.011,51,84,0.001,30,12,0.001,7,-61,0.001,6,126,0.055,-25,-59,0.001,-17,-67,0.019,-6,16,0.017,30,123,0.025,8,127,0.015,45,11,0.065,60,58,0.000,-29,-54,0.008,-6,-65,0.000,-7,36,0.017,-26,-66,0.000,41,-107,0.000,52,116,0.001,51,31,0.005,32,-9,0.008,4,32,0.004,-53,-71,0.000,-1,123,0.004,32,-90,0.017,31,77,0.113,46,41,0.008,8,-76,0.013,19,31,0.001,-2,21,0.001,-5,33,0.015,48,95,0.000,5,-2,0.026,-10,148,0.011,37,36,0.039,-2,136,0.001,-10,35,0.013,-14,-38,0.003,-18,-65,0.007,-34,21,0.002,56,45,0.016,52,48,0.010,13,15,0.004,47,-53,0.003,46,86,0.002,24,126,0.002,-14,-55,0.000,-34,-56,0.002,56,100,0.000,-38,-61,0.002,47,28,0.040,44,10,0.026,-11,166,0.000,19,107,0.002,-23,-44,0.031,-24,33,0.001,44,-103,0.004,58,48,0.001,20,-97,0.052,35,79,0.001,34,42,0.004,15,28,0.001,10,36,0.003,-9,38,0.005,61,63,0.001,38,-98,0.002,49,13,0.025,48,-68,0.003,-2,104,0.034,2,42,0.003,1,25,0.004,16,101,0.047,-22,36,0.001,49,-98,0.002,48,75,0.000,26,95,0.088,40,110,0.046,2,-71,0.001,1,10,0.003,38,128,0.038,16,-4,0.001,12,-9,0.005,49,-117,0.002,63,76,0.003,-31,25,0.001,40,-3,0.185,35,27,0.001,-17,146,0.004,-31,-54,0.003,3,10,0.022,39,103,0.002,54,67,0.002,50,58,0.010,30,53,0.010,27,129,0.002,6,47,0.004,3,27,0.003,51,112,0.001,12,100,0.016,45,26,0.039,21,40,0.014,18,122,0.015,-14,-45,0.001,-3,14,0.001,-7,-49,0.003,30,87,0.000,-27,28,0.122,42,143,0.006,60,22,0.002,32,108,0.051,-17,-40,0.005,31,-113,0.001,28,39,0.001,-30,-67,0.002,55,70,0.002,51,75,0.000,-3,116,0.033,31,64,0.003,28,-106,0.013,27,61,0.002,42,-79,0.011,4,12,0.019,22,-80,0.029,21,91,0.010,-1,15,0.001,-2,-78,0.032,-5,-44,0.014,43,113,0.002,42,68,0.001,6,-3,0.023,-2,33,0.001,-6,104,0.002,-25,26,0.008,-28,-61,0.002,57,51,0.002,37,56,0.016,33,57,0.000,28,99,0.002,9,31,0.005,-15,37,0.007,22,121,0.100,56,17,0.003,37,-91,0.003,13,-13,0.006,46,130,0.022,43,-92,0.005,24,34,0.003,-22,166,0.001,0,32,0.037,-23,31,0.023,-5,144,0.003,47,48,0.001,43,45,0.024,24,-111,0.002,23,74,0.113,15,95,0.004,11,36,0.002,-43,-71,0.001,-9,-39,0.006,25,81,0.124,-13,22,0.001,15,-16,0.024,48,-119,0.001,10,24,0.005,5,38,0.027,20,122,0.000,53,72,0.001,49,73,0.016,-1,-48,0.004,29,46,0.002,-9,127,0.006,25,47,0.005,2,14,0.003,-18,-47,0.002,-19,34,0.007,49,-102,0.001,-8,-73,0.002,-12,-70,0.000,40,82,0.009,39,-87,0.009,50,124,0.001,12,19,0.002,-7,111,0.140,7,152,0.002,62,129,0.001,59,29,0.006,39,58,0.002,36,-84,0.010,35,55,0.002,30,-110,0.002,-8,-43,0.002,7,41,0.017,-17,35,0.015,54,31,0.012,
    50,62,0.000,
    30,65,0.002,
    26,72,0.010,
    7,-6,0.022,
    -27,-50,0.009,
    -26,28,0.030,
    -27,-65,0.032,
    45,62,0.001,
    41,63,0.002,
    21,76,0.101};



@end
