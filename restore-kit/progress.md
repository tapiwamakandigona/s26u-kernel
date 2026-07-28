# progress.md — S688LN restore kit (append-only)

## 2026-07-28 — v1.0 initial build
- Confirmed device from repo evidence: itel S688LN, Android 15 (SDK 35),
  Magisk root on stock kernel; owner de-skins via ADB + Magisk modules.
- Chose non-destructive restore path (PackageManager only), covering the
  three removal methods the owner actually uses. No firmware writes.
- Wrote STEP-1/2/3 .bat (Windows, bundled platform-tools), a Magisk-module
  restore .bat, and a Linux/macOS restore-all.sh.
- Key robustness decision: run enumeration/restore loops INSIDE `adb shell`
  (device sh) instead of parsing package lists in batch — dodges the classic
  CRLF-breaks-`%%p` bug in Windows FOR loops over adb output.
- STEP-1/STEP-3 are strictly read-only; STEP-2 idempotent.
- Added CI workflow restore-kit.yml to bundle platform-tools + zip + SHA256 +
  publish a Release, mirroring the existing flash-kit CI pattern.
- VERIFIED locally: batch/sh/yml syntax + logic review. NOT yet verified on
  the physical phone (no device in the sandbox) — features that require the
  handset are marked passes:false pending an owner run.

## 2026-07-28 — CI verified, released
- Pushed to main; dispatched restore-kit.yml (run 30333294466) -> success.
- Release `restore-kit-v1.0` published: S688LN-restore-kit-v1.0.zip (8.1 MB,
  bundles Windows platform-tools adb.exe) + SHA256SUMS.txt.
- VERIFIED: downloaded zip sha256 == published SHA256SUMS (7b203b3c9030...).
- Remaining passes:false features require the physical phone (owner run).
