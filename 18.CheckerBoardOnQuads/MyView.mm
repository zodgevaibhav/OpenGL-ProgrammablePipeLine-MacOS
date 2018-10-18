

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
    GLuint vertextShaderObject;
    GLuint fragmentShaderObject;
    GLuint shaderProgramObject;
    
    GLuint vao_triangle, vao_quads, vao_quads_tilted;
    GLuint vbo_triangle_position,vbo_triangle_texture;
    GLuint vbo_quads_position,vbo_quads_tilted_position,vbo_quads_texture;
    
    GLuint mvpUniform;
    GLuint textureSamplerUniform;

    int checkImageWidth;
    int checkImageHeight;
    
    GLubyte checkImage[64][64][4];
    GLuint    textureName;
    
    vmath::mat4 perspectiveGraphicProjectionMatrix;
}

-(id)initWithFrame:(NSRect)frame;
{
    
    self=[super initWithFrame:frame];  //initialize NSView by calling constructor of super and pass frame
    
    checkImageWidth=64;
    checkImageHeight=64;
    
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
    // ***** Code to get file location for log file ********
    NSBundle *mainBundle = [NSBundle mainBundle]; // to get path for log file we need to get bundle path (package path)
    NSString *appDirName = [mainBundle bundlePath]; //get directory name using bungle object
    NSString *parentDirPath = [appDirName stringByDeletingLastPathComponent];
    NSString *logFileNameWithPath = [NSString stringWithFormat:@"%@/Log.txt",parentDirPath];
    const char *pszLogFileNameWithPath=[logFileNameWithPath cStringUsingEncoding:NSASCIIStringEncoding];
    
    gpFile = fopen(pszLogFileNameWithPath,"w");
    
    if(gpFile==NULL)
    {
        fprintf(gpFile,"Can not create Log file. \n Exiting now...\n");
        [self release];
        [NSApp  terminate:self];
    }
    fprintf(gpFile,"**** Program started Successfully\n");
    
    // print OpenGL Info
    fprintf(gpFile,"OpenGL Version  : %s\n",glGetString(GL_VERSION)); //glGetString is pure opengl function
    fprintf(gpFile,"GLSL Version    : %s\n",glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [[self openGLContext]makeCurrentContext]; // In constructor we returned self (View object), where context was set. We are referring that context using self.context and asking to makeCurrentContext
    
    GLint swapInt=1;
    [[self openGLContext]setValues:&swapInt forParameter:NSOpenGLCPSwapInterval]; // to avoid tearing intervals.
    
    //**************************************** Vertex shader **********************************************
    vertextShaderObject = glCreateShader(GL_VERTEX_SHADER);
    
    const GLchar *vertexShaderSourceCode =
    "#version 410"\
    "\n"\
    "in vec4 vPosition;"\
    "in vec2 vTextureCords;"\
    "out vec2 outTextureCord;"\
    "uniform mat4 u_mvp_matrix;"\
    "void main(void)" \
    "{" \
    "gl_Position=u_mvp_matrix * vPosition;"\
    "outTextureCord = vTextureCords;"\
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
                fprintf(gpFile,"***** Vertex Shader Compilation Log : %s\n", szInfoLog);
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
    "in vec2 outTextureCord;"
    "uniform sampler2D u_texture0_sampler;" \
    "out vec4 FragColor;"
    "void main(void)" \
    "{" \
    "vec3 tex=vec3(texture(u_texture0_sampler, outTextureCord));" \
    "FragColor=vec4(tex, 1.0f);" \
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
                fprintf(gpFile,"***** Fragment Shader Compilation Log : %s\n", szInfoLog);
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
    
    
    glBindAttribLocation(shaderProgramObject, VVZ_ATTRIBUTE_VERTEX, "vPosition");
    glBindAttribLocation(shaderProgramObject, VVZ_ATTRIBUTE_TEXTURE0, "vTextureCords");
    
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
                fprintf(gpFile,"Shader Program Link Log : %s\n", szInfoLog);
                free(szInfoLog);
                [self release];
                [NSApp terminate:self];
            }
        }
    }
    
    //**************************************** END Link Shader program **********************************************
    
    mvpUniform = glGetUniformLocation(shaderProgramObject,"u_mvp_matrix");
    
    textureSamplerUniform=glGetUniformLocation(shaderProgramObject,"u_texture0_sampler");
    
    //********************* Load Texture from files **************************************************
  //  pyramidTexture = [self loadTextureFromBMPFile:"Smily.bmp"];
   // cubeTexture = [self loadTextureFromBMPFile:"Smily.bmp"];
    
    //**************************************** Quads **********************************************
    
    
    GLfloat quadsVertices[] =
    {
        
        // front surface
        1.0f, 1.0f, 1.0f,  // top-right of front
        -1.0f, 1.0f, 1.0f, // top-left of front
        -1.0f,-1.0f, 1.0f, // bottom-left of front
        1.0f,-1.0f, 1.0f,  // bottom-right of front
        
         };
    
    
    glGenVertexArrays(1, &vao_quads);
    glBindVertexArray(vao_quads);
    
    glGenBuffers(1, &vbo_quads_position);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quads_position);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadsVertices), quadsVertices, GL_STATIC_DRAW);
    
    glVertexAttribPointer(VVZ_ATTRIBUTE_VERTEX, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    
    glEnableVertexAttribArray(VVZ_ATTRIBUTE_VERTEX);
    
    glBindBuffer(GL_ARRAY_BUFFER,0);
    glBindVertexArray(0);
    
    const GLfloat quadTexture[]=
    {
        0.0f,0.0f,
        1.0f,0.0f,
        1.0f,1.0f,
        0.0f,1.0f,
    };
    
    glBindVertexArray(vao_quads);
    
    glGenBuffers(1,&vbo_quads_texture);
    glBindBuffer(GL_ARRAY_BUFFER,vbo_quads_texture);
    glBufferData(GL_ARRAY_BUFFER,sizeof(quadTexture),quadTexture,GL_STATIC_DRAW);
    
    
    glVertexAttribPointer(VVZ_ATTRIBUTE_TEXTURE0,2,GL_FLOAT,GL_FALSE,0,NULL);
    
    glEnableVertexAttribArray(VVZ_ATTRIBUTE_TEXTURE0);
    
    glBindBuffer(GL_ARRAY_BUFFER,0);
    glBindVertexArray(0);
    //************************************************* Quad Tilted *********************

  GLfloat quadsVertices_tilted[] =
    {
        
        2.41421f, 1.0f, -1.41421f, //right-top corner of front face
            1.0f, 1.0f, 0.0f, //left-top corner of front face
            1.0f, -1.0f, 0.0f, //left-bottom corner of front face
            2.41421f, -1.0f, -1.41421f, //right-bottom corner of front face
            
        
         };
    
    
    glGenVertexArrays(1, &vao_quads_tilted);
    glBindVertexArray(vao_quads_tilted);
    
    glGenBuffers(1, &vbo_quads_tilted_position);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_quads_tilted_position);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadsVertices_tilted), quadsVertices_tilted, GL_STATIC_DRAW);
    
    glVertexAttribPointer(VVZ_ATTRIBUTE_VERTEX, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    
    glEnableVertexAttribArray(VVZ_ATTRIBUTE_VERTEX);
    
    glBindBuffer(GL_ARRAY_BUFFER,0);
    glBindVertexArray(0);
    

    glBindVertexArray(vao_quads_tilted);
    
    glGenBuffers(1,&vbo_quads_texture);
    glBindBuffer(GL_ARRAY_BUFFER,vbo_quads_texture);
    glBufferData(GL_ARRAY_BUFFER,sizeof(quadTexture),quadTexture,GL_STATIC_DRAW);
    
    
    glVertexAttribPointer(VVZ_ATTRIBUTE_TEXTURE0,2,GL_FLOAT,GL_FALSE,0,NULL);
    
    glEnableVertexAttribArray(VVZ_ATTRIBUTE_TEXTURE0);
    
    glBindBuffer(GL_ARRAY_BUFFER,0);
    glBindVertexArray(0);


	//***********************************************************
    
    //glShadeModel(GL_SMOOTH);
    
    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    // glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    //glEnable(GL_CULL_FACE);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    
    perspectiveGraphicProjectionMatrix = vmath::mat4::identity();
    [self LoadGLTexture];

    
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
    modelViewMatrix=vmath::translate(-1.0f,0.0f,-6.0f);
    
  
    vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();
    modelViewProjectionMatrix = perspectiveGraphicProjectionMatrix*modelViewMatrix;
    
    glUniformMatrix4fv(mvpUniform,1,GL_FALSE,modelViewProjectionMatrix);
    
    glBindVertexArray(vao_quads);
    
    glBindTexture(GL_TEXTURE_2D,textureName);
    
    glDrawArrays(GL_TRIANGLE_FAN,0,4);

    
    glBindVertexArray(0);
   
	//******************** Quads Tilted

	modelViewMatrix = vmath::mat4::identity();
    modelViewMatrix=vmath::translate(0.0f,0.0f,-6.0f);
    
  
    	modelViewProjectionMatrix = vmath::mat4::identity();
    modelViewProjectionMatrix = perspectiveGraphicProjectionMatrix*modelViewMatrix;
    
    glUniformMatrix4fv(mvpUniform,1,GL_FALSE,modelViewProjectionMatrix);
    
    glBindVertexArray(vao_quads_tilted);
    
    glBindTexture(GL_TEXTURE_2D,textureName);
    
    glDrawArrays(GL_TRIANGLE_FAN,0,4);

    
    glBindVertexArray(0);




    glUseProgram(0);
    
    
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




-(void) LoadGLTexture
{
    
    [self MakeCheckImage];
    
    glGenTextures(1, &textureName); //1 - image
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4); //pixel storage mode (word alignment/4 bytes)
    
    glBindTexture(GL_TEXTURE_2D, textureName); //bind texture
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, checkImageWidth, checkImageHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, checkImage);
    
}

-(void) MakeCheckImage
{
    
    int i, j, c;
    
    for (i = 0; i<checkImageHeight; i++)
    {
        for (j = 0; j<checkImageWidth; j++)
        {
            c = (((i & 0x8) == 0) ^ ((j & 0x8) == 0)) * 255;
            
            checkImage[i][j][0] = (GLubyte)c;
            checkImage[i][j][1] = (GLubyte)c;
            checkImage[i][j][2] = (GLubyte)c;
            checkImage[i][j][3] = (GLubyte)255;
        }
    }
}

@end

//Global function
CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink,const CVTimeStamp *pNow,const CVTimeStamp *pOutputTime,CVOptionFlags flagsIn,
                               CVOptionFlags *pFlagsOut,void *pDisplayLinkContext)
{
    CVReturn result=[(MyView *)pDisplayLinkContext getFrameForTime:pOutputTime];
    return(result);
}


