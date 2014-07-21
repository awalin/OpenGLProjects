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
    
    GLuint _locationVertexBuffer;
    GLuint _locationTextureBuffer;
    GLuint _locationColorBuffer;
    GLuint _planeIndiciesBuffer;
    
    TexImgTweenFunction* tweenFunction;
    
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
    NSLog(@"total indices %d", totalIndices);
    totalPoints = rows*cols;
    self.locations = (CustomPoint*) malloc(totalPoints*sizeof(CustomPoint));
    self.allLocations = [[NSMutableArray alloc] initWithCapacity:totalPoints];
    self.tweens = [[NSMutableArray alloc] initWithCapacity:totalPoints];
    meshIndices = (GLuint*)malloc(totalIndices*sizeof(GLuint));
    
    touchEnded = NO;
    friction = 0.90;
    _duration = 2.0;
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
    
    
    UIImage *texImage = [UIImage imageNamed:@"earth-map.png"];
    float imageAspect = texImage.size.width/texImage.size.height;
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
    float offsetPhi = GLKMathDegreesToRadians(-180.0f);
    
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
            theta = offsetTheta + eachTheta*i;
            
            location.theta = theta;
            location.phi = phi;
            location.row = i;
            location.col = j;
            
            TexImgTween* tween = [[TexImgTween alloc] init];
            tween.planeId = index;
            tween.targetPhi = phi;
            tween.targetTheta = theta;
            
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
            [self.tweens insertObject:tween atIndex:index];
            
            
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
        TexImgTween* tween = [self.tweens objectAtIndex:index];
        PNT_EarthPoint* plane = [self.allLocations objectAtIndex:index];
        tween.startTime = currentTime;
        //        NSLog(@"twn start time %@", tween.startTime);
        if(self.viewType==GLOBE){
            [[self.tweens objectAtIndex:index] setTargetCenter: plane.roundLoc];
            [[self.tweens objectAtIndex:index] setSourceCenter: plane.flatLoc];
        } else if(self.viewType==WALL){
            [[self.tweens objectAtIndex:index] setTargetCenter: plane.flatLoc];
            [[self.tweens objectAtIndex:index] setSourceCenter: plane.roundLoc];
        }
    }
    
}

-(void) setDuration:(float) val {
    _duration = val;
    self.viewChanged=NO;
    
    self.viewChanged = YES;
}



-(void)setupGL{
    
    /** All the local setup for the ViewController */
    
    self.effect = [[GLKBaseEffect alloc] init];
    zTranslation = 5.0f;
    taps=0;
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
    NSString *path = [[NSBundle mainBundle] pathForResource:@"earth-map" ofType:@"png"];
    info = [GLKTextureLoader textureWithContentsOfFile:path options:options error:&error];
    if (info == nil) {
        NSLog(@"Error loading file: %@", [error localizedDescription]);
    }
    self.effect.texture2d0.name = info.name;
    [self makePlane];
    //[self makeGlobe];
    
    glGenBuffers(1, &_locationVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _locationVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(CustomPoint)*totalPoints, self.locations, GL_DYNAMIC_DRAW);
    
	
    glGenBuffers(1, &_locationTextureBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _locationTextureBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(CustomPoint)*totalPoints, self.locations, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_locationColorBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _locationColorBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(CustomPoint)*totalPoints, self.locations, GL_STATIC_DRAW);
	
    glGenBuffers(1, &_planeIndiciesBuffer);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _planeIndiciesBuffer);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLuint)*totalIndices, meshIndices, GL_STATIC_DRAW);
    
    
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
        TexImgTween* tween = [self.tweens objectAtIndex:index];
        float timePassedSinceStart = -[tween.startTime timeIntervalSinceNow];
        durationRemaining = _duration - timePassedSinceStart;
        float ratio =  timeElapsedSinceLastUpdate/timePassedSinceStart;
        ratio = [tweenFunction calculateTweenWithTime: timePassedSinceStart duration: _duration];
        
        [location updateVertex:tween.targetCenter
                          mode:self.viewType
                   timeElapsed: timePassedSinceStart//timeElapsedSinceLastUpdate
                      duration: _duration //durationRemaining
                         ratio:ratio];
        
        self.locations[index].positionCoords = location.center;
        
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
    
    self.effect.texture2d0.enabled = YES;
    
    [self renderSingleFrame];
}


-(void) update {
    
    if(self.viewChanged) {
        
        [self animateView];// changes the points
        
        glBindBuffer(GL_ARRAY_BUFFER, _locationVertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(CustomPoint)*totalPoints, self.locations, GL_DYNAMIC_DRAW);
        
    }
    if(self.viewType==GLOBE)
        modelrotation.y -= 0.2;
    else {
        modelrotation.y= 0;
    }
    
}


-(void) renderSingleFrame {
    
	if( [EAGLContext currentContext] == nil ) // skip until we have a context
    {
		NSLog(@"We have no gl context; skipping all frame rendering");
		return;
	}
    
    
    
    [self.effect prepareToDraw];
    
    
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    glBindBuffer(GL_ARRAY_BUFFER, _locationVertexBuffer);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition,
                          3,
                          GL_FLOAT, GL_FALSE,
                          sizeof(CustomPoint),
                          (void *)offsetof(CustomPoint, positionCoords));
    
    glBindBuffer(GL_ARRAY_BUFFER, _locationTextureBuffer);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0,
                          2,
                          GL_FLOAT,
                          GL_FALSE,
                          sizeof(CustomPoint) ,
                          (void *)offsetof(CustomPoint, textureCoords));
    
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _planeIndiciesBuffer);
    glDrawElements(GL_TRIANGLES, totalIndices, GL_UNSIGNED_INT, NULL);
    
    
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
            
            if(touchEnded) return;
            
            //        NSLog(@"%f, %f", diff.x, diff.y);
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

@end
