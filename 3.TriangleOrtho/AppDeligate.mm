#import "AppDeligate.h"

FILE *gpFile;
@implementation AppDelegate

//Class variables should declare under curly bracket We can not initialize variable while declaraction, there nmust initialize in constructor only
{
@private // declaratio of two global variables as private
    NSWindow *window;   //using window object directly from NSWindow
    MyView *view;  // view used from our own view and not NSView, because we need some more methods under view
}

// method under AppDeligate class. - sign indicates instance variable & + sign indicates static method
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification //createWindow. WMCreate message. Window Server send this message to NSApp & NSApp deligate this to AppDeligate
{
// NSNotificatuin contain, IMSG, WPARAM, LPARAM (sender, what, parameter of what) 

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
    
    // window width and height
    NSRect win_rect;
    win_rect=NSMakeRect(0.0,0.0,800.0,600.0); // x, y, width, height, this function derived from Carbon. All carbon based functions are 'C' based. And Cocoa based functions are Objective-C
    // x, y = NSPoint,     width,height=NSSize
    // create simple window
    
    window=[[NSWindow alloc] initWithContentRect:win_rect  //NSWindow instance created with constructor call initWithContentRect and parameter sent as winRect
                                       styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                         backing:NSBackingStoreBuffered
                                           defer:NO];
    [window setTitle:@"Triangle Ortho"];
    [window center];
    
    view=[[MyView alloc]initWithFrame:win_rect];
    
    [window setContentView:view];  //window.setContentView(view)
    [window setDelegate:self];
    [window makeKeyAndOrderFront:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification  //wmDestroy
{
    fprintf(gpFile,"***** Program is terminated successfilly. \n");
    if(gpFile)
    {
        fclose(gpFile);
        gpFile=NULL;
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    // code
    [NSApp terminate:self];
}

- (void)dealloc
{
    // code
    [view release];
    
    [window release];
    
    [super dealloc]; //ask super to dealloc me/self
}
@end
