#!/bin/sh
# Type './build.sh' to make Android native libraries.
# Type './build.sh -B' to rebuild the native libraries.
# Type `./build.sh -swig` to re-generate JNI classes too.
# Type `./build.sh APP_ABI=x86` to build for the x86 Emulator.
#

if [ ! -f ../../vgandroid/build.sh ] ; then
    git clone https://github.com/rhcad/vgandroid ../../vgandroid
fi

cd ../../vgandroid; sh build.sh $1 $2; cd ../vgplay/android
cd TouchVGPlay/jni; sh build.sh $1 $2; cd ../..

if [ -n "$ANDROID_JAR" -a -f TouchVGPlay/bin/vgplay.jar ]; then
java -jar $ANDROID_SDK_HOME/tools/proguard/lib/proguard.jar @proguard/library.pro \
    -libraryjars $ANDROID_JAR \
    -libraryjars ../../vgandroid/TouchVG/libs/android-support-v4.jar \
    -libraryjars ../../vgandroid/TouchVG/bin/touchvg.jar
fi

mkdir -p output
cp -vR ../../vgandroid/TouchVG/bin/touchvg.jar  output
cp -vR ../../vgandroid/TouchVG/libs/armeabi     output
cp -vR ../../vgandroid/TouchVG/libs/x86         output
cp -vR             TouchVGPlay/libs/armeabi     output
cp -vR             TouchVGPlay/libs/x86         output
