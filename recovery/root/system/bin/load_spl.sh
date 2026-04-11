#!/sbin/sh

# 1. Create a temporary mount point
mkdir -p /mnt/vendor

# 2. Mount the unencrypted vendor partition
# duchamp uses erofs/f2fs. We use the block path directly.
mount -t erofs -o ro /dev/block/by-name/vendor /mnt/vendor

# 3. Extract the real patch date
REAL_PATCH=$(grep "ro.vendor.build.security_patch=" /mnt/vendor/build.prop | cut -d'=' -f2)
REAL_VERSION=$(grep "ro.build.version.release=" /mnt/vendor/build.prop | cut -d'=' -f2)

# 4. Inject it into the live environment
if [ -n "$REAL_PATCH" ]; then
    resetprop ro.build.version.security_patch "$REAL_PATCH"
    resetprop ro.vendor.build.security_patch "$REAL_PATCH"
    resetprop ro.build.version.release "$REAL_VERSION"
    # Also spoof the fingerprint to be safe
    FP=$(grep "ro.vendor.build.fingerprint=" /mnt/vendor/build.prop | cut -d'=' -f2)
    resetprop ro.vendor.build.fingerprint "$FP"
fi

# 5. Cleanup
umount /mnt/vendor
rmdir /mnt/vendor
