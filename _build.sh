#!/bin/bash

KERNEL_DIR=$PWD

BUILD_DEVICE=$1
BUILD_TARGET=$2
BUILD_SELECT=$3

cpoy_initramfs()
{
  if [ -d $INITRAMFS_TMP_DIR ]; then
    rm -rf $INITRAMFS_TMP_DIR  
  fi
  cp -a $INITRAMFS_SRC_DIR $(dirname $INITRAMFS_TMP_DIR)
  rm -rf $INITRAMFS_TMP_DIR/.git
  find $INITRAMFS_TMP_DIR -name .gitignore | xargs rm
}

if [ ! -n "$BUILD_DEVICE" ]; then
  echo ""
  read -p "select device? [L04E] " BUILD_DEVICE
fi

# device setting
if [ "$BUILD_DEVICE" = 'L04E' ]; then
  LG_DEFCONFIG=tak_l04e_lge_defconfig
  REC_DEFCONFIG=tak_l04e_lge_defconfig
  MOD_VERSION=l04e_mod_version
  BOOT_RAMDISK_NAME=l04e_boot_ramdisk
  RECOVERY_RAMDISK_NAME=l04e_recovery_ramdisk
  KERNEL_BASE_ADDRESS=0x80200000
  KERNEL_RAMDISK_OFFSET=0x02000000

else
  echo "error: not found BUILD_DEVICE"
  exit -1
fi

if [ ! -n "$BUILD_TARGET" ]; then
  echo "error: not found BUILD_TARGET"
  exit -1
fi

# check target
case "$BUILD_TARGET" in
  "LG" ) BUILD_DEFCONFIG=$LG_DEFCONFIG ;;
  * ) echo "error: not found BUILD_TARGET" && exit -1 ;;
esac

BIN_DIR=out/$BUILD_TARGET/bin
OBJ_DIR=out/$BUILD_TARGET/obj
mkdir -p $BIN_DIR
mkdir -p $OBJ_DIR

# generate LOCALVERSION
. $MOD_VERSION

# check and get compiler
if [ `uname` = "Darwin" ]; then
  . cross_compile_darwin
elif [ `uname` = "Linux" ]; then
  . cross_compile_linux
fi

# set build env
export ARCH=arm
export CROSS_COMPILE=$BUILD_CROSS_COMPILE
export LOCALVERSION="-$BUILD_LOCALVERSION"

echo "=====> BUILD START $BUILD_KERNELVERSION-$BUILD_LOCALVERSION"

if [ ! -n "$3" ]; then
  echo ""
  read -p "select build? [(a)ll/(u)pdate/(i)mage default:update] " BUILD_SELECT
else
  BUILD_SELECT=$3
fi

# copy initramfs
if [ "$BUILD_TARGET" = 'RECO' ]; then
  INITRAMFS_SRC_DIR=../$RECOVERY_RAMDISK_NAME
  INITRAMFS_TMP_DIR=/tmp/$RECOVERY_RAMDISK_NAME
  IMAGE_NAME=recovery
else
  INITRAMFS_SRC_DIR=../$BOOT_RAMDISK_NAME
  INITRAMFS_TMP_DIR=/tmp/$BOOT_RAMDISK_NAME
  IMAGE_NAME=boot
fi
echo ""
echo "=====> copy initramfs"
cpoy_initramfs


# make start
if [ "$BUILD_SELECT" = 'all' -o "$BUILD_SELECT" = 'a' ]; then
  echo ""
  echo "=====> cleaning"
  make clean
  cp -f ./arch/arm/configs/$BUILD_DEFCONFIG $OBJ_DIR/.config
  make -C $PWD O=$OBJ_DIR oldconfig || exit -1
fi

if [ "$BUILD_SELECT" != 'image' -a "$BUILD_SELECT" != 'i' ]; then
  echo ""
  echo "=====> build start"
  if [ -e make.log ]; then
    mv make.log make_old.log
  fi
  nice -n 10 make O=$OBJ_DIR -j4 2>&1 | tee make.log
fi

# check compile error
COMPILE_ERROR=`grep 'error:' ./make.log`
if [ "$COMPILE_ERROR" ]; then
  echo ""
  echo "=====> ERROR"
  grep 'error:' ./make.log
  exit -1
fi

# *.ko replace
find -name '*.ko' -exec cp -av {} $INITRAMFS_TMP_DIR/lib/modules/ \;

echo ""
echo "=====> CREATE RELEASE IMAGE"
# clean release dir
if [ `find $BIN_DIR -type f | wc -l` -gt 0 ]; then
  rm -rf $BIN_DIR/*
fi
mkdir -p $BIN_DIR

# copy zImage
cp $OBJ_DIR/arch/arm/boot/zImage $BIN_DIR/kernel
if [ `uname` = "Darwin" ]; then
  echo "----- Making uncompressed $IMAGE_NAME ramdisk ------"
  ./release-tools/darwin/mkbootfs $INITRAMFS_TMP_DIR > $BIN_DIR/ramdisk-$IMAGE_NAME.cpio
  echo "----- Making $IMAGE_NAME ramdisk ------"
  ./release-tools/darwin/minigzip < $BIN_DIR/ramdisk-$IMAGE_NAME.cpio > $BIN_DIR/ramdisk-$IMAGE_NAME.img
  echo "----- Making $IMAGE_NAME image ------"
  ./release-tools/darwin/mkbootimg --cmdline "vmalloc=600M console=ttyHSL0,115200,n8 lpj=67677 user_debug=31 msm_rtb.filter=0x0 ehci-hcd.park=3 coresight-etm.boot_enable=0 androidboot.hardware=geefhd" --kernel $BIN_DIR/kernel  --ramdisk $BIN_DIR/ramdisk-$IMAGE_NAME.img --base $KERNEL_BASE_ADDRESS --pagesize 2048 --ramdisk_offset $KERNEL_RAMDISK_OFFSET --output $BIN_DIR/$IMAGE_NAME.img
elif [ `uname` = "Linux" ]; then
  echo "----- Making uncompressed $IMAGE_NAME ramdisk ------"
  ./release-tools/linux/mkbootfs $INITRAMFS_TMP_DIR > $BIN_DIR/ramdisk-$IMAGE_NAME.cpio
  echo "----- Making $IMAGE_NAME ramdisk ------"
  ./release-tools/linux/minigzip < $BIN_DIR/ramdisk-$IMAGE_NAME.cpio > $BIN_DIR/ramdisk-$IMAGE_NAME.img
  echo "----- Making $IMAGE_NAME image ------"
  ./release-tools/linux/mkbootimg --cmdline "vmalloc=600M console=ttyHSL0,115200,n8 lpj=67677 user_debug=31 msm_rtb.filter=0x0 ehci-hcd.park=3 coresight-etm.boot_enable=0 androidboot.hardware=geefhd" --kernel $BIN_DIR/kernel  --ramdisk $BIN_DIR/ramdisk-$IMAGE_NAME.img --base $KERNEL_BASE_ADDRESS --pagesize 2048 --ramdisk_offset $KERNEL_RAMDISK_OFFSET --output $BIN_DIR/$IMAGE_NAME.img
fi

# create cwm image
cd $BIN_DIR
if [ -d tmp ]; then
  rm -rf tmp
fi
mkdir -p ./tmp/META-INF/com/google/android
cp $IMAGE_NAME.img ./tmp/
cp $KERNEL_DIR/release-tools/update-binary ./tmp/META-INF/com/google/android/
sed -e "s/@VERSION/$BUILD_LOCALVERSION/g" $KERNEL_DIR/release-tools/$BUILD_DEVICE/updater-script-$IMAGE_NAME.sed > ./tmp/META-INF/com/google/android/updater-script
cd tmp && zip -rq ../cwm.zip ./* && cd ../
SIGNAPK_DIR=$KERNEL_DIR/release-tools/signapk
java -jar $SIGNAPK_DIR/signapk.jar $SIGNAPK_DIR/testkey.x509.pem $SIGNAPK_DIR/testkey.pk8 cwm.zip $BUILD_LOCALVERSION-$IMAGE_NAME-signed.zip
rm cwm.zip
rm -rf tmp
echo "  $BIN_DIR/$BUILD_LOCALVERSION-$IMAGE_NAME-signed.zip"

cd $KERNEL_DIR
echo ""
echo "=====> BUILD COMPLETE $BUILD_KERNELVERSION-$BUILD_LOCALVERSION"
exit 0
