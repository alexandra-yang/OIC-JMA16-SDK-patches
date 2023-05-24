#!/bin/bash

if [ $# != 2 ]; then
	echo "Illegal number of parameters"
	echo "Usage: ./build.sh <board_id> <fw_ver>"
	exit 1;
fi

BUILD_DIR="$PWD"
# To access FIRWARE DIRECTORY
FIRMWARE_DIR="${BUILD_DIR}/build_dir"

# To access private key
PRIVATE_KEY="${BUILD_DIR}/jio/jma16_keypair/private.pem"

CONFIG_SCRIPT="${BUILD_DIR}/qca/src/linux-4.4/scripts/config "
OPENWRT_DOT_CONFIG_FILE="${BUILD_DIR}/.config"
KERNEL_DOT_CONFIG_FILE="${BUILD_DIR}/target/linux/ipq/config-4.4"
CRASHDUMP_CONFIG_FILE="${BUILD_DIR}/qca/src/u-boot-2016/include/configs/ipq40xx.h"
OPENWRT_VMLINUX_ELF="${BUILD_DIR}/bin/ipq/openwrt-ipq-ipq40xx-vmlinux.elf"
IPQ_VMLINUX_ELF="${FIRMWARE_DIR}/target-arm_cortex-a7_musl-1.1.16_eabi/linux-ipq_ipq40xx/vmlinux.elf"

DEVICE_NAME=""
ODM_VENDOR=""
SW_VENDOR=""
FIRMWARE_VERSION=""
RELEASE_BUILD_R="R"
DEBUG_BUILD_D="D"
RELEASE_IMAGE_SW_VER_NAME=""
DEBUG_IMAGE_SW_VER_NAME=""
EXT=""

manageSerialConfig ()
{
       buildType=$1

       if [ "$buildType" != "D" ] && [ "$buildType" != "R" ]; then
               echo "Invalid Build Type"
               serialConfigStatus="ERROR"
               return
       fi

       if [ "$buildType" = "D" ]; then
               $CONFIG_SCRIPT --file $OPENWRT_DOT_CONFIG_FILE --disable CONFIG_JIO_FEATURE_DISABLE_SERIAL_CONSOLE_LOGIN
               grep "CONFIG_JIO_FEATURE_DISABLE_SERIAL_CONSOLE_LOGIN" $OPENWRT_DOT_CONFIG_FILE

       elif [ "$buildType" = "R" ]; then
               $CONFIG_SCRIPT --file $OPENWRT_DOT_CONFIG_FILE --enable CONFIG_JIO_FEATURE_DISABLE_SERIAL_CONSOLE_LOGIN
               grep "CONFIG_JIO_FEATURE_DISABLE_SERIAL_CONSOLE_LOGIN" $OPENWRT_DOT_CONFIG_FILE
       fi

       serialConfigStatus="OK"
}

manageCrashDumpFeature ()
{
       buildType=$1

       if [ "$buildType" != "D" ] && [ "$buildType" != "R" ]; then
               echo "Invalid Build Type"
               crashDumpStatus="ERROR"
               return
       fi

       if [ "$buildType" = "D" ]; then
               $CONFIG_SCRIPT --file $KERNEL_DOT_CONFIG_FILE --enable CONFIG_QCOM_DLOAD_MODE
               $CONFIG_SCRIPT --file $KERNEL_DOT_CONFIG_FILE --enable CONFIG_QCOM_DLOAD_MODE_APPSBL
               grep "CONFIG_QCOM_DLOAD_MODE_APPSBL\|CONFIG_QCOM_DLOAD_MODE" $KERNEL_DOT_CONFIG_FILE

               sed -i '/JIO_DISABLE_CRASHDUMP/d' $CRASHDUMP_CONFIG_FILE
               grep "/JIO_DISABLE_CRASHDUMP\|CONFIG_QCA_APPSBL_DLOAD" $CRASHDUMP_CONFIG_FILE

       elif [ "$buildType" = "R" ]; then
               $CONFIG_SCRIPT --file $KERNEL_DOT_CONFIG_FILE --disable CONFIG_QCOM_DLOAD_MODE
               $CONFIG_SCRIPT --file $KERNEL_DOT_CONFIG_FILE --disable CONFIG_QCOM_DLOAD_MODE_APPSBL
               grep "CONFIG_QCOM_DLOAD_MODE_APPSBL\|CONFIG_QCOM_DLOAD_MODE" $KERNEL_DOT_CONFIG_FILE

               sed -i '/JIO_DISABLE_CRASHDUMP/d' $CRASHDUMP_CONFIG_FILE
               sed -i '/define CONFIG_QCA_APPSBL_DLOAD/i /*JIO_DISABLE_CRASHDUMP' $CRASHDUMP_CONFIG_FILE
               sed -i '/define CONFIG_QCA_APPSBL_DLOAD/a JIO_DISABLE_CRASHDUMP*/' $CRASHDUMP_CONFIG_FILE
               grep "JIO_DISABLE_CRASHDUMP\|CONFIG_QCA_APPSBL_DLOAD" $CRASHDUMP_CONFIG_FILE
       fi

       crashDumpStatus="OK"
}

#jioluci feeds copy to package luci sdk
LUCI_VERSION="DEFAULT"
if [ "$1" = "jma16" ]; then
 ./feeds/jioluci/jioluci/cpjiolucifiles.sh ${BUILD_DIR} JMA16 ${LUCI_VERSION}
fi


if [ "$1" = "jma16" ]; then
	DEVICE_NAME="JMA16"
	ODM_VENDOR="SDMC"
	SW_VENDOR="JIO"
	FIRMWARE_VERSION=$2

	RELEASE_IMAGE_SW_VER_NAME="${ODM_VENDOR}${SW_VENDOR}_${DEVICE_NAME}_${RELEASE_BUILD_R}${FIRMWARE_VERSION}"
	DEBUG_IMAGE_SW_VER_NAME="${ODM_VENDOR}${SW_VENDOR}_${DEVICE_NAME}_${DEBUG_BUILD_D}${FIRMWARE_VERSION}"
	EXT=bin
	JOBS=`nproc`

	#for BUILD_TYPE in $DEBUG_BUILD_D $RELEASE_BUILD_R
	for BUILD_TYPE in $DEBUG_BUILD_D
	do
		cd $BUILD_DIR

		if [ $BUILD_TYPE = $DEBUG_BUILD_D ]; then
			FIRMWARE_NAME=$DEBUG_IMAGE_SW_VER_NAME
		else
			FIRMWARE_NAME=$RELEASE_IMAGE_SW_VER_NAME
		fi

		#make clean

                crashDumpStatus="ERROR"
                manageCrashDumpFeature $BUILD_TYPE
                if [ "$crashDumpStatus" = "ERROR" ]; then
                        echo "Exiting"
                        exit 1
                fi

                serialConfigStatus="ERROR"
                manageSerialConfig $BUILD_TYPE
                if [ "$serialConfigStatus" = "ERROR" ]; then
                        echo "Exiting"
                        exit 1
                fi

		echo "$FIRMWARE_NAME" > package/base-files/files/etc/sw_version
		echo `date +'%A, %B %d, %Y %R:%S %Z.'` > package/base-files/files/etc/sw_build_time
		sed -i -r "s/^(CONFIG_VERSION_NUMBER=).*/\1\"$FIRMWARE_NAME\"/" .config

		echo "******* $FIRMWARE_NAME MAKE STARTED *******"
		make -j$JOBS V=s  BACKHAUL_SSID=we.piranha BACKHAUL_PASS=welcome8  OPENSYNC_TARGET=DAKOTA OPENSYNC_SRC=/home/alex/Desktop/code/build_os_2/opensync/
		if [ $? -ne 0 ]; then
			echo "Make failed for $BUILD_TYPE Image"
			exit 1;
		fi

        	cd qca_fw_build_tools/
        	mkdir cnss_proc_ps
        	cp meta-scripts/ipq40xx_premium/* common/build/ipq
        	cp ../qca/src/u-boot-2016/tools/pack_legacy.py apss_proc/out/pack.py
        	cp -rf trustzone_images/build/ms/bin/MAZAANAA/* common/build/ipq
        	cp -rf ../bin/ipq/openwrt* common/build/ipq
        	cp boot_images/build/ms/bin/40xx/misc/tools/config/boardconfig_premium common/build/ipq
        	cp boot_images/build/ms/bin/40xx/misc/tools/config/appsboardconfig_premium common/build/ipq
        	cp -rf ../bin/ipq/dtbs/* common/build/ipq/
        	cp -rf skales/* common/build/ipq/
        	cd common/build
        	sed "s/'''$/\n'''/g" -i update_common_info.py
        	sed '/debug/d' -i update_common_info.py
        	sed '/skales/d' -i update_common_info.py
        	sed '/lkboot/d' -i update_common_info.py
        	export BLD_ENV_BUILD_ID=P
        	python update_common_info.py
		cp bin/nornand-ipq40xx-single.img ${FIRMWARE_DIR}/${FIRMWARE_NAME}.$EXT

                if [ "$BUILD_TYPE" = "$DEBUG_BUILD_D" ]; then
			echo "Saving vmlinux elf file from D build."
			mkdir -p ${FIRMWARE_DIR}/D-vmlinux
                        cp -a ${OPENWRT_VMLINUX_ELF} ${FIRMWARE_DIR}/D-vmlinux/openwrt-ipq-ipq40xx-vmlinux.elf
                        cp -a ${IPQ_VMLINUX_ELF} ${FIRMWARE_DIR}/D-vmlinux/vmlinux.elf
		else
			echo "Saving vmlinux elf file from R build."
			mkdir -p ${FIRMWARE_DIR}/R-vmlinux
                        cp -a ${OPENWRT_VMLINUX_ELF} ${FIRMWARE_DIR}/R-vmlinux/openwrt-ipq-ipq40xx-vmlinux.elf
                        cp -a ${IPQ_VMLINUX_ELF} ${FIRMWARE_DIR}/R-vmlinux/vmlinux.elf
                fi

		# used openssl command to generate signature file
		openssl dgst -sha256 -sign $PRIVATE_KEY -passin pass:jmamesh16 -out ${FIRMWARE_DIR}/${FIRMWARE_NAME}.sig ${FIRMWARE_DIR}/${FIRMWARE_NAME}.$EXT

		echo "$BUILD_TYPE build generation completed"
	done
fi

echo "******* COMPLETED *******"
