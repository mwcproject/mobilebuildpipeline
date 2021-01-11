#!/bin/sh

set -e
set -x

BASE_PATH=`pwd`

sudo apt update
sudo apt-get install expect
sudo apt-get install build-essential
sudo apt-get install mesa-common-dev

# Unpacking Java and QT
cat helpers/jdk-8u202-linux-x64/* | bzip2 -dc | tar xvf -
cat helpers/qt_5_15_2/* | bzip2 -dc | tar xvf -

# Java must be located at  jdk1.8.0_202
export JAVA_HOME=$BASE_PATH/jdk1.8.0_202

# Android SDK.
# Installing tools
unzip helpers/commandlinetools-linux-6858069_latest.zip
# Now installing SDK
mkdir android_sdk
export ANDROID_SDK_ROOT=$BASE_PATH/android_sdk
cmdline-tools/bin/sdkmanager --sdk_root=$ANDROID_SDK_ROOT  --update
yes | cmdline-tools/bin/sdkmanager --install --sdk_root=$ANDROID_SDK_ROOT "platforms;android-29" "build-tools;29.0.3" "ndk;22.0.7026061" "cmake;3.10.2.4988404"

# QT is located at Qt/5.15.2
export QT_HOME=$BASE_PATH/Qt/5.15.2

export ANDROID_HOME=$BASE_PATH/android_sdk
export ANDROID_NDK_PLATFORM="android-21"
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/22.0.7026061
#ANDROID_SDK_ROOT=
export QTDIR=$BASE_PATH/Qt/5.15.2/android
export PATH=$JAVA_HOME/bin:$QTDIR/bin:$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH

git clone https://github.com/mwcproject/mwc-qt-wallet.git
sed -i 's/ANDROID_ABIS = x86/ANDROID_ABIS = x86 x86_64 armeabi-v7a arm64-v8a/' mwc-qt-wallet/mwc-qt-mobile.pro

# Note, build is messy because we are using current directory for the build. It is fine for CI/CD, but if you do dev build you better to fix that

$QTDIR/bin/qmake $BASE_PATH/mwc-qt-wallet/mwc-qt-mobile.pro -spec android-clang CONFIG+=qtquickcompiler
$ANDROID_NDK_ROOT/prebuilt/linux-x86_64/bin/make qmake_all
$ANDROID_NDK_ROOT/prebuilt/linux-x86_64/bin/make -j8
$ANDROID_NDK_ROOT/prebuilt/linux-x86_64/bin/make INSTALL_ROOT=$BASE_PATH install
$QTDIR/bin/androiddeployqt --input $BASE_PATH/android-mwc-qt-mobile-deployment-settings.json --output $BASE_PATH --android-platform android-29 --jdk $JAVA_HOME --gradle

# apk is debug, it is not signed. But stil let's calculate md5
$RESULT_APK=$BASE_PATH/build/outputs/apk/debug/mobilebuildpipeline-debug.apk
$APK_NAME=mobilebuildpipeline-debug-$1.apk
cp $RESULT_APK $RESULT_APK
echo "sha256sum = `sha256sum $RESULT_APK`";
./scp.expect "$APK_NAME" $2
