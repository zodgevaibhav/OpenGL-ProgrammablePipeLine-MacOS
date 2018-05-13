
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "MyView.h"
#import "AppDeligate.h"



int main(int argc, const char * argv[]) //const is optional
{
    // code
    NSAutoreleasePool *pPool=[[NSAutoreleasePool alloc]init]; // Variables to auto release (like garbage collection). By just declaring auto release gets enable. init is default constructor. 
    
    NSApp=[NSApplication sharedApplication]; //Request OS to give Window object. Similar to HINSTANCE or Display objects in XWindows. NSApp variable is global shared variable, we do not need to declare it. NSApplication is class with ShareApplication static method. 
    //NSApp is declared in Foundation. Cocoa gives view
    
    //AppDeligate *AppDeligate = [[AppDeligate alloc] init] ;  // this can be written instead below line
   // [NSApp setDelegate:AppDeligate;
    [NSApp setDelegate:[[AppDelegate alloc]init]];// provide our class name as deligate. So that all (implemented messages by AppDeligate class) messages received by NSApp will be deligated to AppDeligate. Ex. DidFinishLaunching
    
    
    [NSApp run]; //Start runLoop (message loop) 
    
    [pPool release]; // release pool after finishing runLoop 
    
    return(0);
}

