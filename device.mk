#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2024 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/xiaomi/duchamp

# Hidl Service
PRODUCT_ENFORCE_VINTF_MANIFEST := true

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += $(DEVICE_PATH)

# Dynamic
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# API
PRODUCT_SHIPPING_API_LEVEL := 31
PRODUCT_TARGET_VNDK_VERSION := 34

# A/B
AB_OTA_UPDATER := true
ENABLE_VIRTUAL_AB := true
TARGET_ENFORCE_AB_OTA_PARTITION_LIST := true
AB_OTA_PARTITIONS += \
    apusys \
    audio_dsp \
    boot \
    ccu \
    dpm \
    dtbo \
    gpueb \
    gz \
    lk \
    logo \
    mcf_ota \
    mcupm \
    md1img \
    mvpu_algo \
    odm \
    odm_dlkm \
    pi_img \
    preloader_raw \
    product \
    scp \
    spmfw \
    sspm \
    system \
    system_ext \
    tee \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vcp \
    vendor \
    vendor_boot \
    vendor_dlkm \
    mi_ext

# A/B
AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/mtk_plpath_utils \
    FILESYSTEM_TYPE_system=erofs \
    POSTINSTALL_OPTIONAL_system=true

# Boot control HAL
#PRODUCT_PACKAGES += \
    android.hardware.boot@1.2-mtkimpl \
    android.hardware.boot@1.2-mtkimpl.recovery \
    bootctrl.mt6897.recovery

#PRODUCT_PACKAGES += \
    android.hardware.boot@1.2- \
    android.hardware.boot@1.2-impl.recovery \
    android.hardware.boot@1.2-service
PRODUCT_PACKAGES += \
    resetprop

PRODUCT_PACKAGES += \
    bootctrl.mt6897 \
    libgptutils \
    libz \
    libcutils \

PRODUCT_PACKAGES += \
    vold.recovery \
    vold_prepare_subdirs.recovery \
    wait_for_keymaster.recovery

PRODUCT_PACKAGES += \
    otapreopt_script \
    cppreopts.sh \
    update_engine \
    update_verifier \
    update_engine_sideload \
    checkpoint_gc

# Health
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-service \
    android.hardware.health@2.1-impl.recovery \
    android.hardware.health@2.1-service.rc

# Mtk plpath utils
#PRODUCT_PACKAGES += \
    mtk_plpath_utils \
    mtk_plpath_utils.recovery

# Keymaster
PRODUCT_PACKAGES += \
    android.hardware.keymaster@4.1

# Keymint
PRODUCT_PACKAGES += \
    android.hardware.security.keymint \
    android.hardware.security.secureclock \
    android.hardware.security.sharedsecret

# Keystore2
PRODUCT_PACKAGES += \
    android.system.keystore2

# Drm
PRODUCT_PACKAGES += \
    android.hardware.drm@1.4    

# Additional Target Libraries
TARGET_RECOVERY_DEVICE_MODULES += \
    android.hardware.keymaster@4.1 \
    android.hardware.vibrator-V1-ndk_platform \
    android.hardware.graphics.common@1.0 \
    libion \
    libxml2 \
    android.hardware.health@2.0-impl-default \
    android.hardware.boot@1.0

TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.keymaster@4.1.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.vibrator-V1-ndk_platform.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.graphics.common@1.0.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libion.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libxml2.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.health@2.0-impl-default.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.boot@1.0.so

# Recovery Blobs — KeyMint + Gatekeeper HAL for FBE decryption
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/vendor/bin/hw/android.hardware.security.keymint@3.0-service.mitee:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/bin/hw/android.hardware.security.keymint@3.0-service.mitee \
    $(LOCAL_PATH)/recovery/root/vendor/bin/hw/android.hardware.gatekeeper-service.mitee:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/bin/hw/android.hardware.gatekeeper-service.mitee \
    $(LOCAL_PATH)/recovery/root/vendor/etc/init/android.hardware.security.keymint.mitee@3.0-service.rc:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/init/android.hardware.security.keymint.mitee@3.0-service.rc \
    $(LOCAL_PATH)/recovery/root/vendor/etc/init/android.hardware.gatekeeper-service.mitee.rc:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/init/android.hardware.gatekeeper-service.mitee.rc \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/android.hardware.gatekeeper-V1-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/android.hardware.gatekeeper-V1-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/android.hardware.security.keymint-V1-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/android.hardware.security.keymint-V1-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/android.hardware.security.keymint-V3-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/android.hardware.security.keymint-V3-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/android.hardware.security.rkp-V3-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/android.hardware.security.rkp-V3-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/android.hardware.security.secureclock-V1-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/android.hardware.security.secureclock-V1-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/android.hardware.security.sharedsecret-V1-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/android.hardware.security.sharedsecret-V1-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/lib_android_keymaster_keymint_utils.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/lib_android_keymaster_keymint_utils.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libcppbor_external.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libcppbor_external.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libcppcose_rkp.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libcppcose_rkp.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libgatekeeper.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libgatekeeper.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libkeymaster4support.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymaster4support.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libkeymaster_messages.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymaster_messages.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libkeymaster_portable.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymaster_portable.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libkeymint.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymint.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libkeymint_remote_prov_support.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymint_remote_prov_support.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libkeymint_support.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libkeymint_support.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libteecli.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libteecli.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libtrusty.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libtrusty.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libpuresoftkeymasterdevice.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libpuresoftkeymasterdevice.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libsoft_attestation_cert.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libsoft_attestation_cert.so \
    $(LOCAL_PATH)/recovery/root/vendor/etc/vintf/manifest/android.hardware.gatekeeper-service.mitee.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest/android.hardware.gatekeeper-service.mitee.xml \
    $(LOCAL_PATH)/recovery/root/system/etc/ld.config.recovery.txt:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/ld.config.recovery.txt \
    $(LOCAL_PATH)/recovery/root/vendor/bin/hw/android.hardware.boot-service.mtk:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/bin/hw/android.hardware.boot-service.mtk \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libmtk_bsg.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libmtk_bsg.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/android.hardware.boot@1.1.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/android.hardware.boot@1.1.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/android.hardware.boot-V1-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/android.hardware.boot-V1-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/etc/init/android.hardware.boot-service.mtk.rc:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/init/android.hardware.boot-service.mtk.rc \
    $(LOCAL_PATH)/recovery/root/vendor/bin/tee-supplicant:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/bin/tee-supplicant \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libvndksupport.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libvndksupport.so \
    $(LOCAL_PATH)/recovery/root/vendor/etc/vintf/manifest/android.hardware.boot-service.mtk.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest/android.hardware.boot-service.mtk.xml
   # $(LOCAL_PATH)/recovery/root/system/bin/load_spl.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/load_spl.sh
   # $(LOCAL_PATH)/recovery/root/vendor/lib64/libbinder_ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libbinder_ndk.so \

# Xiaomi keystore2 stack with keymaster1 compat
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/bin/keystore2:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/keystore2 \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/android.hardware.keymaster@3.0.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/android.hardware.keymaster@3.0.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/android.hardware.keymaster@4.0.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/android.hardware.keymaster@4.0.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/android.hardware.keymaster@4.1.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/android.hardware.keymaster@4.1.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/android.hardware.security.keymint-V4-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/android.hardware.security.keymint-V4-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/android.security.compat-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/android.security.compat-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/android.system.keystore2-V5-ndk.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/android.system.keystore2-V5-ndk.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libc++.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libc++.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libhidlbase.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libhidlbase.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libkeymaster4_1support.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libkeymaster4_1support.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libkeystore2_aaid.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libkeystore2_aaid.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libkeystore2_apc_compat.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libkeystore2_apc_compat.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libkeystore2_crypto.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libkeystore2_crypto.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libkm_compat.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libkm_compat.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libkm_compat_service.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libkm_compat_service.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libvndksupport.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libvndksupport.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/keystore2/libsqlite.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/keystore2/libsqlite.so \


# To fix bootloop due to missing files
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/prebuilt/lib/modules,$(TARGET_COPY_OUT_VENDOR_RAMDISK)/lib/modules) \
    $(LOCAL_PATH)/recovery/root/first_stage_ramdisk/fstab.mt6878:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.mt6878 \
    $(LOCAL_PATH)/recovery/root/first_stage_ramdisk/fstab.emmc:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.emmc