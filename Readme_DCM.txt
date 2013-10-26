1. Android build
  - Download original android source code ( jelly bean 4.1.2_r1 ) from http://source.android.com
  - Unzip opensource packages of Android.zip into downloaded android source directory
  - And, merge the source into the android source code
  - Run following scripts to build android
    a) source build/envsetup.sh
    b) lunch
    c) make -j4
  - When you compile the android source code, you have to add google original prebuilt source(toolchain) into the android directory.
  - After build, you can find output at out/target/product/generic

2. Kernel Build  
  - Unzip opensource packages of Kernel.zip at the android directory
  - When you compile the kernel source code, you have to add google original prebuilt source(toolchain) into the android directory.
  - cd kernel
  - make ARCH=arm TARGET_PRODUCT=geevl04e_dcm_jp CROSS_COMPILE=../prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi- gvdcm_bcm-perf_defconfig zImage -j4
  - After build, you can find the build image(zImage) at arch/arm/boot/