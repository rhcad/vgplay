#!/bin/sh
# Type './build.sh' to make Android native libraries.
# Type './build.sh -B' to rebuild the native libraries.
# Type `./build.sh -swig` to re-generate JNI classes too.
# Type `./build.sh APP_ABI=x86` to build for the x86 Emulator.
#
if [ "$1"x = "-swig"x ] || [ ! -f vgplay_java_wrap.cpp ] ; then # Make JNI classes
    mkdir -p ../src/rhcad/vgplay/core
    rm -rf ../src/rhcad/vgplay/core/*.*
    
    swig -c++ -java -package rhcad.vgplay.core -D__ANDROID__ \
        -outdir ../src/rhcad/vgplay/core \
        -o vgplay_java_wrap.cpp \
        -I../../../../vgcore/core/include \
        -I../../../core \
          ../../../core/vgplay.i
    python replacejstr.py
fi
if [ "$1"x = "-swig"x ] ; then
    ndk-build $2
else
    ndk-build $1 $2
fi
