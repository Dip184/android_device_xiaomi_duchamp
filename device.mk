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
PRODUCT_PACKAGES += \
    android.hardware.boot@1.2-mtkimpl \
    android.hardware.boot@1.2-mtkimpl.recovery \
    bootctrl.mt6897.recovery

PRODUCT_PACKAGES += \
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
PRODUCT_PACKAGES += \
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

PRODUCT_PACKAGES += \
    e2fsck.vendor_ramdisk \
    fsck.f2fs.vendor_ramdisk \
    resize2fs.vendor_ramdisk \
    tune2fs.vendor_ramdisk

PRODUCT_PACKAGES += \
    fstab.mt6897.vendor_ramdisk

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

# To fix bootloop due to missing files
# Copy kernel modules to vendor_ramdisk (ramdisk00) — loaded during normal + recovery boot
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/kernel/modules,$(TARGET_COPY_OUT_VENDOR_RAMDISK)/lib/modules)

# Copy first-stage fstabs to vendor_ramdisk — required by first-stage init
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/first_stage_ramdisk/fstab.mt6897:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.mt6897 \
    $(LOCAL_PATH)/recovery/root/first_stage_ramdisk/fstab.emmc:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.emmc

# Copy stock vendor_ramdisk essentials to ramdisk00 — sepolicy, context files, snapuserd, init
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/vendor_ramdisk/first_stage_ramdisk/system/bin/snapuserd:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/system/bin/snapuserd \
    $(LOCAL_PATH)/vendor_ramdisk/system/bin/init:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/system/bin/init \
    $(LOCAL_PATH)/vendor_ramdisk/init:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/init \
    $(LOCAL_PATH)/vendor_ramdisk/init.recovery.hardware.rc:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/init.recovery.hardware.rc \
    $(LOCAL_PATH)/vendor_ramdisk/sepolicy:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/sepolicy \
    $(LOCAL_PATH)/vendor_ramdisk/prop.default:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/prop.default \
    $(LOCAL_PATH)/vendor_ramdisk/plat_file_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/plat_file_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/plat_property_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/plat_property_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/plat_service_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/plat_service_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/vendor_file_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/vendor_file_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/vendor_property_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/vendor_property_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/vendor_service_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/vendor_service_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/system_ext_file_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/system_ext_file_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/system_ext_property_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/system_ext_property_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/system_ext_service_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/system_ext_service_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/odm_file_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/odm_file_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/odm_property_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/odm_property_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/product_file_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/product_file_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/product_property_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/product_property_contexts \
    $(LOCAL_PATH)/vendor_ramdisk/product_service_contexts:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/product_service_contexts

# Copy all system/ to vendor_ramdisk — boot service, health HAL, config
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/recovery/root/system,$(TARGET_COPY_OUT_VENDOR_RAMDISK)/system)

# Copy root-level RC files to vendor_ramdisk — imported by init during normal + recovery boot
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.mt6897.rc:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/init.recovery.mt6897.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.usb.rc:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/init.recovery.usb.rc \
    $(LOCAL_PATH)/recovery/root/tee-supplicant.rc:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/tee-supplicant.rc \
    $(LOCAL_PATH)/recovery/root/miteelog.rc:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/miteelog.rc

#fix arb
PRODUCT_COPY_FILES += \
    device/xiaomi/duchamp/recovery/root/system/bin/prepdecrypt.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/prepdecrypt.sh
