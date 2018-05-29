

#import "MyView.h"


CVReturn MyDisplayLinkCallback(CVDisplayLinkRef,const CVTimeStamp *,const CVTimeStamp *,CVOptionFlags,CVOptionFlags *,void *);

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
    GLuint vertextShaderObject;
    GLuint fragmentShaderObject;
    GLuint shaderProgramObject;
    
    GLuint vao_triangle, vao_quads;
    GLuint vbo_triangle_position,vbo_triangle_color;
    GLuint vbo_quads_position,vbo_quads_color;
    GLuint mvpUniform;
    
    GLfloat angleRotate;
    
    vmath::mat4 perspectiveGraphicProjectionMatrix;
}

-(id)initWithFrame:(NSRect)frame;
{
    
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
            printf("No valid OpenGL pixel format is available. Exiting...\n");
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
    printf("OpenGL Version  : %s\n",glGetString(GL_VERSION)); //glGetString is pure opengl function
    printf("GLSL Version    : %s\n",glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [[self openGLContext]makeCurrentContext]; // In constructor we returned self (View object), where context was set. We are referring that context using self.context and asking to makeCurrentContext
    
    GLint swapInt=1;
    [[self openGLContext]setValues:&swapInt forParameter:NSOpenGLCPSwapInterval]; // to avoid tearing intervals.
    
    //**************************************** Vertex shader **********************************************
    vertextShaderObject = glCreateShader(GL_VERTEX_SHADER);
    
    const GLchar *vertexShaderSourceCode =
    "#version 410"\
    "\n"\
    "layout(location = 0) in vec4 vPosition;"\
    "layout(location = 1) in vec4 vColor;"\
    "out vec4 outColor;"\
    "uniform mat4 u_mvp_matrix;"\
    "void main(void)" \
    "{" \
    "gl_Position=u_mvp_matrix * vPosition;"
    "outColor = vColor;"
    "}";
    
    glShaderSource(vertextShaderObject, 1, (const GLchar **)&vertexShaderSourceCode, NULL);
    
    //******************* Compile Vertex shader
    glCompileShader(vertextShaderObject);
    
    GLint iInfoLogLength = 0;
    GLint iShaderCompiledStatus = 0;
    char *szInfoLog = NULL;
    glGetShaderiv(vertextShaderObject, GL_COMPILE_STATUS, &iShaderCompiledStatus);
    if (iShaderCompiledStatus == GL_FALSE)
    {
        glGetShaderiv(vertextShaderObject, GL_INFO_LOG_LENGTH, &iInfoLogLength);
        if (iInfoLogLength > 0)
        {
            szInfoLog = (char *)malloc(iInfoLogLength);
            if (szInfoLog != NULL)
            {
                GLsizei written;
                glGetShaderInfoLog(vertextShaderObject, iInfoLogLength, &written, szInfoLog);
                printf("***** Vertex Shader Compilation Log : %s\n", szInfoLog);
                free(szInfoLog);
                [self release];
                [NSApp terminate:self];
            }
        }
    }
    
    //**************************************** Fragment shader **********************************************
    fragmentShaderObject = glCreateShader(GL_FRAGMENT_SHADER);
    
    const GLchar *fragmentShaderSourceCode =
    "#version 410"\
    "\n"\
    "in vec4 outColor;"
    "out vec4 FragColor;"
    "void main(void)" \
    "{" \
    "FragColor=outColor;"\
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
                printf("***** Fragment Shader Compilation Log : %s\n", szInfoLog);
                free(szInfoLog);
                [self release];
                [NSApp terminate:self];
                
            }
        }
    }
    
    //**************************************** Shader program attachment **********************************************
    
    shaderProgramObject = glCreateProgram();
    
    // attach vertex shader to shader program
    glAttachShader(shaderProgramObject, vertextShaderObject);
    
    // attach fragment shader to shader program
    glAttachShader(shaderProgramObject, fragmentShaderObject);
    
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
                printf("Shader Program Link Log : %s\n", szInfoLog);
                free(szInfoLog);
                [self release];
                [NSApp terminate:self];
            }
        }
    }
    
    //**************************************** END Link Shader program **********************************************
    
    mvpUniform = glGetUniformLocation(shaderProgramObject,"u_mvp_matrix");
    
    //**************************************** Triangle **********************************************
    
    const GLfloat triangleVertices[] =
    { 0.0f,1.0f,0.0f, //0
        -1.0f,-1.0f,0.0f,
        1.0f,-1.0f,0.0f,
    };
    
    glGenVertexArrays(1, &vao_triangle);
    glBindVertexArray(vao_triangle);
    
    glGenBuffers(1, &vbo_triangle_position);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_triangle_position);
    glBufferData(GL_ARRAY_BUFFER, sizeof(triangleVertices), triangleVertices, GL_STATIC_DRAW);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    
    glEnableVertexAttribArray(0);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    
    const GLfloat triangleColor[]=
    {
        1.0f,0.0f,0.0f,
        0.0f,1.0f,0.0f,
        0.0f,0.0f,1.0f,
    };
    
    glBindVertexArray(vao_triangle);
    
    glGenBuffers(1,&vbo_triangle_color);
    glBindBuffer(GL_ARRAY_BUFFER,vbo_triangle_color);
    glBufferData(GL_ARRAY_BUFFER,sizeof(triangleColor),triangleColor,GL_STATIC_DRAW);
    
    
    glVertexAttribPointer(VVZ_ATTRIBUTE_COLOR,3,GL_FLOAT,GL_FALSE,0,NULL);
    
    glEnableVertexAttribArray(VVZ_ATTRIBUTE_COLOR);
    
    glBindBuffer(GL_ARRAY_BUFFER,0);
    glBindVertexArray(0);
    
    //**************************************** Quads **********************************************
    
    
    const GLfloat quadsVertices[] =
    { 1.0f,1.0f,0.0f, //0
        -1.0f,1.0f,0.0f,
        -1.0f,-1.0f,0.0f,
        1.0f,-1.0f,0.0f,
    };
    
    glGenVertexArrays(1, &vao_quads);
    glBindVertexArray(vao_quads);
    
    glGenBuffers(1, &vbo_quads_position);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quads_position);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadsVertices), quadsVertices, GL_STATIC_DRAW);
    
    glVertexAttribPointer(VVZ_ATTRIBUTE_VERTEX, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    
    glEnableVertexAttribArray(VVZ_ATTRIBUTE_VERTEX);
    
    glVertexAttrib3f(VVZ_ATTRIBUTE_COLOR, 0.0f, 0.0f, 1.0f);
    
    //  glEnableVertexAttribArray(VVZ_ATTRIBUTE_COLOR);
    
    glBindBuffer(GL_ARRAY_BUFFER,0);
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
    //********************  Triangle ***************
    vmath::mat4 modelViewMatrix = vmath::mat4::identity();
    modelViewMatrix=vmath::translate(-2.0f,0.0f,-6.0f);
    
    vmath::mat4 rotationMatrix = vmath::mat4::identity();
    rotationMatrix = vmath::rotate(angleRotate,0.0f,1.0f,0.0f);
    
    modelViewMatrix = modelViewMatrix * rotationMatrix;
    vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();
    modelViewProjectionMatrix = perspectiveGraphicProjectionMatrix*modelViewMatrix;
    
    glUniformMatrix4fv(mvpUniform,1,GL_FALSE,modelViewProjectionMatrix);
    
    glBindVertexArray(vao_triangle);
    
    glDrawArrays(GL_TRIANGLES,0,3);
    
    glBindVertexArray(0);
    
    //********************  Quads  ***************
    
    modelViewMatrix = vmath::mat4::identity();
    modelViewMatrix=vmath::translate(2.0f,0.0f,-6.0f);
    
    rotationMatrix = vmath::mat4::identity();
    rotationMatrix = vmath::rotate(angleRotate,1.0f,0.0f,0.0f);
    
    modelViewMatrix = modelViewMatrix * rotationMatrix;
    modelViewProjectionMatrix = vmath::mat4::identity();
    modelViewProjectionMatrix = perspectiveGraphicProjectionMatrix*modelViewMatrix;
    
    glUniformMatrix4fv(mvpUniform,1,GL_FALSE,modelViewProjectionMatrix);
    
    glBindVertexArray(vao_quads);
    
    glDrawArrays(GL_TRIANGLE_FAN,0,4);
    
    glBindVertexArray(0);
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


