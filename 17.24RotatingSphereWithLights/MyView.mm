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

	GLuint gNumElements;
	GLuint gNumVertices;
	float sphere_vertices[1146];
	float sphere_normals[1146];
	float sphere_textures[764];

	short sphere_elements[2280];
        

	GLuint gVao_sphere;
	GLuint gVbo_sphere_position;
	GLuint gVbo_sphere_normal;
	GLuint gVbo_sphere_element;
        
        GLfloat angleRotateRed;
        GLfloat angleRotateGreen;
        GLfloat angleRotateBlue;
        
	GLuint model_matrix_uniform, view_matrix_uniform, projection_matrix_uniform;

        GLuint La_uniform;
	GLuint Ls_uniform;

	GLuint Ld_uniform_red;
	GLuint light_position_uniform_red;

	GLuint Ld_uniform_green;
	GLuint light_position_uniform_green;

	GLuint Ld_uniform_blue;
	GLuint light_position_uniform_blue;

	GLuint ka_uniform;
	GLuint kd_uniform;
	GLuint ks_uniform;
	GLuint materialShininessUniform;
        
        GLuint gLKeyPressedUniform;
        
        bool gbLight, bIsLKeyPressed;

        GLfloat width,height;
        
        vmath::mat4 gPerspectiveProjectionMatrix;
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
        printf("Can not create Log file.\n Exiting now...\n");
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
    angleRotateRed = 90;
    angleRotateGreen = 180;
    angleRotateBlue = 260;
    
    // print OpenGL Info
    fprintf(gpFile,"OpenGL Version  : %s\n",glGetString(GL_VERSION)); //glGetString is pure opengl function
    fprintf(gpFile,"GLSL Version    : %s\n",glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [[self openGLContext]makeCurrentContext]; // In constructor we returned self (View object), where context was set. We are referring that context using self.context and asking to makeCurrentContext
    
    GLint swapInt=1;
    [[self openGLContext]setValues:&swapInt forParameter:NSOpenGLCPSwapInterval]; // to avoid tearing intervals.
    
    //**************************************** Vertex shader **********************************************
    
    vertexShaderObject = glCreateShader(GL_VERTEX_SHADER);
    
    const GLchar *vertexShaderSourceCode =
		"#version 410"\
    		"\n"\
		"in vec4 vPosition;" \
		"in vec3 vNormal;" \
		"uniform mat4 u_model_matrix;" \
		"uniform mat4 u_view_matrix;" \
		"uniform mat4 u_projection_matrix;" \
		"uniform vec4 u_light_position_red;" \
		"uniform vec4 u_light_position_green;" \
		"uniform vec4 u_light_position_blue;" \
		"uniform int u_lighting_enabled;" \
		"out vec3 transformed_normals;" \
		"out vec3 light_direction_red;" \
		"out vec3 light_direction_green;" \
		"out vec3 light_direction_blue;" \
		"out vec3 viewer_vector;" \
		"void main(void)" \
		"{" \
		"if(u_lighting_enabled==1)" \
		"{" \
		"vec4 eye_coordinates=u_view_matrix * u_model_matrix * vPosition;" \
		"transformed_normals=mat3(u_view_matrix * u_model_matrix) * vNormal;" \
		"light_direction_red = vec3(u_light_position_red) - eye_coordinates.xyz;"\
		"light_direction_green = vec3(u_light_position_green) - eye_coordinates.xyz;"\
		"light_direction_blue = vec3(u_light_position_blue) - eye_coordinates.xyz;"\
		"viewer_vector = -eye_coordinates.xyz;" \
		"}" \
		"gl_Position=u_projection_matrix * u_view_matrix * u_model_matrix * vPosition;" \
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
    		"#version 410"\
    		"\n"\
		"in vec3 transformed_normals;" \
		"in vec3 light_direction_red;" \
		"in vec3 light_direction_green;" \
		"in vec3 light_direction_blue;" \
		"in vec3 viewer_vector;" \
		"out vec4 FragColor;" \
		"uniform vec3 u_La;" \
		"uniform vec3 u_Ld_red;" \
		"uniform vec3 u_Ld_green;" \
		"uniform vec3 u_Ld_blue;" \
		"uniform vec3 u_Ls;" \
		"uniform vec3 u_Ka;" \
		"uniform vec3 u_Kd;" \
		"uniform vec3 u_Ks;" \
		"uniform float u_material_shininess;" \
		"uniform int u_lighting_enabled;" \
		"void main(void)" \
		"{" \
		"vec3 phong_ads_color;" \
		"if(u_lighting_enabled==1)" \
		"{" \
		"vec3 normalized_transformed_normals=normalize(transformed_normals);" \
		"vec3 normalized_light_direction=normalize(light_direction_red);" \
		"vec3 normalized_viewer_vector=normalize(viewer_vector);" \
		"vec3 ambient = u_La * u_Ka;" \
		"float tn_dot_ld = max(dot(normalized_transformed_normals, normalized_light_direction),0.0);" \
		"vec3 diffuse = u_Ld_red * u_Kd * tn_dot_ld;" \
		"vec3 reflection_vector = reflect(-normalized_light_direction, normalized_transformed_normals);" \
		"vec3 specular = u_Ls * u_Ks * pow(max(dot(reflection_vector, normalized_viewer_vector), 0.0), u_material_shininess);" \
		"phong_ads_color=ambient + diffuse + specular;" \

		"normalized_light_direction=normalize(light_direction_blue);" \
		"tn_dot_ld = max(dot(normalized_transformed_normals, normalized_light_direction),0.0);" \
		"diffuse = u_Ld_blue * u_Kd * tn_dot_ld;" \
		"reflection_vector = reflect(-normalized_light_direction, normalized_transformed_normals);" \
		"specular = u_Ls * u_Ks * pow(max(dot(reflection_vector, normalized_viewer_vector), 0.0), u_material_shininess);" \
		"phong_ads_color= phong_ads_color + (ambient + diffuse + specular);" \

		"normalized_light_direction=normalize(light_direction_green);" \
		"tn_dot_ld = max(dot(normalized_transformed_normals, normalized_light_direction),0.0);" \
		"diffuse = u_Ld_green * u_Kd * tn_dot_ld;" \
		"reflection_vector = reflect(-normalized_light_direction, normalized_transformed_normals);" \
		"specular = u_Ls * u_Ks * pow(max(dot(reflection_vector, normalized_viewer_vector), 0.0), u_material_shininess);" \
		"phong_ads_color= phong_ads_color + (ambient + diffuse + specular);" \

		"}" \
		"else" \
		"{" \
		"phong_ads_color = vec3(1.0, 1.0, 1.0);" \
		"}" \
		"FragColor = vec4(phong_ads_color, 1.0);" \
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
	model_matrix_uniform = glGetUniformLocation(shaderProgramObject, "u_model_matrix");
	view_matrix_uniform = glGetUniformLocation(shaderProgramObject, "u_view_matrix");
	projection_matrix_uniform = glGetUniformLocation(shaderProgramObject, "u_projection_matrix");
    
   
gLKeyPressedUniform = glGetUniformLocation(shaderProgramObject, "u_lighting_enabled");

	// ambient color intensity of light
	La_uniform = glGetUniformLocation(shaderProgramObject, "u_La");
	// specular color intensity of light
	Ls_uniform = glGetUniformLocation(shaderProgramObject, "u_Ls");

	Ld_uniform_red = glGetUniformLocation(shaderProgramObject, "u_Ld_red");
	light_position_uniform_red = glGetUniformLocation(shaderProgramObject, "u_light_position_red");;


	Ld_uniform_green = glGetUniformLocation(shaderProgramObject, "u_Ld_green");
	light_position_uniform_green = glGetUniformLocation(shaderProgramObject, "u_light_position_green");;

	Ld_uniform_blue = glGetUniformLocation(shaderProgramObject, "u_Ld_blue");
	light_position_uniform_blue = glGetUniformLocation(shaderProgramObject, "u_light_position_blue");;


	// ambient reflective color intensity of material
	ka_uniform = glGetUniformLocation(shaderProgramObject, "u_Ka");
	// diffuse reflective color intensity of material
	kd_uniform = glGetUniformLocation(shaderProgramObject, "u_Kd");
	// specular reflective color intensity of material
	ks_uniform = glGetUniformLocation(shaderProgramObject, "u_Ks");
	// shininess of material ( value is conventionally between 1 to 200 )
	materialShininessUniform = glGetUniformLocation(shaderProgramObject, "u_material_shininess");;

	// *** vertices, colors, shader attribs, vbo, vao initializations ***

	Sphere *sphere = new Sphere();
	sphere->getSphereVertexData(sphere_vertices, sphere_normals, sphere_textures, sphere_elements);

	gNumVertices = sphere->getNumberOfSphereVertices();
	gNumElements = sphere->getNumberOfSphereElements();

	// vao
	glGenVertexArrays(1, &gVao_sphere);
	glBindVertexArray(gVao_sphere);

	// position vbo
	glGenBuffers(1, &gVbo_sphere_position);
	glBindBuffer(GL_ARRAY_BUFFER, gVbo_sphere_position);
	glBufferData(GL_ARRAY_BUFFER, sizeof(sphere_vertices), sphere_vertices, GL_STATIC_DRAW);

	glVertexAttribPointer(VVZ_ATTRIBUTE_VERTEX, 3, GL_FLOAT, GL_FALSE, 0, NULL);

	glEnableVertexAttribArray(VVZ_ATTRIBUTE_VERTEX);


 
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
	glGenBuffers(1, &gVbo_sphere_normal);
	glBindBuffer(GL_ARRAY_BUFFER, gVbo_sphere_normal);
	glBufferData(GL_ARRAY_BUFFER, sizeof(sphere_normals), sphere_normals, GL_STATIC_DRAW);

	glVertexAttribPointer(VVZ_ATTRIBUTE_NORMAL, 3, GL_FLOAT, GL_FALSE, 0, NULL);

	glEnableVertexAttribArray(VVZ_ATTRIBUTE_NORMAL);

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	// element vbo
	glGenBuffers(1, &gVbo_sphere_element);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(sphere_elements), sphere_elements, GL_STATIC_DRAW);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

	glBindVertexArray(0);
  //*************************************************

    
    
    //glShadeModel(GL_SMOOTH);
    
    glClearDepth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    //glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    glEnable(GL_CULL_FACE);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    
    gPerspectiveProjectionMatrix = vmath::mat4::identity();

	gbLight = false;

    
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
    
     width=rect.size.width;
     height=rect.size.height;
    
    if(height==0)
        height=1;
    
    glViewport(0,0,(GLsizei)width,(GLsizei)height);
    
    
        gPerspectiveProjectionMatrix = vmath::perspective(45.0f,(GLfloat)width/(GLfloat)height,0.1f,100.0f);
    
    
    CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self drawView];
}

- (void)drawView
{

    GLfloat light_ambient[]={0.0,0.0,0.0};
    GLfloat light_specular[]={1.0,1.0,1.0};
    
    GLfloat light_diffuse[]={1.0,0.0,0.0};
    GLfloat light_position[]={100.0,100.0,100.0,1.0};
    
    
    GLfloat lightAmbient[]= {0.0f,0.0f,0.0f,1.0f};
    GLfloat lightSpecular[] = { 1.0f,1.0f,1.0f,1.0f };
    
    GLfloat lightDiffuseRed[] = { 1.0f,0.0f,0.0f,0.0f };
    GLfloat lightPositionRed[] = { 100.0f,100.0f,100.0f,1.0f };
    
    GLfloat lightDiffuseGreen[] = { 0.0f,1.0f,0.0f,0.0f };
    GLfloat lightPositionGreen[] = { 100.0f,100.0f,100.0f,1.0f };
    
    GLfloat lightDiffuseBlue[] = { 0.0f,0.0f,1.0f,0.0f };
    GLfloat lightPositionBlue[] = { 100.0f,100.0f,100.0f,1.0f };
    
    
    
    GLfloat material_ambient[]= {0.0,0.0,0.0};
    GLfloat material_diffuse[]= {1.0,1.0,1.0};
    GLfloat material_specular[]= {1.0,1.0,1.0};
    GLfloat material_shininess= 50.0;
    
    
    GLfloat s1_ambient_material[] = { 0.0215, 0.1745, 0.0215};
    GLfloat s1_difuse_material[] = { 0.07568, 0.61424, 0.07568};
    GLfloat s1_specular_material[] = { 0.633, 0.727811, 0.633};
    GLfloat s1_shininess =  0.6 * 128.0 ;
    
    GLfloat s2_ambient_material[] = { 0.135, 0.2225, 0.1575};
    GLfloat s2_difuse_material[] = { 0.54, 0.89, 0.63};
    GLfloat s2_specular_material[] = { 0.316228, 0.316228, 0.316228};
    GLfloat s2_shininess=0.1 * 128.0 ;
    
    GLfloat s3_ambient_material[] = { 0.05375, 0.05, 0.06625};
    GLfloat s3_difuse_material[] = { 0.18275, 0.17, 0.22525};
    GLfloat s3_specular_material[] = { 0.332741, 0.328634, 0.346435};
    GLfloat s3_shininess =  0.3 * 128.0;
    
    GLfloat s4_ambient_material[] = { 0.25, 0.20725, 0.20725};
    GLfloat s4_difuse_material[] = { 1.0, 0.829, 0.829};
    GLfloat s4_specular_material[] = { 0.296648, 0.296648, 0.296648};
    GLfloat s4_shininess = 0.088 * 128.0 ;
    
    GLfloat s5_ambient_material[] = { 0.1745, 0.01175, 0.01175};
    GLfloat s5_difuse_material[] = { 0.61424, 0.04136, 0.04136};
    GLfloat s5_specular_material[] = { 0.727811, 0.626959, 0.626959};
    GLfloat s5_shininess = 0.6 * 128.0 ;
    
    GLfloat s6_ambient_material[] = { 0.1, 0.18725, 0.1745};
    GLfloat s6_difuse_material[] = { 0.396, 0.74151, 0.69102};
    GLfloat s6_specular_material[] = { 0.297254, 0.30829, 0.306678};
    GLfloat s6_shininess = 0.1 * 128.0 ;
    
    GLfloat s7_ambient_material[] = { 0.329412, 0.223529, 0.027451};
    GLfloat s7_difuse_material[] = { 0.780392, 0.568627, 0.113725};
    GLfloat s7_specular_material[] = { 0.992157, 0.941176, 0.807843};
    GLfloat s7_shininess = 0.21794872 * 128.0;
    
    GLfloat s8_ambient_material[] = { 0.2125, 0.1275, 0.054};
    GLfloat s8_difuse_material[] = { 0.714, 0.4284, 0.18144};
    GLfloat s8_specular_material[] = { 0.393548, 0.271906, 0.166721};
    GLfloat s8_shininess = 0.2 * 128.0 ;
    
    GLfloat s9_ambient_material[] = { 0.25, 0.25, 0.25};
    GLfloat s9_difuse_material[] = { 0.4, 0.4, 0.4};
    GLfloat s9_specular_material[] = { 0.774597, 0.774597, 0.774597};
    GLfloat s9_shininess = 0.6 * 128.0 ;
    
    GLfloat s10_ambient_material[] = { 0.19125, 0.0735, 0.0225};
    GLfloat s10_difuse_material[] = { 0.7038, 0.27048, 0.0828};
    GLfloat s10_specular_material[] = { 0.256777, 0.137622, 0.086014};
    GLfloat s10_shininess = 0.1 *  128.0;
    
    GLfloat s11_ambient_material[] = { 0.24725, 0.1995, 0.0745};
    GLfloat s11_difuse_material[] = { 0.75164, 0.60648, 0.22648};
    GLfloat s11_specular_material[] = { 0.628281, 0.555802, 0.366065};
    GLfloat s11_shininess = 0.4 *  128.0;
    
    GLfloat s12_ambient_material[] = { 0.19225, 0.19225, 0.19225};
    GLfloat s12_difuse_material[] = { 0.50754, 0.50754, 0.50754};
    GLfloat s12_specular_material[] = { 0.508273, 0.508273, 0.508273};
    GLfloat s12_shininess = 0.4 *  128.0;
    
    GLfloat s13_ambient_material[] = { 0.0, 0.0, 0.0};
    GLfloat s13_difuse_material[] = { 0.01, 0.01, 0.01};
    GLfloat s13_specular_material[] = { 0.50, 0.50, 0.50};
    GLfloat s13_shininess = 0.25 *  128.0;
    
    GLfloat s14_ambient_material[] = { 0.0, 0.1, 0.06};
    GLfloat s14_difuse_material[] = { 0.0, 0.50980392, 0.50980392};
    GLfloat s14_specular_material[] = { 0.50196078, 0.50196078, 0.50196078};
    GLfloat s14_shininess = 0.25 *  128.0;
    
    GLfloat s15_ambient_material[] = { 0.0, 0.0, 0.0};
    GLfloat s15_difuse_material[] = { 0.1, 0.35, 0.1};
    GLfloat s15_specular_material[] = { 0.45, 0.55, 0.45};
    GLfloat s15_shininess = 0.25 *  128.0;
    
    GLfloat s16_ambient_material[] = { 0.0, 0.0, 0.0};
    GLfloat s16_difuse_material[] = { 0.5, 0.0, 0.0};
    GLfloat s16_specular_material[] = { 0.7, 0.6, 0.6};
    GLfloat s16_shininess = 0.25 *  128.0;
    
    GLfloat s17_ambient_material[] = { 0.0, 0.0, 0.0};
    GLfloat s17_difuse_material[] = { 0.55, 0.55, 0.55};
    GLfloat s17_specular_material[] = { 0.70, 0.70, 0.70};
    GLfloat s17_shininess = 0.25 *  128.0;
    
    GLfloat s18_ambient_material[] = { 0.0, 0.0, 0.0};
    GLfloat s18_difuse_material[] = { 0.5, 0.5, 0.0};
    GLfloat s18_specular_material[] = { 0.60, 0.60, 0.50};
    GLfloat s18_shininess = 0.25 *  128.0;
    
    GLfloat s19_ambient_material[] = { 0.02, 0.02, 0.02};
    GLfloat s19_difuse_material[] = { 0.01, 0.01, 0.01};
    GLfloat s19_specular_material[] = { 0.4, 0.4, 0.4};
    GLfloat s19_shininess = 0.078125 *  128.0;
    
    GLfloat s20_ambient_material[] = { 0.0, 0.05, 0.05};
    GLfloat s20_difuse_material[] = { 0.4, 0.5, 0.5};
    GLfloat s20_specular_material[] = { 0.04, 0.7, 0.7};
    GLfloat s20_shininess = 0.078125 *  128.0;
    
    GLfloat s21_ambient_material[] = { 0.0, 0.05, 0.0};
    GLfloat s21_difuse_material[] = { 0.4, 0.5, 0.4};
    GLfloat s21_specular_material[] = { 0.04, 0.7, 0.04};
    GLfloat s21_shininess = 0.078125 *  128.0;
    
    GLfloat s22_ambient_material[] = { 0.05, 0.0, 0.0};
    GLfloat s22_difuse_material[] = { 0.5, 0.4, 0.4};
    GLfloat s22_specular_material[] = { 0.7, 0.04, 0.04};
    GLfloat s22_shininess = 0.078125 *  128.0;
    
    GLfloat s23_ambient_material[] = { 0.05, 0.05, 0.05};
    GLfloat s23_difuse_material[] = { 0.5, 0.5, 0.5};
    GLfloat s23_specular_material[] = { 0.7, 0.7, 0.7};
    GLfloat s23_shininess = 0.078125 *  128.0;
    
    GLfloat s24_ambient_material[] = { 0.05, 0.05, 0.0};
    GLfloat s24_difuse_material[] = { 0.5, 0.5, 0.4};
    GLfloat s24_specular_material[] = { 0.7, 0.7, 0.04};
    GLfloat s24_shininess = 0.078125 *  128.0;
    
    GLfloat s25_ambient_material[] = { 0.05, 0.00, 0.4};
    GLfloat s25_difuse_material[] = { 0.4, 0.5, 0.4};
    GLfloat s25_specular_material[] = { 0.7, 0.7, 0.07};
    GLfloat s25_shininess = 0.078125 *  128.0;

    [[self openGLContext]makeCurrentContext];
    CGLLockContext((CGLContextObj)[[self openGLContext]CGLContextObj]);
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glUseProgram(shaderProgramObject);
    
    if (gbLight == true)
    {
      		 glUniform1i(gLKeyPressedUniform, 1);



			 lightPositionRed[0] = cos(angleRotateRed)*100.0;
			 lightPositionRed[1]=0.0;
			 lightPositionRed[2]=sin(angleRotateRed)*100.0;
			 lightPositionRed[3]=100.0;

			 lightPositionGreen[0] = 0.0;
			 lightPositionGreen[1]=cos(angleRotateGreen)*100.0;
			 lightPositionGreen[2]=sin(angleRotateGreen)*100.0;
			 lightPositionGreen[3]=100.0 ;

			 lightPositionBlue[0] = -cos(angleRotateBlue)*100.0;
			 lightPositionBlue[1]=0.0;
			 lightPositionBlue[2]=sin(angleRotateBlue)*100.0;
			 lightPositionBlue[3]=100.0;


		// setting light's properties
		glUniform3fv(La_uniform, 1, lightAmbient);
		glUniform3fv(Ls_uniform, 1, lightSpecular);

		glUniform3fv(Ld_uniform_red, 1, lightDiffuseRed);
		glUniform4fv(light_position_uniform_red, 1, lightPositionRed);

		glUniform3fv(Ld_uniform_green, 1, lightDiffuseGreen);
		glUniform4fv(light_position_uniform_green, 1, lightPositionGreen);

		glUniform3fv(Ld_uniform_blue, 1, lightDiffuseBlue);
		glUniform4fv(light_position_uniform_blue, 1, lightPositionBlue);

		// setting material's properties
		glUniform3fv(ka_uniform, 1, material_ambient);
		glUniform3fv(kd_uniform, 1, material_diffuse);
		glUniform3fv(ks_uniform, 1, material_specular);
		glUniform1f(materialShininessUniform, material_shininess);
        

    }
    else
    {
        glUniform1i(gLKeyPressedUniform, 0);
    }
    
    // OpenGL Drawing
    // set all matrices to identity
    vmath::mat4 modelMatrix = vmath::mat4::identity();
    vmath::mat4 viewMatrix = vmath::mat4::identity();
    
	//vmath::mat4 rotationMatrix = vmath::mat4::identity();
    
    // apply z axis translation to go deep into the screen by -5.0,
    // so that triangle with same fullscreen co-ordinates, but due to above translation will look small
    modelMatrix = vmath::translate(0.0f, 0.0f, -8.0f);
    
    
	glUniformMatrix4fv(model_matrix_uniform, 1, GL_FALSE, modelMatrix);
	glUniformMatrix4fv(view_matrix_uniform, 1, GL_FALSE, viewMatrix);
	glUniformMatrix4fv(projection_matrix_uniform, 1, GL_FALSE, gPerspectiveProjectionMatrix);
 
    
    //*************************** 1 line ******************************************************************************
    
glViewport(0, 864, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s1_ambient_material);
    glUniform3fv(kd_uniform,1,s1_difuse_material);
    glUniform3fv(ks_uniform,1,s1_specular_material);
    glUniform1f(materialShininessUniform, s1_shininess);
    
    // *** bind vao ***
    glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    

    
    //-----
    
    glViewport(384, 864, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s2_ambient_material);
    glUniform3fv(kd_uniform,1,s2_difuse_material);
    glUniform3fv(ks_uniform,1,s2_specular_material);
    glUniform1f(materialShininessUniform, s2_shininess);
    
    glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //-----
    
    glViewport(768, 864, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s3_ambient_material);
    glUniform3fv(kd_uniform,1,s3_difuse_material);
    glUniform3fv(ks_uniform,1,s3_specular_material);
    glUniform1f(materialShininessUniform, s3_shininess);
    
    glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    //-----
    
    glViewport(1156, 864, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s4_ambient_material);
    glUniform3fv(kd_uniform,1,s4_difuse_material);
    glUniform3fv(ks_uniform,1,s4_specular_material);
    glUniform1f(materialShininessUniform, s4_shininess);
    
    
    glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    //-----
    
    glViewport(1536, 864, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s5_ambient_material);
    glUniform3fv(kd_uniform,1,s5_difuse_material);
    glUniform3fv(ks_uniform,1,s5_specular_material);
    glUniform1f(materialShininessUniform, s5_shininess);
    
    
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //*************************** 2 line ******************************************************************************
    
    
    glViewport(0, 648, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s25_ambient_material);
    glUniform3fv(kd_uniform,1,s25_difuse_material);
    glUniform3fv(ks_uniform,1,s25_specular_material);
    glUniform1f(materialShininessUniform, s25_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //------
    
    glViewport(384, 648, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s6_ambient_material);
    glUniform3fv(kd_uniform,1,s6_difuse_material);
    glUniform3fv(ks_uniform,1,s6_specular_material);
    glUniform1f(materialShininessUniform, s6_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //-------
    
    glViewport(768, 648, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s7_ambient_material);
    glUniform3fv(kd_uniform,1,s7_difuse_material);
    glUniform3fv(ks_uniform,1,s7_specular_material);
    glUniform1f(materialShininessUniform, s7_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //-------
    
    glViewport(1156, 648, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s8_ambient_material);
    glUniform3fv(kd_uniform,1,s8_difuse_material);
    glUniform3fv(ks_uniform,1,s8_specular_material);
    glUniform1f(materialShininessUniform, s8_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //-------
    
    glViewport(1536, 648, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s9_ambient_material);
    glUniform3fv(kd_uniform,1,s9_difuse_material);
    glUniform3fv(ks_uniform,1,s9_specular_material);
    glUniform1f(materialShininessUniform, s9_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //*************************** 3 line ******************************************************************************
    
    glViewport(0, 432, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s10_ambient_material);
    glUniform3fv(kd_uniform,1,s10_difuse_material);
    glUniform3fv(ks_uniform,1,s10_specular_material);
    glUniform1f(materialShininessUniform, s10_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //--------
    
    glViewport(384, 432, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s11_ambient_material);
    glUniform3fv(kd_uniform,1,s11_difuse_material);
    glUniform3fv(ks_uniform,1,s11_specular_material);
    glUniform1f(materialShininessUniform, s11_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //-------
    
    glViewport(768, 432, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s12_ambient_material);
    glUniform3fv(kd_uniform,1,s12_difuse_material);
    glUniform3fv(ks_uniform,1,s12_specular_material);
    glUniform1f(materialShininessUniform, s12_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //-------
    
    glViewport(1156, 432, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s13_ambient_material);
    glUniform3fv(kd_uniform,1,s13_difuse_material);
    glUniform3fv(ks_uniform,1,s13_specular_material);
    glUniform1f(materialShininessUniform, s13_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //-------
    
    glViewport(1536, 432, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s14_ambient_material);
    glUniform3fv(kd_uniform,1,s14_difuse_material);
    glUniform3fv(ks_uniform,1,s14_specular_material);
    glUniform1f(materialShininessUniform, s14_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //*************************** 4 line ******************************************************************************
    
    glViewport(0, 216, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s15_ambient_material);
    glUniform3fv(kd_uniform,1,s15_difuse_material);
    glUniform3fv(ks_uniform,1,s15_specular_material);
    glUniform1f(materialShininessUniform, s15_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //-----
    
    glViewport(384, 216, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s16_ambient_material);
    glUniform3fv(kd_uniform,1,s16_difuse_material);
    glUniform3fv(ks_uniform,1,s16_specular_material);
    glUniform1f(materialShininessUniform, s16_shininess);
    
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //------
    
    glViewport(768, 216, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s17_ambient_material);
    glUniform3fv(kd_uniform,1,s17_difuse_material);
    glUniform3fv(ks_uniform,1,s17_specular_material);
    glUniform1f(materialShininessUniform, s17_shininess);
    
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //------
    
    glViewport(1156, 216, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s18_ambient_material);
    glUniform3fv(kd_uniform,1,s18_difuse_material);
    glUniform3fv(ks_uniform,1,s18_specular_material);
    glUniform1f(materialShininessUniform, s18_shininess);
    
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //------
    
    glViewport(1536, 216, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s19_ambient_material);
    glUniform3fv(kd_uniform,1,s19_difuse_material);
    glUniform3fv(ks_uniform,1,s19_specular_material);
    glUniform1f(materialShininessUniform, s19_shininess);
    
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //*************************** 5 line
    
    glViewport(0, 0, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s20_ambient_material);
    glUniform3fv(kd_uniform,1,s20_difuse_material);
    glUniform3fv(ks_uniform,1,s20_specular_material);
    glUniform1f(materialShininessUniform, s20_shininess);
    
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //-------
    
    glViewport(384, 0, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s21_ambient_material);
    glUniform3fv(kd_uniform,1,s21_difuse_material);
    glUniform3fv(ks_uniform,1,s21_specular_material);
    glUniform1f(materialShininessUniform, s21_shininess);
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //------
    
    glViewport(768, 0, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s22_ambient_material);
    glUniform3fv(kd_uniform,1,s22_difuse_material);
    glUniform3fv(ks_uniform,1,s22_specular_material);
    glUniform1f(materialShininessUniform, s22_shininess);
    
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //------
    
    glViewport(1156, 0, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s23_ambient_material);
    glUniform3fv(kd_uniform,1,s23_difuse_material);
    glUniform3fv(ks_uniform,1,s23_specular_material);
    glUniform1f(materialShininessUniform, s23_shininess);
    
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);
    
    //------
    
    glViewport(1536, 0, (GLsizei)width/4, (GLsizei)height/4);
    
    
    glUniform3fv(ka_uniform,1,s24_ambient_material);
    glUniform3fv(kd_uniform,1,s24_difuse_material);
    glUniform3fv(ks_uniform,1,s24_specular_material);
    glUniform1f(materialShininessUniform, s24_shininess);
    
       glBindVertexArray(gVao_sphere);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gVbo_sphere_element);
    glDrawElements(GL_TRIANGLES, gNumElements, GL_UNSIGNED_SHORT, 0);
    glBindVertexArray(0);


//*********************************************
    // stop using OpenGL program object
    glUseProgram(0);

    [self updateAngleRotateRed];
    [self updateAngleRotateGreen];
    [self updateAngleRotateBlue];

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

-(void) updateAngleRotateRed
{
    if (angleRotateRed==360.0f)
        angleRotateRed=0.0f;
    else
        angleRotateRed=angleRotateRed+0.1f;
}

-(void) updateAngleRotateGreen
{
    if (angleRotateGreen==360.0f)
        angleRotateGreen=0.0f;
    else
        angleRotateGreen=angleRotateGreen+0.1f;
}

-(void) updateAngleRotateBlue
{
    if (angleRotateBlue==360.0f)
        angleRotateBlue=0.0f;
    else
        angleRotateBlue=angleRotateBlue+0.1f;
}



@end

//Global function
CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink,const CVTimeStamp *pNow,const CVTimeStamp *pOutputTime,CVOptionFlags flagsIn,
                               CVOptionFlags *pFlagsOut,void *pDisplayLinkContext)
{
    CVReturn result=[(MyView *)pDisplayLinkContext getFrameForTime:pOutputTime];
    return(result);
}


