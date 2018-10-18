mkdir -p Window.app/Contents/MacOS
clang++ -o Window.app/Contents/MacOS/Window *.mm -framework Cocoa -framework QuartzCore -framework OpenGL
