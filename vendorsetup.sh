# A/B Partition
	export FOX_VIRTUAL_AB_DEVICE=1
	export FOX_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
	export FOX_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"
    cp device/xiaomi/duchamp/recovery/root/system/bin/prepdecrypt.sh "$RAMDISK_STAGING/system/bin/prepdecrypt.sh"
	chmod 755 "$RAMDISK_STAGING/system/bin/prepdecrypt.sh"
