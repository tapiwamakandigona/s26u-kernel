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

## 2026-07-28 — v1.1: DIAGNOSE.bat (owner-requested flow change)
- Owner flow: DIAGNOSE first -> owner sends logs -> generate tailored restore .bat.
- VERIFIED owner's claim: full stock firmware IS in the repos — release
  `firmware-S688LN-15.1.2.170SP05` on private itel-s26-ultra-Dev (7.35 GB
  split .7z, exact build OP001PF001AZ, reassembled sha256 cc18ca1d25d5...).
  PacExtractor + pac_manifest.json + spd_dump also present. So truly-deleted
  APKs CAN be recovered: extract from firmware -> ship as Magisk-mount module.
- DIAGNOSE.bat additions vs STEP-1: -f codePath existence check (flags
  MISSING_FILE for root-deleted APKs still tracked by PMS), on-disk app-dir
  listing, Magisk module+mask inventory, `debloat status` (their module).
- Note: packages fully forgotten by PMS are invisible to the device scan;
  those get caught later by diffing the logs against the firmware app list.

## 2026-07-28 — v1.2: diagnostics analyzed, tailored restore generated
- Owner ran DIAGNOSE.bat and returned S688LN-diagnostics.zip (both uploads
  byte-identical). Device confirmed: S688LN, build 170SP05 OP001PF001AZ.
- ANALYSIS (all VERIFIED from the logs):
  * 23 stock apps hidden via uninstall --user 0 (14_hidden.txt; recomputed
    04-03 diff matches exactly).
  * 4 apps disabled (05_disabled.txt).
  * 0 root-deleted system APKs. ALL 89 MISSING_FILE flags were false
    positives from a DIAGNOSE v1.1 parser bug: `f=${l%%=*}` truncates
    /data/app/~~<base64>==/ codePaths at the '=' padding. Proof: every
    flagged path continues with '==/' in 07_paths.txt; zero flags on
    /system|/product|/system_ext partitions.
  * 0 Magisk masks (12 empty); De-bloater module enabled but masks nothing.
  * Baseline diff (restore-kit/baseline_packages_20260721.txt on the private
    repo) vs current: no stock package forgotten by PMS. Firmware extraction
    NOT needed for this restore.
  * 6 apps under /product/operator/app looked absent from 09_app_dirs.txt
    only because the ls didn't include that dir; all 6 verified installed+enabled.
- FIXES in DIAGNOSE.bat (v1.2): suffix-based codePath parse
  (`p=${l##*=}; f=${l%%=$p}`) — VERIFIED clean against all 397 real codePath
  lines from the owner's 07_paths.txt; added /product/operator/app to the ls.
- NEW: RESTORE-CUSTOM.bat — tailored plan with the exact 23+4 package lists
  hardcoded; install-existing + pm enable only; no root, no flashing; ends
  with on-device verification (pm path per package + disabled count) and
  prints per-app undo commands. Device-side loops as usual (CRLF-safe).
- On-device execution by owner pending -> passes:false until confirmed.

## 2026-07-28 — v1.3: fix [2/3] — the 4 "disabled" apps are FACTORY-disabled
- Owner ran RESTORE-CUSTOM v1.2: step [1/3] hidden-app restore OK; step [2/3]
  3 of 4 `pm enable` FAILED (devicelockcontroller, scorpio.securitycom,
  gms.supervision), iotcard enabled.
- ROOT CAUSE (VERIFIED): July-21 recon baseline packages_disabled.txt lists
  the SAME 4 packages — factory-disabled, never user-disabled. Including them
  in the enable list was a v1.2 analysis error (05_disabled.txt was taken as
  user damage without diffing against the baseline disabled list).
- The 3 failures are the OS protecting dormant security modules
  (financed-device lock, Transsion payment lock, Kids supervision) from
  shell — failing was the correct outcome. Do NOT su-force them.
- iotcard did get enabled (not protected) -> v1.3 reverts it to factory
  state: `pm default-state`, verify still listed disabled, else
  `pm disable-user` fallback (exact factory state constant unknowable
  from recon, but end state matches baseline either way).
- Expected stock signature after v1.3: 0 hidden / 4 disabled.
- LESSON: always diff "disabled" against the factory baseline before
  calling it damage; `pm enable` failures on protected pkgs are a signal,
  not an error to force through.
- AI apps status: hidden-23 included kolun.aiservice, kolun.assistant,
  aiwallpaper (restored in step 1); aicore.matting/ocr, microintelligence,
  aiwriting.overlay, tranvoicecommand, aivoiceassistant overlay,
  imaging.aiengine, aigallery.clipper were never removed (enabled at
  baseline AND in current diagnostics). No AI package missing.
