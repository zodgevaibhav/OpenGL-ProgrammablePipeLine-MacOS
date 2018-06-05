

#import "MyView.h"


CVReturn MyDisplayLinkCallback(CVDisplayLinkRef,const CVTimeStamp *,const CVTimeStamp *,CVOptionFlags,CVOptionFlags *,void *);
FILE *gpFile;
enum
{
    VVZ_ATTRIBUTE_VERTEX=0,
    VVZ_ATTRIBUTE_COLOR=1,
    VVZ_ATTRIBUTE_NORMAL=2,
    VVZ_ATTRIBUTE_TEXTURE0=3,
    
};

//Class variables should declare under curly bracket We can not initialize variable while declaraction, there nmust initialize in constructor only
@implementation MyView
    {
        @private
        CVDisplayLinkRef displayLink; //CVDisplayLinkRef is from core video library. Also it is pointer variable in side
        GLuint vertexShaderObject;
        GLuint fragmentShaderObject;
        GLuint shaderProgramObject;
        
        GLuint vao_triangle, vao_quads;
        GLuint vbo_quads_position,vbo_quads_normal;
        GLuint mvpUniform;
        
        GLfloat angleRotate;
        
        GLuint gModelViewMatrixUniform,gProjectionMatrixUniform;
        GLuint gLdUniform, gKdUniform, gLightPositionUniform;
        
        GLuint gLKeyPressedUniform;
        
        bool gbLight,bIsLKeyPressed,bIsAKeyPressed,gbAnimate;
        
        vmath::mat4 perspectiveGraphicProjectionMatrix;
    }

-(id)initWithFrame:(NSRect)frame;
{
    
    
    // ***** Code to get file location for log file ********
    NSBundle *mainBundle = [NSBundle mainBundle]; // to get path for log file we need to get bundle path (package path)
    NSString *appDirName = [mainBundle bundlePath]; //get directory name using bungle object
    NSString *parentDirPath = [appDirName stringByDeletingLastPathComponent];
    NSString *logFileNameWithPath = [NSString stringWithFormat:@"%@/Log.txt",parentDirPath];
    const char *pszLogFileNameWithPath=[logFileNameWithPath cStringUsingEncoding:NSASCIIStringEncoding];
    
    gpFile = fopen(pszLogFileNameWithPath,"w");
    
    if(gpFile==NULL)
    {
        printf("Can not create Log file. \n Exiting now...\n");
        [self release];
        [NSApp  terminate:self];
    }
    fprintf(gpFile,"**** Program started Successfully\n");
    
    
    
    
    self=[super initWithFrame:frame];  //initialize NSView by calling constructor of super and pass frame
    
    if(self)
    {
        [[self window]setContentView:self]; //set view to window. it is like, self.window.setContentView(self);
        //NSOpenGLPFA - NextStep OpenGL Pixels format attribute
        NSOpenGLPixelFormatAttribute attrs[]=
        {
            // Must specify the 4.1 Core Profile to use OpenGL 4.1
            NSOpenGLPFAOpenGLProfile,NSOpenGLProfileVersion4_1Core, //gives opengl programming profiles. For fixed functions value will be NSOpenGLProfileVersionLegacy
            // Specify the display ID to associate the GL context with (main display for now)
            NSOpenGLPFAScreenMask,CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),   //asking display (hardware rendering)
            NSOpenGLPFANoRecovery, // if no display found then do not give any software renderer. We need hardware renderer only.
            NSOpenGLPFAAccelerated, //hardware acceleration
            NSOpenGLPFAColorSize,24, // color bits can be written 32. Best practices says use 24
            NSOpenGLPFADepthSize,24,
            NSOpenGLPFAAlphaSize,8,
            NSOpenGLPFADoubleBuffer,
            0}; // last 0 indicates array is ending
        
        NSOpenGLPixelFormat *pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs]autorelease]; //get pixel format for above declared attributes
        if(pixelFormat==nil)
        {
            fprintf(gpFile,"No valid OpenGL pixel format is available. Exiting...\n");
            [self release];
            [NSApp terminate:self];
        }
        NSOpenGLContext *glContext = [[[NSOpenGLContext alloc]initWithFormat:pixelFormat shareContext:nil]autorelease]; // get OpenGL context. Share Context nill. Autorelease clean once this context switched and not in use.
        [self setPixelFormat:pixelFormat];
        [self setOpenGLContext:glContext];
        
        
    }
    return(self); //return self means view
}
-(CVReturn)getFrameForTime:(const CVTimeStamp *)pOutPutTime
{
    NSAutoreleasePool *pool =[[NSAutoreleasePool alloc]init];
    [self drawView];
    [pool release];
    return(kCVReturnSuccess);
}

-(void)prepareOpenGL// this method inherited from OpenGLView. We need to write init code from windows
{
    
    // print OpenGL Info
    fprintf(gpFile,"OpenGL Version  : %s\n",glGetString(GL_VERSION)); //glGetString is pure opengl function
    fprintf(gpFile,"GLSL Version    : %s\n",glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [[self openGLContext]makeCurrentContext]; // In constructor we returned self (View object), where context was set. We are referring that context using self.context and asking to makeCurrentContext
    
    GLint swapInt=1;
    [[self openGLContext]setValues:&swapInt forParameter:NSOpenGLCPSwapInterval]; // to avoid tearing intervals.
    
    //**************************************** Vertex shader **********************************************
    
    vertexShaderObject = glCreateShader(GL_VERTEX_SHADER);
    
    const GLchar *vertexShaderSourceCode =
    "#version 410" \
    "\n" \
    "in vec4 vPosition;" \
    "in vec3 vNormal;" \
    "uniform int u_LKeyPressed;" \
    "uniform mat4 u_model_view_matrix;" \
    "uniform mat4 u_projection_matrix;" \
    /*Light intensity*/        "uniform vec3 u_Ld;" \
    /*Light material*/        "uniform vec3 u_Kd;" \
    "uniform vec4 u_light_position;" \
    "out vec3 diffuse_light;" \
    "void main(void)" \
    "{" \
    "if (u_LKeyPressed == 1)" \
    "{" \
    "vec4 eyeCoordinates = u_model_view_matrix * vPosition;" \
    "vec3 tnorm = normalize(mat3(u_model_view_matrix) * vNormal);" \
    "vec3 s = normalize(vec3(u_light_position - eyeCoordinates));" \
    "diffuse_light = u_Ld * u_Kd * max(dot(s, tnorm), 0.0);" \
    "}" \
    "gl_Position = u_projection_matrix * u_model_view_matrix * vPosition;" \
    "}";
    
    /*
     Steps to calculate defuse light (this is done in vertex shader), it is done using observational mathmatics
     1. First geometry position coordinate covert to eye space (eye co-ordinates)
     2. Calculate Normal matrix, which is required to convert normals in to eye space (It is done by GLSL compiler internally under mat3 conversion.
     3. Convert normals in to eye space.
     4. Calculate source vector by substracting eyeCoordinates from light position.
     5. Calculate diffuse_light, by multiply {ld * kd * "dot product of source vector and notmal vectors"}
     */
    
    glShaderSource(vertexShaderObject, 1, (const GLchar **)&vertexShaderSourceCode, NULL);
    
    //******************* Compile Vertex shader
    glCompileShader(vertexShaderObject);
    GLint iInfoLogLength = 0;
    GLint iShaderCompiledStatus = 0;
    char *szInfoLog = NULL;
    glGetShaderiv(vertexShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
    if (iShaderCompiledStatus == GL_FALSE)
    {
        glGetShaderiv(vertexShaderObject, GL_INFO_LOG_LENGTH, &iInfoLogLength);
        if (iInfoLogLength > 0)
        {
            szInfoLog = (char *)malloc(iInfoLogLength);
            if (szInfoLog != NULL)
            {
                GLsizei written;
                glGetShaderInfoLog(vertexShaderObject, iInfoLogLength, &written, szInfoLog);
                fprintf(gpFile, "Vertex Shader Compilation Log : %s\n", szInfoLog);
                free(szInfoLog);
            }
        }
    }
    
    //**************************************** Fragment shader **********************************************
    
    fragmentShaderObject = glCreateShader(GL_FRAGMENT_SHADER);
    
    const GLchar *fragmentShaderSourceCode =
    "#version 410" \
    "\n" \
    "in vec3 diffuse_light;" \
    "out vec4 FragColor;" \
    "uniform int u_LKeyPressed;" \
    "void main(void)" \
    "{" \
    "vec4 color;" \
    "if (u_LKeyPressed == 1)" \
    "{" \
    "color = vec4(diffuse_light,1.0);" \
    "}" \
    "else" \
    "{" \
    "color = vec4(1.0, 1.0, 1.0, 1.0);" \
    "}" \
    "FragColor = color;" \
    "}";
    
    glShaderSource(fragmentShaderObject, 1, (const GLchar **)&fragmentShaderSourceCode, NULL);
    
    //******************* Compile fragment shader
    glCompileShader(fragmentShaderObject);
    glGetShaderiv(fragmentShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
    if (iShaderCompiledStatus == GL_FALSE)
    {
        glGetShaderiv(fragmentShaderObject, GL_INFO_LOG_LENGTH, &iInfoLogLength);
        if (iInfoLogLength > 0)
        {
            szInfoLog = (char *)malloc(iInfoLogLength);
            if (szInfoLog != NULL)
            {
                GLsizei written;
                glGetShaderInfoLog(fragmentShaderObject, iInfoLogLength, &written, szInfoLog);
                fprintf(gpFile, "Fragment Shader Compilation Log : %s\n", szInfoLog);
                free(szInfoLog);
                
            }
        }
    }
    
    //**************************************** Shader program attachment **********************************************
    
    shaderProgramObject = glCreateProgram();
    
    // attach vertex shader to shader program
    glAttachShader(shaderProgramObject, vertexShaderObject);
    
    // attach fragment shader to shader program
    glAttachShader(shaderProgramObject, fragmentShaderObject);
    
    // pre-link binding of shader program object with vertex shader position attribute
    glBindAttribLocation(shaderProgramObject, VVZ_ATTRIBUTE_VERTEX, "vPosition");
    glBindAttribLocation(shaderProgramObject, VVZ_ATTRIBUTE_NORMAL, "vNormal");
    
    //**************************************** Link Shader program **********************************************
    glLinkProgram(shaderProgramObject);
    GLint iShaderProgramLinkStatus = 0;
    glGetProgramiv(shaderProgramObject, GL_LINK_STATUS, &iShaderProgramLinkStatus);
    if (iShaderProgramLinkStatus == GL_FALSE)
    {
        glGetProgramiv(shaderProgramObject, GL_INFO_LOG_LENGTH, &iInfoLogLength);
        if (iInfoLogLength>0)
        {
            szInfoLog = (char *)malloc(iInfoLogLength);
            if (szInfoLog != NULL)
            {
                GLsizei written;
                glGetProgramInfoLog(shaderProgramObject, iInfoLogLength, &written, szInfoLog);
                fprintf(gpFile, "Shader Program Link Log : %s\n", szInfoLog);
                free(szInfoLog);
                
            }
        }
    }
    
    //**************************************** END Link Shader program **********************************************
    
    // get uniform locations
    gModelViewMatrixUniform = glGetUniformLocation(shaderProgramObject, "u_model_view_matrix");
    gProjectionMatrixUniform = glGetUniformLocation(shaderProgramObject, "u_projection_matrix");
    
    gLKeyPressedUniform = glGetUniformLocation(shaderProgramObject, "u_LKeyPressed");
    
    gLdUniform = glGetUniformLocation(shaderProgramObject, "u_Ld");
    gKdUniform = glGetUniformLocation(shaderProgramObject, "u_Kd");
    gLightPositionUniform = glGetUniformLocation(shaderProgramObject, "u_light_position");
    
    //************************************ Quods ********************************************************
    
    // ***********************************  Quods Vertices
    GLfloat cubeVertices[] =
    {
        1.0f, 1.0f, -1.0f,
        -1.0f, 1.0f, -1.0f,
        -1.0f, 1.0f, 1.0f,
        1.0f, 1.0f, 1.0f,
        
        1.0f, -1.0f, 1.0f,
        -1.0f, -1.0f, 1.0f,
        -1.0f, -1.0f, -1.0f,
        1.0f, -1.0f, -1.0f,
        
        1.0f, 1.0f, 1.0f,
        -1.0f, 1.0f, 1.0f,
        -1.0f, -1.0f, 1.0f,
        1.0f, -1.0f, 1.0f,
        
        1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f, -1.0f,
        -1.0f, 1.0f, -1.0f,
        1.0f, 1.0f, -1.0f,
        
        -1.0f, 1.0f, 1.0f,
        -1.0f, 1.0f, -1.0f,
        -1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f, 1.0f,
        
        1.0f, 1.0f, -1.0f,
        1.0f, 1.0f, 1.0f,
        1.0f, -1.0f, 1.0f,
        1.0f, -1.0f, -1.0f,
    };
    
    for (int i = 0; i<72; i++)
    {
        if (cubeVertices[i]<0.0f)
            cubeVertices[i] = cubeVertices[i] + 0.25f;
        else if (cubeVertices[i]>0.0f)
            cubeVertices[i] = cubeVertices[i] - 0.25f;
        else
            cubeVertices[i] = cubeVertices[i];
    }
    
    const GLfloat cubeNormals[] =
    {
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f
    };
    
    // CUBE CODE
    // vao
    glGenVertexArrays(1, &vao_quads);
    glBindVertexArray(vao_quads);
    
    // position vbo
    glGenBuffers(1, &vbo_quads_position);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quads_position);
    glBufferData(GL_ARRAY_BUFFER, sizeof(cubeVertices), cubeVertices, GL_STATIC_DRAW);
    
    glVertexAttribPointer(VVZ_ATTRIBUTE_VERTEX, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    
    glEnableVertexAttribArray(VVZ_ATTRIBUTE_VERTEX);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    // normal vbo
    glGenBuffers(1, &vbo_quads_normal);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quads_normal);
    glBufferData(GL_ARRAY_BUFFER, sizeof(cubeNormals), cubeNormals, GL_STATIC_DRAW);
    
    glVertexAttribPointer(VVZ_ATTRIBUTE_NORMAL, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    
    glEnableVertexAttribArray(VVZ_ATTRIBUTE_NORMAL);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    glBindVertexArray(0);
  //*************************************************

    
    
    //glShadeModel(GL_SMOOTH);
    
    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
   // glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    //glEnable(GL_CULL_FACE);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    
    perspectiveGraphicProjectionMatrix = vmath::mat4::identity();

    
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink); // Core Video create display link with currently active display
    CVDisplayLinkSetOutputCallback(displayLink,&MyDisplayLinkCallback,self); // set output call back. Display Link, callback function address, argument to our call back function
    CGLContextObj cglContext = (CGLContextObj)[[self openGLContext]CGLContextObj];
    CGLPixelFormatObj cglPixelFormat=(CGLPixelFormatObj)[[self pixelFormat]CGLPixelFormatObj];
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink,cglContext,cglPixelFormat);
    CVDisplayLinkStart(displayLink);
}

-(void)reshape  //this method inherited from OpenGLView. This method gets called automatically if window modified by user.
{
    // code
    CGLLockContext((CGLContextObj)[[self openGLContext]CGLContextObj]);
    
    NSRect rect=[self bounds];
    
    GLfloat width=rect.size.width;
    GLfloat height=rect.size.height;
    
    if(height==0)
        height=1;
    
    glViewport(0,0,(GLsizei)width,(GLsizei)height);
    
    
        perspectiveGraphicProjectionMatrix = vmath::perspective(45.0f,(GLfloat)width/(GLfloat)height,0.1f,100.0f);
    
    
    CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self drawView];
}

- (void)drawView
{
    [[self openGLContext]makeCurrentContext];
    CGLLockContext((CGLContextObj)[[self openGLContext]CGLContextObj]);
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glUseProgram(shaderProgramObject);
    
    if (gbLight == true)
    {
        glUniform1i(gLKeyPressedUniform, 1);
        
        glUniform3f(gLdUniform, 1.0f, 1.0f, 1.0f);
        glUniform3f(gKdUniform, 0.5f, 0.5f, 0.5f);
        
        float lightPosition[] = { 0.0f, 0.0f, 2.0f, 1.0f };
        glUniform4fv(gLightPositionUniform, 1, (GLfloat *)lightPosition);
    }
    else
    {
        glUniform1i(gLKeyPressedUniform, 0);
    }
    
    // OpenGL Drawing
    // set all matrices to identity
    vmath::mat4 modelMatrix = vmath::mat4::identity();
    vmath::mat4 modelViewMatrix = vmath::mat4::identity();
    vmath::mat4 rotationMatrix = vmath::mat4::identity();
    
    // apply z axis translation to go deep into the screen by -5.0,
    // so that triangle with same fullscreen co-ordinates, but due to above translation will look small
    modelMatrix = vmath::translate(0.0f, 0.0f, -5.0f);
    
    // all axes rotation by gAngle angle
    rotationMatrix = vmath::rotate(angleRotate, angleRotate, angleRotate);
    
    // multiply rotation matrix and model matrix to get modelView matrix
    modelViewMatrix = modelMatrix * rotationMatrix; // ORDER IS IMPORTANT
    
    // pass modelview matrix to the vertex shader in 'u_model_view_matrix' shader variable
    // whose position value we already calculated in initialize() by using glGetUniformLocation()
    glUniformMatrix4fv(gModelViewMatrixUniform, 1, GL_FALSE, modelViewMatrix);
    
    // pass projection matrix to the vertex shader in 'u_projection_matrix' shader variable
    // whose position value we already calculated in initialize() by using glGetUniformLocation()
    glUniformMatrix4fv(gProjectionMatrixUniform, 1, GL_FALSE, perspectiveGraphicProjectionMatrix);
    
    // *** bind vao ***
    glBindVertexArray(vao_quads);
    
    // *** draw, either by glDrawTriangles() or glDrawArrays() or glDrawElements()
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 4, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 8, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 12, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 16, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 20, 4);
    
    // *** unbind vao ***
    glBindVertexArray(0);
    
    // stop using OpenGL program object
    glUseProgram(0);

    [self updateAngleRotate];
    
    CGLFlushDrawable((CGLContextObj)[[self openGLContext]CGLContextObj]);
    CGLUnlockContext((CGLContextObj)[[self openGLContext]CGLContextObj]);
}
-(BOOL)acceptsFirstResponder
{
    [[self window]makeFirstResponder:self];
    return(YES);
}

-(void)keyDown:(NSEvent *)theEvent
{
    int key=(int)[[theEvent characters]characterAtIndex:0];
    switch(key)
    {
        case 27: // Esc key
            [ self release];
            [NSApp terminate:self];
            break;
        case 'F':
        case 'f'://fall down conditions
            [[self window]toggleFullScreen:self]; // repainting occurs automatically
            break;
        case 'a': // for 'A' or 'a'
        case 'A':
            if (bIsAKeyPressed == false)
            {
                fprintf(gpFile,"*** Animation is On");
                gbAnimate = true;
                bIsAKeyPressed = true;
            }
            else
            {
                fprintf(gpFile,"*** Animation is Off");
                gbAnimate = false;
                bIsAKeyPressed = false;
            }
            break;
        case 'l': // for 'L' or 'l'
        case 'L':
            if (bIsLKeyPressed == false)
            {
                fprintf(gpFile,"*** Light is on");
                gbLight = true;
                bIsLKeyPressed = true;
            }
            else
            {
                fprintf(gpFile,"*** Light is oFF");
                gbLight = false;
                bIsLKeyPressed = false;
            }
            break;
        default:
            break;
    }
}

-(void)mouseDown:(NSEvent *)theEvent
{
}

-(void)mouseDragged:(NSEvent *)theEvent
{
  
}

-(void)rightMouseDown:(NSEvent *)theEvent
{
 
}

- (void) dealloc
{
 
    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
    [super dealloc];
}

-(void) updateAngleRotate
{
    if (angleRotate==360.0f)
        angleRotate=0.0f;
    else
        angleRotate=angleRotate+1.5f;
}

@end

//Global function
CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink,const CVTimeStamp *pNow,const CVTimeStamp *pOutputTime,CVOptionFlags flagsIn,
                               CVOptionFlags *pFlagsOut,void *pDisplayLinkContext)
{
    CVReturn result=[(MyView *)pDisplayLinkContext getFrameForTime:pOutputTime];
    return(result);
}


