# Aria Kernel CI (Galaxy A13 A135F, Exynos850, 4.19.325)

Upload everything in this folder to a GitHub repo. No kernel source goes here: the workflow clones the kernel tree itself.
Output: artifact `Aria-Image` containing `Image` and `dtb.img` (flash both: the CPU/GPU range tweaks live in the device tree).

## Layout
```
.github/workflows/build-aria.yml               the workflow
.github/aria/pkenti-core.diff                  pkenti: CPU/GPU limits (exynos-acme, ect_parser, ufc, tmu, gpex_*)
.github/aria/pkenti-dts-cpu.diff               pkenti: CPU table rows 130 MHz ... 2314 MHz in exynos3830.dts
.github/aria/pkenti-dts-gpu.diff               pkenti: GPU table 100 ... 1196 MHz in exynos3830.dts
.github/aria/pkenti-gpu-pm.diff                pkenti: Mali "adaptive" power policy (GPU oc only)
.github/aria/pkenti-teo.diff                   pkenti: TEO idle governor
.github/aria/pkenti.config                     pkenti defconfig changes
.github/aria/selinux-always-permissive.diff    SELinux permissive patch
.github/aria/path-umount.diff                  path_umount backport (KernelSU guide)
.github/aria/mkdtbimg.py                       wraps exynos3830.dtb into dtb.img
```

## Build conditions (same as pkenti's CI)
Android prebuilt clang r450784d, `LLVM=1 LLVM_IAS=1 KCFLAGS=-w PLATFORM_VERSION=14 ANDROID_MAJOR_VERSION=14`, targets `Image dtbs`.

## Inputs
- `cpu_freq_mode`: stock | uc (130-2002 MHz) | oc (130-2314 MHz, pkenti's default; also locks the CPU max against userspace lowering it)
- `gpu_freq_mode`: stock | oc (100-1196 MHz, + adaptive power policy, GPU max locked against userspace lowering it)
- Boot parameters from his code still work: `cpu_min_c1= cpu_min_c2= cpu_max_c1= cpu_max_c2= gpu_min= gpu_max=` (kHz)
- `cpu_idle_teo` (default on), `pkenti_config` (default on), `physwizz_config` (default on)
- `cpu_governor` (all seven built in, default schedutil), `selinux`, `ksu_hook`
- `cpu_undervolt_uv` / `gpu_undervolt_uv`: kernel's own margin parameters `lit= big= g3d=` (0 = off)

## Not taken from pkenti, on purpose
- lz4armv8: replaces the whole LZ4 library API and nothing in his tree calls it.
- `iowait_boost_enable`: a field that does not exist in this tree and that nothing uses.
- dts bootargs (initramfs options): ROM-specific, not a tweak.
- His kernel/ and mm/ differences: only an older stable base, no tweaks.
