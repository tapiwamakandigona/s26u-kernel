# How Android kernels are made and work — and what v0.8 changes

*Written 2026-07-29 as the research base for the v0.8 config tier. Plain
English, every claim sourced. Labels: VERIFIED = checked against primary
source / command output; ASSUMED = reasoned, not directly re-tested.*

---

## 1. What a kernel actually does

The kernel is the one program with direct hardware access. Everything else —
apps, Android itself — must ask it for hardware via **system calls**. Four
jobs matter here:

- **CPU scheduling** — decides which app/thread runs on which core, for how
  long. (On 6.6 the scheduler is EEVDF; tuning knobs live in `/proc/sys/sched*`.)
- **Memory** — hands out RAM, and when RAM runs low, compresses cold pages
  into **zram** (a compressed block device in RAM) instead of dropping them.
- **Networking** — the TCP stack. How fast a connection ramps up and how it
  reacts to packet loss is decided by the **congestion-control algorithm**.
- **Drivers** — code that talks to specific hardware: display, touch, WiFi,
  modem. Most ship as loadable **kernel modules** (`.ko` files).

## 2. How an Android (GKI) kernel is *made*

Phones used to ship fully custom per-model kernels — chaos. Since Android 11+
Google splits the world in two (VERIFIED, source.android.com "Kernel overview"
and "Kernel modules overview"):

- **GKI kernel** — Google's Generic Kernel Image: the hardware-independent
  core + a set of **GKI modules** (e.g. `rfkill.ko`), built from the **ACK**
  (Android Common Kernel) tree, which tracks an upstream LTS (ours: 6.6).
- **Vendor modules** — the SoC/device drivers (ours: Unisoc's `sprd_wlan_combo`,
  `sprdbt_tty`, …), shipped by the manufacturer in vendor partitions.

The two sides meet at the **KMI** — the *Kernel Module Interface*, a frozen
binary contract for one KMI generation (e.g. `android15-6.6`): same struct
layouts, same exported-symbol signatures (source.android.com, "Maintain a
stable kernel module interface"). This is why vendor drivers built by Unisoc
keep working on a kernel Google rebuilds every month.

Three enforcement details ran this whole project (all VERIFIED the hard way,
see `evidence/`):

1. **MODVERSIONS CRCs.** Every exported symbol carries a CRC of its type
   signature. A module loads only if all CRCs match. → Building even a
   slightly different source (6.6.139 vs 6.6.102) breaks vendor WiFi. That
   killed v0.1.
2. **Release stamp.** The kernel's version string (`uname -r`) is baked in at
   build time (`--config=stamp` + build number). Android resolves some
   on-demand modules by that string. → An unstamped `maybe-dirty` kernel
   silently never *attempted* the WiFi chain (v0.2–v0.4).
3. **Per-build module signing + protected exports.** Google signs GKI modules
   with a key generated fresh *per build*; the kernel trusts only its own
   build's key, and unsigned/untrusted modules may not use *protected*
   symbols. → Our kernel rejected Google's `rfkill.ko`
   (`exports protected symbol rfkill_alloc` → EPERM) and the whole WiFi/BT
   chain cascaded down (v0.5). v0.6+ ships **the same build's own signed**
   `rfkill.ko`, loaded early by a tiny module. (source.android.com,
   "Implement a GKI module partition": GKI modules are "Google build-time
   signed".)

**Build pipeline** (what CI does): fetch the exact per-build manifest Google
used → Kleaf (Bazel) compiles the pinned ACK + config → the defconfig gate
(`check_defconfig`) byte-compares our config vs a canonical regenerated one →
gates verify the release string, the signed modules, KSU presence, and (new in
v0.8) the tuning values → pack `boot.img` (header v4, kernel only — Android 15
splits ramdisk into `init_boot`).

## 3. What v0.8 changes, and why each is safe

v0.8 changes **default values only** — nothing structural. No symbol added or
removed, no struct/ABI change, no LTO → the CRCs the WiFi modules depend on
stay byte-identical (the v0.1 failure mode is impossible by construction).
Same reason KFENCE is turned off via its *sample interval* instead of
un-setting `CONFIG_KFENCE`: every KFENCE symbol stays compiled in.

| Change | Stock default | v0.8 default | Why |
|---|---|---|---|
| TCP congestion control | `cubic` | **`bbr`** | BBR models bandwidth + RTT instead of treating every loss as congestion; on lossy high-latency links it holds far more throughput. Especially relevant on Starlink: a 2026 measurement study found BBR "dominant" among classic algorithms on real Starlink paths (arXiv:2607.07133); WPI satellite testbeds show large BBR-vs-CUBIC gaps under loss (web.cs.wpi.edu/~claypool/papers/bbr-cubic-sat). |
| zram compressor | `lzo-rle` | **`zstd`** | zstd compresses noticeably *smaller* (more RAM saved) for a modest CPU cost that big.LITTLE phones absorb easily; it is the direction Android/ChromiumOS kernel work has moved (benchmarks: LWN.net/Articles/973757, Chromium zram patchwork series). Decompression speed — what you feel when switching apps — stays in the same class as lzo. |
| KFENCE sampling | `500` ms | **`0` (off)** | KFENCE is a sampling memory-bug detector for *debugging*. At interval 0 it never arms allocations → zero runtime overhead; the code stays built-in so a future debug session can re-arm it live via sysfs. (Kconfig help, VERIFIED: "Set this to 0 to disable KFENCE by default.") |

**Zero behavior risk argument:** the phone has already been running all three
values since 2026-07-22 via the S26U-KernelBoost/Flow module (VERIFIED
on-device). v0.8 only moves *when* they apply — from boot, by default, even if
the module is disabled — and removes the tiny boot-time window where stock
defaults were briefly active. The module stays installed and compatible; its
writes become idempotent confirmations.

## 4. How we know the build is correct before it ships (checks-first)

- `check_defconfig` is order- and default-sensitive. v0.8's exact 3-line
  defconfig delta was **pre-verified locally against the real pinned tree**
  (`1481f357a31c`) using the kernel's own `savedefconfig`: the delta between
  file and regenerated canonical form is byte-identical to the pristine
  baseline's (only pre-existing toolchain-gated lines differ). VERIFIED.
- CI then re-proves it end-to-end: config gate, KSU gate, **new v0.8 tuning
  gate** (the built `.config` must contain all five effective values),
  release-string prefix gate, signed-`rfkill` vermagic gate, and KMI strict
  mode stays ON as the in-CI CRC check.
- On-device remains the owner's gate: `fastboot boot` (never flash blind) →
  KSU manager "Working" + WiFi + BT + ~248 modules.

## Sources
- source.android.com/docs/core/architecture/kernel (GKI overview, modules,
  stable-KMI, GKI partitions, GKI versioning)
- android.googlesource.com/kernel/common/+/1481f357a31c (pinned source:
  net/ipv4/Kconfig, drivers/block/zram/Kconfig, lib/Kconfig.kfence,
  arch/arm64/configs/gki_defconfig — all lines cited above VERIFIED there)
- arXiv:2607.07133 — *Unveiling TCP BBR Dominance in Starlink Internet* (2026)
- web.cs.wpi.edu/~claypool/papers/bbr-cubic-sat — BBR vs CUBIC satellite
  testbed measurements (WPI)
- lwn.net/Articles/973757 — zram compression algorithm tunables + benchmarks
- This repo's `evidence/` — the v0.1→v0.7.1 post-mortems (CRC drift, release
  stamp, per-build module signing)
