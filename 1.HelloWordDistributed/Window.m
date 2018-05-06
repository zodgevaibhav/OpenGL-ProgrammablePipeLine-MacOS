
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "MyView.h"
#import "AppDeligate.h"



// Entry-point function
int main(int argc, const char * argv[])
{
    // code
    NSAutoreleasePool *pPool=[[NSAutoreleasePool alloc]init];
    
    NSApp=[NSApplication sharedApplication];

    [NSApp setDelegate:[[AppDelegate alloc]init]];
    
    [NSApp run];
    
    [pPool release];
    
    return(0);
}