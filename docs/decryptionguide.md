# The Complete Duchamp FBE Decryption Investigation Guide

> **Device:** Xiaomi Poco X6 Pro (`duchamp`, MT6897 / Dimensity 8300/9200)
> **Platform:** Android 14 / HyperOS, MediaTek MiTEE TEE
> **Recovery:** OrangeFox (OFRP) 14.1
> **Scope:** Full arc of FBE decryption investigation — every hypothesis, dead end, breakthrough, and pivot

---

## Table of Contents

1. [The Problem](#1-the-problem)
2. [Error -33 (`INVALID_KEY_BLOB`)](#2-error--33-invalid_key_blob)
   - 2.1 [What -33 Actually Means](#21-what--33-actually-means)
   - 2.2 [Reverse-Engineering the TA](#22-reverse-engineering-the-ta)
   - 2.3 [The "Root of Trust Mismatch" Red Herring](#23-the-root-of-trust-mismatch-red-herring)
   - 2.4 [Fix: Mount Secure-Storage Partitions Early](#24-fix-mount-secure-storage-partitions-early)
3. [From -33 to -26: The Gatekeeper Race](#3-from--33-to--26-the-gatekeeper-race)
   - 3.1 [Why Synchronization Matters](#31-why-synchronization-matters)
   - 3.2 [Fix: Delayed Gatekeeper Startup](#32-fix-delayed-gatekeeper-startup)
4. [Normal Boot: vendor_boot Dependency Cherry-Picking](#4-normal-boot-vendor_boot-dependency-cherry-picking)
   - 4.1 [Stock init Binary (NOT OFRP's)](#41-stock-init-binary-not-ofrps)
   - 4.2 [Library Dependency Tree](#42-library-dependency-tree)
   - 4.3 [Kernel Modules](#43-kernel-modules)
   - 4.4 [SELinux & Context Files](#44-selinux--context-files)
   - 4.5 [snapuserd — Virtual A/B Requirement](#45-snapuserd--virtual-ab-requirement)
   - 4.6 [prop.default — GPU Service Fix](#46-propdefault--gpu-service-fix)
   - 4.7 [What Was Removed](#47-what-was-removed)
5. [GPU Crash: Old DTB](#5-gpu-crash-old-dtb)
   - 5.1 [Symptoms](#51-symptoms)
   - 5.2 [Root Cause](#52-root-cause)
6. [Diagnostic Reference](#6-diagnostic-reference)

---

## 1. The Problem

OrangeFox recovery on the Poco X6 Pro failed to decrypt `/data`. The device uses:

- **FBE** (File-Based Encryption) with hardware-backed keys via KeyMint 3.0
- **MediaTek MiTEE** as the TEE (Trusted Execution Environment)
- **Metadata encryption** layered underneath FBE (`dm-default-key`)
- A `vendor_boot`-based recovery architecture (no separate recovery partition)

The initial symptom was: `Failed to send cmd 4 err: -33`.

This kicked off a full reverse-engineering investigation spanning the KeyMint TA, TEE storage mechanics, Gatekeeper/KeyMint synchronization, vendor_boot composition, and DTB mismatches. Each layer revealed a distinct fix.

---

## 2. Error -33 (`INVALID_KEY_BLOB`)

### 2.1 What -33 Actually Means

```
[MITEE] Failed to send cmd 4 err: -33
→ Android-side mapping: Km(INVALID_KEY_BLOB)
```

Metadata encryption requires vold to call into KeyMint to unwrap the metadata partition's protecting key before `/data` can be mounted. On this device, that key blob is stored in format 2 — Android's secure-deletion-secret-bound format. Unwrapping requires reading a specific slot out of a TEE persistent object backed by `tee-supplicant`'s REE-FS mechanism.

That backing storage lives on these partitions:

`protect_f`, `protect_s`, `nvdata`, `nvcfg`

If these aren't mounted when `vendor.keymint-mitee` starts and `Decrypt_Data()` runs, the TEE-side lookup for the secure-deletion secret slot fails. A truncated fallback object gets created, `EVP_DecryptFinal_ex` fails on the wrong derived key, and KeyMint returns `-33` — which looks like a corrupted or RoT-mismatched key blob, even though the blob is completely valid.

**This is a boot-ordering problem, not a crypto/patchlevel problem.** Stock ROM avoids it because these partitions are mounted earlier in Android's full init sequence than recovery's minimal init replicates.

**Critical early mistake:** Assuming this was a TEE transport failure. It wasn't. The full proven communication chain:

```
recovery / keystore2
    → KeyMint HAL (android.hardware.security.keymint@3.0-service.mitee)
    → MiTEE client library
    → TEEC_InvokeCommand(cmd=4)
    → KeyMint TA executes BeginOperation
    → TA returns -33 inside the response payload
```

The transport worked perfectly. The KeyMint TA itself rejected the key blob.

### 2.2 Reverse-Engineering the TA

Ghidra analysis of the KeyMint TA mapped:
- **Command 4** → `BeginOperation`
- **Command 0x88** → `getRootOfTrust` (separate, not involved here)

Static analysis found a patchlevel anti-rollback check that could emit `-33`:

```
"Key blob invalid! key patchlevel %lu is > current patchlevel %lu"
```

**Tested and disproven:** Recovery's `boot.img` AVB `security_patch` (`2026-02-01`) matched stock exactly. Rebuilding with matching patchlevel did not change the error.

### 2.3 The "Root of Trust Mismatch" Red Herring

This became a popular hypothesis because KeyMint blobs *can* be bound to:
- Verified Boot state
- AVB/vbmeta state
- Rollback indices
- RPMB-backed device state

**Verdict:** Investigated extensively, **never confirmed**. The eventual working fix had nothing to do with Root of Trust. The `-33` was a **symptom** of deeper storage unavailability, not a cryptographic mismatch.

> **Key lesson:** Do not summarize this as "-33 was caused by Root of Trust mismatch." That was never proven. The accurate summary is: "-33 was returned by the KeyMint TA after successful transport, during blob decryption, because a required secure-storage object (`SecureDeletionSecrets_1`) was inaccessible in recovery."

### 2.4 Fix: Mount Secure-Storage Partitions Early

Add explicit mounts early in recovery's init, before KeyMint/Gatekeeper service start:

```ini
# init.recovery.<device>.rc — add before `start vendor.keymint-mitee` / `start vendor.gatekeeper_mitee`

on fs
    mount ext4 /dev/block/by-name/protect1 /mnt/vendor/protect_f noatime,nosuid,nodev
    mount ext4 /dev/block/by-name/protect2 /mnt/vendor/protect_s noatime,nosuid,nodev
    mkdir /mnt/vendor/nvdata 0755 root root
    mkdir /mnt/vendor/nvcfg 0755 root root
    mount ext4 /dev/block/by-name/nvdata /mnt/vendor/nvdata noatime,nosuid,nodev
    mount ext4 /dev/block/by-name/nvcfg /mnt/vendor/nvcfg noatime,nosuid,nodev
```

(Adjust block device names / mount points to match the target device's actual fstab — `protect1`/`protect2`/`nvdata`/`nvcfg` by-name symlinks are common on MTK devices but naming can vary.)

#### Why This Matters Beyond One Device

Any MTK MiTEE device shipping with metadata encryption enabled will hit this identical deadlock in recovery: KeyMint needs a secure-deletion secret to unwrap the metadata key, that secret's backing storage isn't mounted yet, `-33` results, `/data` never decrypts. This isn't device-specific beyond the exact partition names.

**Suggested general fix for OFRP:** Consider having OFRP's core init sequence automatically mount fstab entries missing `first_stage_mount` that are tagged as MTK secure-storage partitions, or at minimum document this requirement clearly in the MTK device-tree porting guide. This took a full RE investigation — from Ghidra call-chain tracing through live TEE log capture — to identify.

---

## 3. From -33 to -26: The Gatekeeper Race

After the secure-storage partitions were mounted, KeyMint progressed deeper and produced:

```
Auth token signature invalid
Auth required but no matching auth token found
-26
```

The key blob was now reaching authentication enforcement, moving the investigation toward Gatekeeper/KeyMint synchronization.

### 3.1 Why Synchronization Matters

Credential-protected FBE relies on Gatekeeper producing authentication information that KeyMint accepts:

```
User PIN → Gatekeeper → HAT → KeyMint → auth-gated key operation → FBE decryption
```

Decryption was **intermittent** — the same recovery image, PIN, and encrypted data could occasionally succeed. Good and bad boots were captured and service initialization compared. The evidence pointed toward a KeyMint/Gatekeeper ordering difference.

The conclusion: an **initialization/synchronization race**. Stock Android naturally separates these services through init classes (`KeyMint → early_hal`, `Gatekeeper → hal`), but recovery was starting the security stack too aggressively.

### 3.2 Fix: Delayed Gatekeeper Startup

A dedicated recovery-domain service delays Gatekeeper:

```ini
service delayed_gatekeeper /system/bin/sh -c "sleep 1; start vendor.gatekeeper_mitee"
    class core
    user root
    group root
    disabled
    oneshot
    seclabel u:r:recovery:s0
```

Startup sequence:

```ini
enable vendor.keymint-mitee
start tee-supplicant
start vendor.keymint-mitee
start delayed_gatekeeper
```

Resulting sequence:

```
tee-supplicant → KeyMint → ~1s delay → Gatekeeper → HAT accepted → FBE decrypt
```

After this change: **5 / 5 successful recovery decryptions**.

The one-second delay is a proven working workaround, not necessarily the minimum. A readiness-based dependency would be cleaner if a reliable KeyMint-ready signal can be identified.

---

## 4. Normal Boot: vendor_boot Dependency Cherry-Picking

Once recovery decryption worked, a new problem emerged: **OrangeFox boots and decrypts, but normal Android does not boot** — typically stopping at the POCO logo (one step better than the previous bootloop).

The root cause: the stock `vendor_boot` v4 contains two ramdisk fragments — `ramdisk00` (platform) and `ramdisk01` (recovery). Packing the complete stock `ramdisk00` together with a full OrangeFox `ramdisk01` exceeded the vendor_boot size limit. A cherry-picked minimal `ramdisk00` was needed.

**Principle:** A vendor_boot ramdisk must contain only what the kernel + init need to reach the point where `/vendor` and `/system` partitions are mounted. Every extra byte pushes toward the 64MB partition limit.

### 4.1 Stock init Binary (NOT OFRP's)

MediaTek SoCs have proprietary init modifications in the stock binary. Using OFRP's generic init breaks MediaTek-specific first-stage init logic.

- Extract `init` from stock `vendor_boot` ramdisk00 at `system/bin/init`
- Place at two locations:
  - `vendor_ramdisk/init` — kernel entry point
  - `vendor_ramdisk/system/bin/init` — second-stage `execv()` target
- Verify: `readelf -l vendor_ramdisk/init | grep INTERP` → `/system/bin/linker64`

### 4.2 Library Dependency Tree

Run `readelf -d stock_init_binary | grep NEEDED`, then recursively on each NEEDED library until closure.

**22 libraries** in `system/lib64/`:

```
libc.so       libc++.so     libm.so       libdl.so
ld-android.so libbase.so    libcrypto.so  libcutils.so
libext4_utils.so libfs_mgr.so  libgsi.so  libhidl-gen-utils.so
libkeyutils.so  liblog.so   liblogwrap.so liblp.so
libprocessgroup.so libprocessgroup_setup.so
libselinux.so libunwindstack.so libziparchive.so
```

**What was excluded** (46 libs present in stock vendor_boot but not in init's dep tree):

```
libbinder.so (0.9MB), libvintf.so (0.7MB), libhidlbase.so (0.7MB),
libprotobuf-cpp-lite.so (0.6MB), libssl.so (0.4MB), libsqlite.so,
libexpat.so, libpcre2.so, libnetd_client.so, libgui.so, libui.so, ...
```

**7 binaries** in `system/bin/`:

```
init (stock), linker64, sh, toybox, toolbox (→ toybox symlink),
ueventd (→ init symlink), watchdogd
```

**170+ toybox tool symlinks** (`cat`, `ls`, `mount`, `mkdir`, `chmod`, etc.) — all point to `toybox`. These cost ~0 bytes beyond the 528KB toybox binary.

### 4.3 Kernel Modules

| Subset | Count | Use case |
|---|---|---|
| All `.ko` files | 219 | Included in ramdisk00 |
| Normal boot load list (`modules.load`) | 198 | Loaded by init in NORMAL_MODE |
| Recovery boot load list (`modules.load.recovery`) | 209 | Loaded by init in RECOVERY_MODE |

**11 extra modules in recovery** (touch, battery, mcupm, sec, slbc):

```
adsp.ko, mediatek-cpufreq-hw.ko, mtk-dvfsrc-devfreq.ko,
mtk-dvfsrc-helper.ko, mtk_slbc.ko, slbc_mt6897.ko,
slbc_ipi.ko, slbc_trace.ko, vcp_status.ko,
arm_dsu_pmu.ko, mtk-swpm-perf-arm-pmu.ko
```

**Verification:** After build, `wc -l ramdisk00/lib/modules/modules.load` must output exactly `198`.

### 4.4 SELinux & Context Files

All files verified identical across three sources (device tree, live-pulled `vendor_boot_a`, stock `vendor_boot_stock.img`):

| File | Purpose | Size |
|---|---|---|
| `sepolicy` | SELinux policy | 1.3MB |
| `plat_service_contexts` | Platform service contexts | 37KB |
| `vendor_service_contexts` | Vendor service contexts | 16KB |
| `plat_file_contexts` | File contexts | 44KB |
| `vendor_file_contexts` | Vendor file contexts | 131KB |
| `prop.default` | Default properties | 14KB |
| `plat_property_contexts` / `vendor_property_contexts` | Property contexts | 103KB / 66KB |
| `system_ext_*`, `product_*`, `odm_*` | Additional contexts | ~28KB total |

**Key insight:** Do NOT regenerate sepolicy or context files from source. Use the stock binary blobs verbatim — the AOSP build system may produce different policies for the same source.

### 4.5 snapuserd — Virtual A/B Requirement

Virtual A/B requires `snapuserd` in the first-stage ramdisk. This was missing from the initial OFRP build, causing boot failure.

- **Source:** Stock `vendor_boot` → `ramdisk00/first_stage_ramdisk/system/bin/snapuserd` (1.1MB)
- **Placement:** `vendor_ramdisk/first_stage_ramdisk/system/bin/snapuserd`

### 4.6 prop.default — GPU Service Fix

Stock `prop.default` is used verbatim with **one addition**:

```
ro.vendor.mtk.gpu.service=1
```

This enables `vendor.gpuserv-default` HAL service which registers `vendor.mediatek.hardware.gpuserv.IGpuService/default`. Without this, the Mali GPU power domain never turns on and SurfaceFlinger crashes with `"no suitable EGLConfig found, giving up (META-EGL)"`.

### 4.7 What Was Removed

These were initially copied into ramdisk00 but belong only in ramdisk01 (recovery):

| Category | Examples | Size saved |
|---|---|---|
| `vendor/bin/*` | KeyMint, Gatekeeper, TEE daemons | ~3MB |
| `vendor/lib64/*` | 44 .so files (camera, TEE, firmware HALs) | ~4MB |
| `vendor/etc/init/*` | TEE, KeyMint, Gatekeeper init .rc files | ~50KB |
| `vendor/firmware/*` | Firmware blobs | ~500KB |

Removed by deleting the `recovery/root/vendor/*` PRODUCT_COPY_FILES entries from device.mk. These still land in ramdisk01 via OFRP's auto-include of `recovery/root/*`.

---

## 5. GPU Crash: Old DTB

After all cherry-picking fixes, the device reached userspace but **SurfaceFlinger crash-looped**.

### 5.1 Symptoms

```
libGLES_mali.so
mali: Failed creating base context during opening of kernel driver.
mali: Kernel module may not have been loaded
libEGL: eglInitialize(...) failed (EGL_NOT_INITIALIZED)
RenderEngine: no suitable EGLConfig found
SurfaceFlinger aborts
```

Also present but confirmed as **noise** (same messages appear on a working stock boot):

```
SELinux denied ... mapper/mediatek
Gralloc5: Failed to load mapper.mediatek.so
```

Kernel modules were identical between stock and OFRP (SHA256 verified). `modules.load`, `modules.dep`, `modules.alias`, `modules.softdep` were also identical.

The first meaningful dmesg divergence:

```
[GPU/FREQ][ERROR] fail to get resource GPUEB_MBOX
[GPU/FREQ][ERROR] fail to init platform info (-2)
gpufreq: probe of 13fbf000.gpufreq failed with error -2
```

### 5.2 Root Cause

DTBs in stock and OFRP `vendor_boot` had different hashes. Searching DTB strings exposed the exact difference:

| OFRP (old) | Stock (current) |
|---|---|
| `gpufreq@13fbf000` | `gpufreq@13fbf000` |
| `mediatek,gpufreq` | `mediatek,gpufreq` |
| *(missing)* | **`gpueb_mbox`** |

**Failure chain:**

```
Old DTB
  ↓ missing/outdated GPUEB_MBOX description
  ↓ gpufreq probe fails (-2)
  ↓ GPU/Mali kernel init incomplete
  ↓ libGLES_mali cannot create kernel base context
  ↓ eglInitialize → EGL_NOT_INITIALIZED
  ↓ RenderEngine cannot find EGLConfig
  ↓ SurfaceFlinger crash-loop
```

**Fix:** Updated the OFRP DTB to the current stock DTB. **Result: Android boot succeeded.**

---

## 6. Diagnostic Reference

### Recovery Log Symptoms

```
I:Unable to decrypt metadata encryption
I:FBE setup failed. Trying FDE...
```

### TEE Log Signature (Error -33)

Read `/proc/mitee_log` directly (no daemon needed) during the failing `BeginOperation`:

```
[MIKEYMINT:debug] Opened file SecureDeletionSecrets_1 with handle 1000, fileSize:<small>
[MIKEYMINT:err] Invalid key slot <N> would read past end of file of size <small>
[MIKEYMINT:debug] Decrypting blob with format: 2
[MIKEYMINT:err] auth_encrypted_key_blob.cpp, Line 198: EVP_DecryptFinal_ex error
[MIKEYMINT:info] do_dispatch #1 err: -33
```

If you see this exact signature, check whether secure-storage partitions are mounted before KeyMint/Gatekeeper services start.

### Testing Methodology Note

Testing via `adb shell mount` followed by `setprop ctl.stop/ctl.start` on the KeyMint service will **not** validate the mount fix — that restart sequence only re-runs the service's CONFIGURE handshake, not a real `BeginOperation`/decrypt retry. Validate with a **full rebuild + cold boot**. Live adb mutation gave misleading "still fails" results during this investigation before the actual init.rc fix was tried.

### DTB Verification

Compare DTB hashes between stock and build:

```bash
dd if=vendor_boot.img bs=1 skip=$((0x40)) 2>/dev/null | sha256sum
# or extract via unpack_bootimg
```
