#!/bin/sh
# Type './build.sh' to make iOS libraries.
# Type './build.sh -arch arm64' to make iOS libraries for iOS 64-bit.
# Type './build.sh clean' to remove object files.

if [ ! -f ../../vgcore/ios/build.sh ] ; then
    git clone https://github.com/rhcad/vgcore ../../vgcore
fi
if [ ! -f ../../vgios/build.sh ] ; then
    git clone https://github.com/rhcad/vgios ../../vgios
fi

xcodebuild -project TouchVGPlay/TouchVGPlay.xcodeproj $1 $2 -configuration Release -alltargets

mkdir -p output/TouchVGPlay
cp -R TouchVGPlay/build/Release-universal/*.a output
cp -R TouchVGPlay/build/Release-universal/include/TouchVGPlay/*.h output/TouchVGPlay

if [ ! -f output/libTouchVG.a ] ; then
    cd ../../vgios
    sh build.sh $1 $2
    cd ../vgplay/ios
fi

mkdir -p output/TouchVG
mkdir -p output/TouchVGCore
cp -R ../../vgios/output/*.a output
cp -R ../../vgios/output/TouchVGCore/*.h output/TouchVG
cp -R ../../vgcore/ios/output/TouchVGCore/*.h output/TouchVGCore
