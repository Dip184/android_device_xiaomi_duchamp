# Duchamp Recovery Decryption — Full Research Log

> **Raw chronological documentation of every session, hypothesis, dead end, and fix.**
> Companion to the polished [decryptionguide.md](decryptionguide.md).
>
> **Device:** Xiaomi Poco X6 Pro (`duchamp`, MT6897 / Dimensity 8300)
> **Platform:** Android 14→16 / HyperOS 3, MediaTek MiTEE TEE
> **Recovery:** TWRP → OrangeFox (OFRP) 14.1

---

## Table of Contents

1. [Session 1 — Foundation & Blob Extraction](#session-1--foundation--blob-extraction)
2. [Session 2 — First Build, Linker Namespace Breakthrough](#session-2--first-build-linker-namespace-breakthrough)
3. [Session 3 — libhidlbase, ABI Conflict & twrp-14.1 Attempt](#session-3--libhidlbase-abi-conflict--twrp-141-attempt)
   - 3.1 [Post-Flash Discoveries & MTK Boot HAL](#31-post-flash-discoveries--mtk-boot-hal)
4. [Session 4 — TEE Error -33, tee-supplicant & Init Ordering](#session-4--tee-error--33-tee-supplicant--init-ordering)
   - 4.1 [Post-Session 4 — Keymint Startup Race Fix](#41-post-session-4--keymint-startup-race-fix)
5. [Session 5 — snapuserd Patch & Keymaster1 Compat Bridge](#session-5--snapuserd-patch--keymaster1-compat-bridge)
6. [Session 6 — Mitee KeyMint TA Reverse Engineering](#session-6--mitee-keymint-ta-reverse-engineering)

---

## Session 1 — Foundation & Blob Extraction

### Goal
Build a custom recovery with working decryption for HyperOS 3 / Android 16.

### Device Info

| Property | Value |
|---|---|
| Device | Poco X6 Pro (codename: duchamp) |
| Chipset | MediaTek Dimensity 8300 (mt6897) |
| GPU | Mali-G615 |
| HyperOS Version | OS3.0.3.0.WNLINXM |
| Android Version | 16 |
| Kernel | 6.1.138-android14-11-g44bda9e8f6e9-ab13792638 |
| Encryption | FBE (File Based Encryption) |
| fscrypt policy | v2 + inlinecrypt_optimized |
| Metadata encryption | aes-256-cts |
| userdata filesystem | f2fs |
| Bootloader | Unlocked |

### Why Recovery Can't Decrypt /data

Android /data is encrypted with fscrypt v2. To decrypt, recovery needs to:
1. Ask the TEE to unwrap the encryption key
2. Verify PIN/password via gatekeeper
3. Mount /data with the decrypted key

The TEE middlemen are two AIDL binderized HAL services:
- `android.hardware.security.keymint@3.0-service.mitee` — talks to TEE for keys
- `android.hardware.gatekeeper-service.mitee` — verifies PIN

The existing PBRP build (TheFormidable, HyperOS 1 era) had:
- Wrong fscrypt policy (v1 instead of v2)
- Wrong/missing vendor blobs
- Services marked `disabled`

### Key Findings

**Real fstab userdata entry:**
```
/dev/block/by-name/userdata /data f2fs ... fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized,keydirectory=/metadata/vold/metadata_encryption ...
```

**Both keymint and gatekeeper rc files had `disabled`** — they would never auto-start in recovery.

### Blobs Extracted

**Service binaries** from `/vendor/bin/hw/`:
- `android.hardware.security.keymint@3.0-service.mitee`
- `android.hardware.gatekeeper-service.mitee`

**19 libraries** from `/vendor/lib64/` including:
- `libteecli.so` (critical MTK TEE client)
- `libkeymint.so`, `libkeymaster_messages.so`, `libkeymaster_portable.so`
- `libkeymint_support.so`, `libkeymint_remote_prov_support.so`
- `libgatekeeper.so`, `libtrusty.so`

**Init RC files fixed:**
- `class early_hal` → `class hal`
- Removed `disabled`
- Added `seclabel u:r:recovery:s0`

### Reference Repos

| Repo | URL |
|---|---|
| PBRP Releases | https://github.com/TheFormidable/Pbrp-Releases |
| Device Tree (base) | https://github.com/perilouspike/android_device_xiaomi_duchamp |
| Kernel Source | https://github.com/MiCode/Xiaomi_Kernel_OpenSource (branch: bsp-duchamp-u-oss) |
| Our Fork | https://github.com/Dip184/android_device_xiaomi_duchamp |
| TWRP Manifest | https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp (branch: twrp-12.1) |

### Build Environment (Arch Linux)

| Property | Value |
|---|---|
| Build dir | /build/twrp-duchamp/ |
| RAM | 14GB + 18GB swap |
| Python | 3.14.3 (may need downgrade) |
| Java | OpenJDK 26 (may need downgrade) |

### End State
- `repo init` completed
- `repo sync` ~80% complete (4 repos dropped due to connection)

### Session 2 Starting Steps
1. Resume sync (remove 4 broken repo dirs, `repo sync -j4`)
2. Fork device tree
3. Clone fork
4. Transfer blobs from phone
5. Copy blobs into device tree
6. Write fixed `recovery.fstab`
7. Fix `BoardConfig.mk` (fscrypt v2, PLATFORM_VERSION)
8. Fix `device.mk` (PRODUCT_COPY_FILES)
9. Build, flash, test

---

## Session 2 — First Build, Linker Namespace Breakthrough

### Wins
- Built TWRP successfully (37 min, clean build)
- Fixed gatekeeper VINTF manifest — gatekeeper now starts and connects to TEE
- Fixed keymint linker symbol issue — keymint starts, connects to TEE, registers all services
- TWRP boots and reaches decryption stage

### Still Broken
- keystore2 crashes on startup (SIGABRT)
- boot-hal crashes on startup
- Metadata key SELinux denials
- `libhidlbase.so` version mismatch

### Fix 1: fscrypt Policy
Uncommented `TW_USE_FSCRYPT_POLICY := 2` in BoardConfig.mk.

### Fix 2: Gatekeeper VINTF Manifest
Gatekeeper was rejected by servicemanager:
```
Could not find android.hardware.gatekeeper.IGatekeeper/default in the VINTF manifest
```
Created `/vendor/etc/vintf/manifest/android.hardware.gatekeeper-service.mitee.xml`.

### Fix 3: Missing Libraries
keymint crashed immediately:
```
CANNOT LINK EXECUTABLE: cannot locate symbol "_ZTVN9keymaster20GenerateCsrV2RequestE"
```
Pulled `libpuresoftkeymasterdevice.so` and `libsoft_attestation_cert.so` from running device.

### Fix 4: Linker Namespace Problem (The Big One)
Even with the right libs, keymint still crashed. The recovery linker config only searched `/system/lib64`:
```
namespace.default.search.paths = /system/${LIB}
```
The build system was also compiling its own older versions of `libkeymaster_messages.so` and `libkeymaster_portable.so` and placing them at `/system/lib64/` — these old versions were missing newer symbols Xiaomi's binaries need.

**Fix:** Added `copy` commands to init rc to overwrite AOSP libs with Xiaomi's versions at boot:
```
copy /vendor/lib64/libkeymaster_messages.so /system/lib64/libkeymaster_messages.so
copy /vendor/lib64/libkeymaster_portable.so /system/lib64/libkeymaster_portable.so
...
```

**Result:**
```
[MITEE]: connect to mitee keymaster success ✓
[MITEE]: build mitee keymint success ✓
[MITEE]: adding keymint service instance: IKeyMintDevice/default ✓
```

### Fix 5: VINTF Manifest for Keymint
Added keymint services to VINTF manifest.

### Fix 6: restorecon_recursive /metadata
SELinux blocking access to metadata encryption key directory. Added `restorecon_recursive /metadata` to `on fs` trigger.

### Remaining Problems at End of Session
```
keystore2: Check failed: serviceManager.get() Failed to get ServiceManager
boot-hal: cannot locate symbol referenced by "/vendor/lib64/libhidlbase.so"
```

### Files Modified

| File | Change |
|---|---|
| BoardConfig.mk | fscrypt v2, PLATFORM_VERSION := 16 |
| device.mk | PRODUCT_COPY_FILES for all blobs |
| recovery/root/vendor/bin/hw/ | keymint + gatekeeper binaries |
| recovery/root/vendor/lib64/ | 21 libraries |
| recovery/root/vendor/etc/init/ | Fixed rc files |
| recovery/root/vendor/etc/vintf/manifest/ | VINTF manifest |
| recovery/root/system/etc/recovery.fstab | Correct fscrypt v2 |
| init.recovery.mt6897.rc | lib copy commands, restorecon |

---

## Session 3 — libhidlbase, ABI Conflict & twrp-14.1 Attempt

### What Was Attempted
- Identified root cause of remaining crashes (libhidlbase ABI mismatch)
- Confirmed twrp-14.1 not viable for this device tree
- Returned twrp-12.1 tree to clean known-good state
- Successful build at end

### Dead Ends
- Copying Xiaomi's libhidlbase.so → bootloop
- Copying libc++.so alongside libhidlbase → worse bootloop
- Migrating to twrp-14.1 → multiple build system blockers

### Root Cause: libhidlbase ABI Mismatch

Both keystore2 and boot-hal crashed with:
```
cannot locate symbol "_ZNSt3__122__libcpp_verbose_abortEPKcz" referenced by "/system/lib64/libhidlbase.so"
```

Xiaomi's `libhidlbase.so` was compiled against Android 14/15 era libc++. twrp-12.1 ships an older libc++.so missing those symbols.

**Fix:** Removed Xiaomi's libhidlbase. Let AOSP recovery's own handle it. The crash was self-inflicted by including an incompatible vendor version.

### twrp-14.1 Migration Attempt — Why It Failed

Blockers in order:
1. `lunch` format changed (needs `twrp_duchamp-ap2a-eng`)
2. `BOARD_BUILD_SYSTEM_ROOT_IMAGE` obsolete
3. `TARGET_USES_64_BIT_BINDER` deprecated
4. CTS doesn't know Android 16
5. `android.security.apc-ndk_platform` ninja dep missing — **unfixable**

**Conclusion:** twrp-14.1 abandoned. Returned to twrp-12.1.

### Fixes Applied to twrp-12.1

1. **Removed Xiaomi's libhidlbase** from device tree
2. **Fixed keymint rc** — class hal, user system, removed disabled
3. **PLATFORM_VERSION back to 14** — version 16 breaks NDK stubs
4. **Confirmed BOARD_USES_METADATA_PARTITION** and TW_INCLUDE_FBE_METADATA_DECRYPT

### Init RC State at End

```ini
on init
    copy /vendor/lib64/libkeymaster_messages.so /system/lib64/libkeymaster_messages.so
    copy /vendor/lib64/libkeymaster_portable.so /system/lib64/libkeymaster_portable.so
    copy /vendor/lib64/libkeymint.so /system/lib64/libkeymint.so
    copy /vendor/lib64/libkeymint_support.so /system/lib64/libkeymint_support.so
    copy /vendor/lib64/libkeymaster4support.so /system/lib64/libkeymaster4support.so
    copy /vendor/lib64/lib_android_keymaster_keymint_utils.so /system/lib64/lib_android_keymaster_keymint_utils.so
    copy /vendor/lib64/libpuresoftkeymasterdevice.so /system/lib64/libpuresoftkeymasterdevice.so
    copy /vendor/lib64/libsoft_attestation_cert.so /system/lib64/libsoft_attestation_cert.so

on fs
    install_keyring
    restorecon_recursive /metadata
    start boot-hal-1-2
```

### Pending at End
- keystore2 VINTF fix (hidl manager declaration still needed)

### Key Insight
Never include Xiaomi's libhidlbase or libc++ in AOSP recovery. The ABI conflict cannot be resolved on twrp-12.1.

---

### 3.1 Post-Flash Discoveries & MTK Boot HAL

#### First Successful TWRP UI Boot
- TWRP UI rendering (`3.7.1_12-perilouspike/beta`)
- `/data` directory visible — decryption succeeded?
- Internal Storage showing **0MB** — boot-hal crash loop
- UI extremely laggy (CPU saturated by boot-hal respawn)

#### What Worked
- **keymint** — FULLY WORKING: `[MITEE]: connect to mitee keymaster success`
- **gatekeeper** — FULLY WORKING: `[MITEE]: Connected`
- **keystore2** — STARTED SUCCESSFULLY (no more SIGABRT)

#### What Was Still Broken
- **boot-hal** — crash loop every 5 seconds, causing UI lag and 0MB storage

#### The Big Discovery — MTK Proprietary Boot HAL

Standard TWRP uses `android.hardware.boot@1.2-service` (generic AOSP). MediaTek **abandoned the standard AOSP boot HAL naming entirely** — they ship a completely proprietary binary:
```
root     506     1     android.hardware.boot-service.mtk
```

**Dependencies pulled:**
- `android.hardware.boot-service.mtk` (binary)
- `libmtk_bsg.so` (MediaTek Block Storage Generation)
- `android.hardware.boot@1.1.so`
- `android.hardware.boot-V1-ndk.so`
- `libbinder_ndk.so`
- `android.hardware.boot-service.mtk.rc`

#### Plan
- Replace generic boot-hal with MTK proprietary version
- Remove `start boot-hal-1-2` from init rc
- Let MTK rc file handle startup

---

## Session 4 — TEE Error -33, tee-supplicant & Init Ordering

### Starting State

| Component | Status |
|---|---|
| mitee.ko | ✅ Loading |
| keymint HAL | ✅ Running, TEE connected |
| gatekeeper HAL | ✅ Running, TEE connected |
| keystore2 | ✅ Starting |
| boot-hal | ❌ Crash loop (MTK blob pending) |
| vold / decrypt | ❓ Unknown |

### Phase 1: First Real Logcat

Boot-hal was still crashing, but vold ran anyway. The critical error:
```
[MITEE]: mitee_keymaster_call 229 4
[MITEE]: Response of size 131072 contained error code -33
[MITEE]: Failed to send cmd 4 err: -33
keystore2: Error::Km(ErrorCode(-33))
```

TEE is receiving the key blob, attempting to use it, and returning -33. Everything upstream works.

Also found: `start vold` failed — `service vold not found`. TWRP handles vold internally. Removed it from rc.

### Phase 2: Understanding TEE Error -33

- **ErrorCode -33 = KEY_REQUIRES_UPGRADE** in KeyMint
- keystore2 is supposed to call `upgradeKey` first, then retry — but upgrade itself fails silently

**What was investigated and ruled out:**
1. **PLATFORM_VERSION mismatch** — Fixed 14→16. Still -33.
2. **Boot state mismatch** — Live OS shows `green/locked` via `getprop`, but Tricky Store spoofs this in userspace. TEE always sees real `orange/unlocked`. Boot state matched. Not the cause.
3. **Key blob date analysis** — `keymaster_key_blob` (219 bytes) was rewritten by March 2026 HyperOS 3 OTA. The new blob format is what the TEE rejects during upgrade.
4. **Vendor build version** — `ro.vendor.build.version.release = 14` (vendor is still Android 14 base). Normal — not a mismatch.
5. **SELinux** — Recovery domain is permissive. Denials logged but cannot block.
6. **Attestation certs** — No `/vendor/etc/attestation/`. Material factory-provisioned inside TEE.

**Conclusion on -33:** The blob was sealed by live OS. When recovery tries to use it, TEE says "upgrade required." The upgradeKey call fails because parameters recovery provides don't match what TEE expects.

### Phase 3: Key Regeneration Attempt

**Theory:** Delete metadata key, let recovery create a fresh one.

**Attempt 1 — Wrong:** Deleted via Termux on live OS, then let Xiaomi recovery reformat. New blob sealed under `green/locked` — same -33 in TWRP.

**Attempt 2 — Correct but blocked:**
- Deleted metadata key from TWRP via adb
- Tried Format Data from TWRP
- **Result:** "Unable to check merge status" — Virtual A/B snapshot merge check fails

**Root cause of merge check failure:** `ENABLE_VIRTUAL_AB` was not set in BoardConfig. Even though snapuserd was compiled in, it had no configuration → blocked Format Data.

### Phase 4: Boot-hal Analysis

**Crash:** `vendor.boot-default` exiting with status 1 every 5 seconds.

**Key finding:** `libbinder_ndk.so` — vendor version conflicted with AOSP's. Removed vendor version. AOSP's `libbinder_ndk.so` in `/system/lib64/` works fine.

**vibratorfeature crash loop:** Added `disabled` flag to service definition.

### Phase 5: tee-supplicant Discovery

`tee-supplicant` is the userspace daemon bridging TEE client library and kernel driver:
- Sets up `/dev/tee0`, `/dev/teepriv0`
- Handles RPMB access
- Must run BEFORE keymint connects to TEE

**Critical finding in `tee-supplicant.rc`:**
```ini
on fs
    ...device setup...
    enable vendor.keymint-mitee
    start tee-supplicant
```

tee-supplicant should start FIRST, then ENABLE keymint. Our init rc was starting keymint via `crypto.ready=1` which fires before `on fs`.

**Fixes:**
- Added tee-supplicant to device.mk PRODUCT_COPY_FILES
- Added `import /tee-supplicant.rc` back to init rc
- Removed keymint/gatekeeper start from `on property:crypto.ready=1`

### Phase 6: Init RC Cleanup

- Removed duplicate `vendor.gatekeeper_mitee` service definition
- Removed duplicate symlink line
- Started tee-supplicant on `on fs`, keymint on `on hwservicemanager.ready`

### Files Modified

| File | Change |
|---|---|
| BoardConfig.mk | PLATFORM_VERSION=16, ENABLE_VIRTUAL_AB=true, sepolicy uncommented |
| init.recovery.mt6897.rc | Removed start vold, removed duplicate definitions, added tee-supplicant import, disabled vibratorfeature |
| vendor/lib64/libbinder_ndk.so | DELETED |
| device.mk | Added tee-supplicant |
| sepolicy/recovery.te | Expanded SELinux rules |

---

### 4.1 Post-Session 4 — Keymint Startup Race Fix

#### What Broke
Applied the tee-supplicant startup order changes. Result: keymint never started at all.
```
keystore2::watchdog: Watchdog thread idle -> terminating. Have a great day.
```

#### Root Cause — Three-Way Conflict

Three things were fighting over keymint startup:

1. **`keymint.service.mitee.rc`** — NO `disabled` flag. keymint auto-started at boot via `class hal` before TEE devices were ready.
2. **`tee-supplicant.rc` `on fs` block** — contains `enable vendor.keymint-mitee`, but keymint already auto-started (too early).
3. **`init.recovery.mt6897.rc` `on hwservicemanager.ready`** — tried to start keymint again.

**Result:** keymint connected to TEE before `/dev/tee0` was ready → silent failure → keystore2 timeout → gave up.

#### Fix

Added `disabled` to `keymint.service.mitee.rc`:
```
service vendor.keymint-mitee /vendor/bin/hw/android.hardware.security.keymint@3.0-service.mitee
    class hal
    user system
    group system drmrpc
    disabled          ← ADDED
    seclabel u:r:recovery:s0
```

**Correct startup sequence:**
```
Boot
 └─ on fs (tee-supplicant.rc)
     ├─ chmod /dev/tee0, /dev/teepriv0
     ├─ enable vendor.keymint-mitee
     └─ start tee-supplicant

 └─ on hwservicemanager.ready (init.recovery.mt6897.rc)
     ├─ start vendor.keymint-mitee
     └─ start vendor.gatekeeper_mitee

 └─ keystore2
     └─ finds IKeyMintDevice/default ✓
```

#### Key Lesson
`class hal` means auto-start at boot. Any HAL service with hardware dependencies (like `/dev/tee0`) must have `disabled` and be explicitly enabled after hardware setup.

---

## Session 5 — snapuserd Patch & Keymaster1 Compat Bridge

### Starting State

| Component | Status |
|---|---|
| keymint | ✅ Running |
| gatekeeper | ✅ Running |
| keystore2 (AOSP) | ✅ Starting |
| boot-hal | ✅ Fixed |
| tee-supplicant order | ✅ Fixed |
| TEE Error -33 | ❌ Persistent |
| Format Data | ❌ Blocked by merge check |

### Wins
- Fixed "Unable to check merge status" — surgical patch to `partitionmanager.cpp`
- Successfully ran Format Data from TWRP for first time
- Identified root cause of -33: AOSP keystore2 lacks `libkm_compat_service.so`
- Identified Xiaomi's proprietary keystore2 dep tree

### Dead Ends
- Security patch level mismatch — red herring (all match)
- Tricky Store spoofing — red herring (can't reach TEE)
- Xiaomi libhidlbase — bootloop (libc++ ABI conflict)
- Xiaomi keystore2 blob injection — bootloop (libsqlite→libandroidicu dep chain)

### Fix 1: snapuserd Merge Check Patch

**Problem:** Format Data blocked by `Check_Pending_Merges()` calling `HandleImminentDataWipe()` which tried to remap already-mounted logical partitions → `DM_DEV_CREATE failed: Device or resource busy`.

**Fix:** Patched `partitionmanager.cpp` to early-exit when `/metadata/ota/snapshot-boot` doesn't exist:
```cpp
bool TWPartitionManager::Check_Pending_Merges() {
    int rc = access("/metadata/ota/snapshot-boot", F_OK);
    if (rc != 0) {
        LOGINFO("No OTA snapshots found, skipping merge check\n");
        return true;
    }
    // ...
}
```

**Result:** Format Data worked. `/data` mounted with inlinecrypt. 488GB internal storage visible.

### Fix 2: BOOT_SECURITY_PATCH
Uncommented in BoardConfig — was empty in recovery. Did NOT fix -33 (all values already matched).

### The -33 Root Cause

**What -33 actually is:** `KEY_REQUIRES_UPGRADE`. TEE flags the blob for upgrade. keystore2's upgrade closure fails immediately — no upgrade attempt reaches TEE.

**Why upgrade fails:** The Dimensity 8300 TEE uses **keymaster1** internally. Xiaomi's live OS keystore2 uses a compatibility bridge (`libkm_compat_service.so` + `libkm_compat.so`) to translate keymint calls down to keymaster1.

TWRP's AOSP keystore2 does NOT have this bridge — it sends keymint-native calls directly. TEE receives malformed requests → returns -33.

**Proof:** Xiaomi's `/system/bin/keystore2` links against `libkm_compat_service.so`. TWRP's compiled version does not.

### Xiaomi keystore2 Blob Injection Attempt

**Plan:** Replace AOSP keystore2 with Xiaomi's proprietary version in isolated `/vendor/lib64/keystore2/`.

**Dep tree pulled (16 files):**
```
keystore2 (binary), libkm_compat_service.so, libkm_compat.so,
libkeymaster4_1support.so, android.security.compat-ndk.so,
android.system.keystore2-V5-ndk.so, android.hardware.security.keymint-V4-ndk.so,
android.hardware.keymaster@3.0.so, android.hardware.keymaster@4.0.so,
android.hardware.keymaster@4.1.so, libkeystore2_aaid.so,
libkeystore2_apc_compat.so, libkeystore2_crypto.so, libhidlbase.so,
libvndksupport.so, libc++.so
```

**What failed:**
1. `sqlite3_changes64` symbol missing — Xiaomi's keystore2 needs newer libsqlite
2. After adding libsqlite → `libandroidicu.so` dep chain → bootloop
3. Root conflict: twrp-12.1 libc++ is too old for Xiaomi's Android 16 stack

**Conclusion:** twrp-12.1 base cannot run Xiaomi's Android 16 keystore2. libc++ ABI mismatch is insurmountable.

### The Core Problem Going Forward

twrp-12.1 (Android 12) ships libc++ incompatible with Xiaomi's Android 16 HyperOS binaries.

**Options:**
- **A:** Migrate to twrp-14.1 (newer libc++, but tree has build blockers)
- **B:** Patch AOSP keystore2 source to include keymaster1 compat (complex)
- **C:** Use a wrapper binary with dlopen (extremely complex)

**Recommended:** Try Option A — remove `android.security.apc-ndk_platform` dep from libtar and prebuilt.

### Key Facts Established
- All version strings match between live OS and recovery
- Tricky Store does NOT affect TEE
- Dimensity 8300 TEE uses keymaster1 internally — keymint is a shim
- Format Data from TWRP works, but live OS overwrites the key
- Permanent fix: TWRP keystore2 needs keymaster1 compat bridge

### Files Modified

| File | Change |
|---|---|
| bootable/recovery/partitionmanager.cpp | Early-exit in Check_Pending_Merges |
| BoardConfig.mk | Uncommented BOOT_SECURITY_PATCH |
| keystore2 + libs | Xiaomi blob injection (REVERTED — bootloop) |

---

## Session 6 — Mitee KeyMint TA Reverse Engineering

> **⚠️ Superseded finding:** The Root-of-Trust conclusion below was the working
> hypothesis at this point in the investigation (TWRP-era, dual-boot TWRP/HyperOS
> key blob conflict). It was later investigated further and found to be
> unconfirmed — see [decryptionguide.md §2.3](decryptionguide.md#23-the-root-of-trust-mismatch-red-herring).
> The actual confirmed root cause of -33 (OFRP-era) was secure-storage partitions
> (`protect_f`/`protect_s`/`nvdata`/`nvcfg`) not being mounted before KeyMint
> starts — see [decryptionguide.md §2.4](decryptionguide.md#24-fix-mount-secure-storage-partitions-early).
> Kept here unedited for historical accuracy of the raw investigation.



### Starting Point
`TEEC_InvokeCommand(cmd=4)` failing with -33 during `BeginOperation`.

### False Trail
Found `fcn.0000a2a0` — the shared TEEC dispatch wrapper used by EVERY command — contains explicit handling for `TEEC_ERROR_TARGET_DEAD`. This is real, correctly-reversed behavior, but **unrelated to this specific -33**. The TARGET_DEAD recovery is command-agnostic, not a BeginOperation-specific bug.

### Actual Root Cause (Confirmed via Device Log)

```
[MITEE]Request: 375 Max size: 131072
[MITEE]Response of size 131072 contained error code -33
```

`TEEC_InvokeCommand` **succeeded** (returned 0). The -33 is an error code embedded *inside* a valid, fully-returned response — not a transport failure.

**-33 = KeyMint `ErrorCode::INVALID_KEY_BLOB`**

### Why It Happens

KeyMint key blobs are cryptographically bound to `Tag::ROOT_OF_TRUST` (verified boot state, boot key hash, lock state). TWRP and HyperOS present **different root-of-trust context** to the Mitee TA.

Cycle:
- TWRP boots → decrypts `/metadata` → mints key blob bound to TWRP's root-of-trust
- HyperOS boots → validates blob against its own root-of-trust → mismatch → -33 → regenerates key
- Reboot to TWRP → same conflict in reverse

This is an inherent architectural conflict between two different verified-boot contexts sharing one metadata key slot.

### Full Mitee TA Command Table

Mapped every TEEC command ID the TA exposes. One TA backs **five separate HAL services**:

| Cmd | Method | Interface |
|---|---|---|
| 0x00 | `generateKey` | KeyMintDevice |
| 0x04 | `begin` | KeyMintOperation |
| 0x08 | `update` | KeyMintOperation |
| 0x0c | `finish` | KeyMintOperation |
| 0x10 | `abort` | KeyMintOperation |
| 0x14 | `importKey` | KeyMintDevice |
| 0x3c | `getKeyCharacteristics` | KeyMintDevice |
| 0x44 | `upgradeKey` | KeyMintDevice |
| 0x50 | `computeSharedSecret` | SharedSecret |
| 0x58 | `deleteKey` | KeyMintDevice |
| 0x5c | `deleteAllKeys` | KeyMintDevice |
| 0x64 | `importWrappedKey` | KeyMintDevice |
| 0x68 | `deviceLocked` | KeyMintDevice |
| 0x74 | `generateEcdsaP256KeyPair` | RemotelyProvisionedComponent |
| 0x7c | `generateTimeStamp` | SecureClock |
| 0x88 | `getRootOfTrust` | KeyMintDevice |
| 0x8c | `getHardwareInfo` | KeyMintDevice |
| 0x90 | `generateCsrV2` | RemotelyProvisionedComponent |

All multiplexed through a single TEEC dispatcher.

### Open Items
- [ ] Confirm `update` (0x08) and `abort` (0x10) via Ghidra signature comments
- [ ] RE `getRootOfTrust` (cmd 0x88) in detail — determine exactly what fields feed the TA's root-of-trust check
- [ ] **New direction:** Flash vbmeta with `--disable-verification --disable-verity` on stock HyperOS and check if -33 disappears when booting TWRP

---

*End of research log. Build count: ~15. Flash cycles: ~20+. Bootloops: 3.*
