# TouchVGPlay

## Overview

A vector shape playing and animation framework for iOS and Android based on TouchVG.

Demos: [vgplay-ios](https://github.com/rhcad/vgplay-ios),
[vgplay-android](https://github.com/rhcad/vgplay-android).

## Features

- Vector shape playback and recording.
- One drawing, others playback synchronously (Shared whiteboard).
- Shape provider which can play any customized shape and animation.
- Spirit animation (animated GIF).
- Export shapes to CAShapeLayer for animation on path on iOS.

![](https://raw.githubusercontent.com/rhcad/vgplay-ios/demo/Screenshot/animatedlines.gif) |
![](https://raw.githubusercontent.com/rhcad/vgplay-ios/demo/Screenshot/spirit.gif) |
![](https://raw.githubusercontent.com/rhcad/vgplay-ios/demo/Screenshot/sharedboard.gif) |
![](https://raw.githubusercontent.com/rhcad/vgplay-ios/demo/Screenshot/anipath.gif) 

## Build

* Build for **iOS** platform on Mac OS X.

  > Cd the 'ios' folder of this project and type `./build.sh` to build `ios/output/libTouchVGPlay.a`.

* Build for **Android** platform on Mac, Linux or Windows.

  > Cd the 'android' folder of this project and type `./build.sh` to build
    with ndk-build. MinGW and MSYS are recommend on Windows.
  >
  > The library `libvgplay.so` will be outputed to `android/TouchVGPlay/libs/armeabi`.

## License

This is an open source [GPL v3.0](LICENSE) licensed project that is in active development.
Contributors and sponsors are welcome.

If you want to use TouchVGPlay in a commercial project (not open source), you need to apply for a
[business license](https://github.com/rhcad/vgplay/wiki/Apply-Business-License).

This project has been used in the following applications:

- Educational software, Beijing Founder Electronics Co., Ltd.
- TODO: Add a line about which company use it in what industry and application.

It uses the following open source projects:

- [vgios](https://github.com/rhcad/vgios) (BSD): Vector drawing framework for iOS.
- [vgandroid](https://github.com/rhcad/vgandroid) (BSD): Vector drawing framework for Android.
- [vgcore](https://github.com/rhcad/vgcore) (BSD): Cross-platform vector drawing libraries using C++.
