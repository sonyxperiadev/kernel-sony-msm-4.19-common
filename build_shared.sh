set -e
# Check if mkdtimg tool exist
if [ ! -f "$MKDTIMG" ]; then
    echo "mkdtimg: File not found!"
    echo "Building mkdtimg"
    export ALLOW_MISSING_DEPENDENCIES=true
    $ANDROID_ROOT/build/soong/soong_ui.bash --make-mode mkdtimg
fi

cd "$KERNEL_TOP"/kernel

echo "================================================="
echo "Your Environment:"
echo "ANDROID_ROOT: ${ANDROID_ROOT}"
echo "KERNEL_TOP  : ${KERNEL_TOP}"
echo "KERNEL_TMP  : ${KERNEL_TMP}"

for platform in $PLATFORMS; do \

    case $platform in
        edo)
            DEVICE=$EDO;
            DTBO="true";;
    esac

    for device in $DEVICE; do \
        (
            if [ ! $only_build_for ] || [ $device = $only_build_for ] ; then

                KERNEL_TMP=$KERNEL_TMP-${device}
                # Keep kernel tmp when building for a specific device or when using keep tmp
                [ ! "$keep_kernel_tmp" ] && [ ! "$only_build_for" ] &&rm -rf "${KERNEL_TMP}"
                mkdir -p "${KERNEL_TMP}"

                echo "================================================="
                echo "Platform -> ${platform} :: Device -> $device"
                make O="$KERNEL_TMP" ARCH=arm64 \
                                          CROSS_COMPILE=aarch64-linux-android- \
                                          CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                                          -j$(nproc) ${BUILD_ARGS} ${CC:+CC="${CC}"} \
                                          aosp_${platform}_${device}_defconfig

                echo "The build may take up to 10 minutes. Please be patient ..."
                echo "Building new kernel image ..."
                echo "Logging to $KERNEL_TMP/build.log"
                make O="$KERNEL_TMP" ARCH=arm64 \
                     CROSS_COMPILE=aarch64-linux-android- \
                     CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                     -j$(nproc) ${BUILD_ARGS} ${CC:+CC="${CC}"} \
                     >"$KERNEL_TMP"/build.log 2>&1;

                echo "Copying new kernel image ..."
                cp "$KERNEL_TMP/arch/arm64/boot/Image.gz-dtb" "$KERNEL_TOP/common-kernel/kernel-dtb-$device"
                if [ $DTBO = "true" ]; then
                    # shellcheck disable=SC2046
                    # note: We want wordsplitting in this case.
                    $MKDTIMG create "$KERNEL_TOP"/common-kernel/dtbo-${device}.img $(find "$KERNEL_TMP"/arch/arm64/boot/dts -name "*.dtbo")
                fi

            fi
        )
    done
done


echo "================================================="
echo "Done!"
