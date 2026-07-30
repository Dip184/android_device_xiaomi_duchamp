# OrangeFox Device Tree — Xiaomi Poco X6 Pro (duchamp)

Fully working OrangeFox recovery with FBE decryption for `duchamp` (MT6897 / Dimensity 8300).

> **These blobs are the property of MediaTek/Xiaomi** and are extracted from the user's own device for interoperability purposes.

---

## If You're Forking This

⚠️ **Bring your own blobs.** Do not copy these binaries blindly — they are tied to HyperOS 3.0.7.0.WNLINXM. If you use mismatched blobs you will waste hours debugging cryptic TEE errors and questioning your life choices. Ask me how I know. 😂

Extract your own: `adb pull /sdcard/recovery_blobs/ ./`

---

#Working

    Display
    Touch
    Decryption
    Backup & Restore
    MTP/OTG Storage
    ADB
    Factory Reset
    
#Not working

     vibration
     
## Guides

| File | What's Inside |
|---|---|
| [decryptionguide.md](decryptionguide.md) | Compact, polished investigation — fixes ordered 1-6, TOC, ready for GitHub |
| [researchlog.md](researchlog.md) | Full chronological log — every session, every dead end, every breakthrough |

---

## Special Thanks

- **OrangeFox Discord Community** — for support throughout development
- **[@koaaN](https://github.com/koaaN)** — for the security patch level sync script
- **[@perilouspike](https://github.com/perilouspike)** — for the base device tree
- **TeamWin Recovery Project (TWRP)** — for the recovery framework and `prepdecrypt` mechanism this build's decrypt fix is built on
- **OrangeFox Recovery Project** — for the recovery this device tree targets


---

