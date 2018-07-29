#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import <QuartzCore/CVDisplayLink.h>

#import <OpenGL/gl3.h>
#import <OpenGL/gl3ext.h>

#import "vmath.h"
#import "Sphere.h"


// NSApplicationDelegate's method 1 ApplicationDidFinishLaunching
@interface MyView : NSOpenGLView // MyView extrnds NSView

-(void) updateAngleRotate;
@end
