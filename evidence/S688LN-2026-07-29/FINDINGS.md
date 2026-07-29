# S688LN 2026-07-29 — v0.7.1 `ksun`: KernelSU-Next in-kernel, WiFi + BT alive, Magisk removed

**Outcome: SUCCESS, VERIFIED on-device.** The `ksun` profile kernel
(`v0.7.1`) boots, KernelSU-Next v3.3.0 reports **Working — BUILT-IN (GKI2)**,
all 5 modules load, WiFi and Bluetooth work, and **Magisk has been fully
uninstalled** — KSU-Next is now the only root manager on the device.

This closes the `on-device-verified` owner gate for the ksun subproject.

## Evidence in this directory

| File | What it shows |
|---|---|
| `uname.txt` / `proc_version.txt` | Running kernel = `6.6.102-android15-8-g1481f357a31c-dirty-ab14794947-4k`, byte-identical to the string logged by ksun CI run 30405396108. Proves the booted image is ours. |
| `lsmod.txt` | **248 modules = exactly the stock count** (v0.5 managed only 234). |
| `wifi_bt_chain.txt` | `rfkill 36864 2 sprdbt_tty,cfg80211`; `cfg80211 … 1 sprd_wlan_combo`; `unisoc_wcn_bsp … 4 …`. The full keystone chain is up — i.e. the same-run signed `rfkill.ko` was accepted. |
| `wlan0_state.txt` | `wlan0 … UP,LOWER_UP … state UP` (MAC redacted). |
| `switch_states.txt` | `1` / `1` — WiFi and Bluetooth toggles both on. |
| `ksu_manager_home.jpg` | KSU-Next: **Working**, `BUILT-IN (GKI2)`, **v3.3.0 (33214-2)**, Modules **5**, Superuser 0. |
| `ksu_manager_info.jpg` | Kernel version, Android 15 (35), arm64-v8a, **SELinux Enforcing**, Seccomp Filter. |

Owner report (2026-07-29 22:30 CAT): *"it working magisk is uninstalled the
modules show in kernel su and wifi and bluetooth work."*

## Confirmations

1. **The KSU version-code fix landed.** Manager shows `33214-2` — the
   Kbuild `KSU_VERSION_FALLBACK := 33214` patch from iteration 4 worked; the
   earlier "kernel su next version 1 is too low" error is gone.
2. **Same-run signing discipline is the whole ballgame.** v0.7 failed WiFi/BT
   only because a stale v0.6-signed `s688ln_wifi_fix` was still installed.
   With the matched v0.7.1 pair (boot.img + `s688ln-wifi-fix-v0.7.1-ksun.zip`)
   the chain loads first try. *Never mix a kernel with another run's kos.*
3. **The wifi-fix module is root-agnostic in practice, not just in theory** —
   it now runs under KernelSU with Magisk gone, unchanged.
4. **SELinux stayed Enforcing** with KSU built in.

## Corrections to earlier docs

- `ksun/PROJECT.md` planned **kprobe** hook mode; the manager reports
  **Hook mode: Tracepoint** on the running build. Functionally fine (root
  works), but the doc should say tracepoint for v3.3.0.
- `README.md` line *"Keep Magisk for root (don't rebuild root into the
  kernel)"* is now **obsolete** — root is in the kernel and Magisk is gone.

## Known gaps (not blockers)

- `fix_module_log.txt` / `fix_module_files.txt` in the owner's gather zip came
  back `su: inaccessible or not found` — the gather script ran from a shell
  with no KSU superuser grant (manager shows **Superuser 0**). Not included
  here. Grant the terminal/ADB shell root in KSU before the next gather.
- **Metamodule status: Not installed.** Modules still mount fine, so this is
  informational only.
- **No SUSFS** in this kernel (deliberately deferred, see `ksun/PROJECT.md`),
  and uname carries `-dirty`. Root hiding is therefore userspace-only
  (KSU App Profile umount + Zygisk Next + friends). A `ksun-susfs` profile is
  the natural v0.8.
- Raw `logcat_tail.txt`, `dmesg.txt` (empty — needed root) and the full
  property dump from the owner's zip are intentionally **not** committed to
  this public repo.
