# S688LN system-app restore kit — PROJECT.md

## Goal
Restore EVERY stock system app removed during de-skinning on the itel S26
Ultra (itel S688LN, Android 15) **without a factory reset and without
re-flashing**. Ship it as a downloadable, self-contained kit (bundled
platform-tools + click-to-run scripts), built and published by GitHub CI —
same pattern as `flash-kit` in this repo.

## Standing decisions / constraints
- **Never write a partition.** Only PackageManager is used
  (`cmd package install-existing`, `pm enable`). No fastboot, no boot/vendor/
  init_boot writes. Matches the owner's golden safety rules.
- **No root required for the core restore.** Root is only used, optionally,
  to disable a Magisk debloat module (reversible: drops a `disable` flag).
- **Idempotent.** STEP-2 is safe to re-run; install-existing on an already
  installed package is a no-op.
- **Device-side loops.** Enumeration + restore loops run inside `adb shell`
  (device `sh`) to avoid Windows CRLF/parsing bugs.
- Home repo: `tapiwamakandigona/s26u-kernel` (public, free Actions runners).

## Removal methods covered
1. `pm uninstall --user 0` (hidden, APK still in /system) → `install-existing`.
2. `pm disable-user` (switched off) → `pm enable`.
3. Magisk systemless mask → disable the module + reboot (RESTORE-MAGISK-DEBLOAT).
Out of scope: root `rm` of the actual APK from /system (needs dirty-flash).

## Files
- `READ-ME-FIRST.txt` — user guide + safety.
- `STEP-1-SCAN.bat` — read-only report (counts + full lists).
- `STEP-2-RESTORE-ALL.bat` — enable-all + install-existing-all.
- `STEP-3-VERIFY.bat` — read-only confirmation vs baseline.
- `RESTORE-MAGISK-DEBLOAT.bat` — root path for module-masked apps.
- `linux-mac/restore-all.sh` — scan/restore/verify/modules for Linux/macOS.
- `../.github/workflows/restore-kit.yml` — bundles platform-tools, zips,
  SHA256SUMS, publishes a Release.

## Session-start ritual
Read this file, `features.json`, `progress.md`. Search the repo before
assuming anything is unbuilt. One task per iteration; verify; commit.
