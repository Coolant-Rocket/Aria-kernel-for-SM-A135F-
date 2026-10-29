# Aria Kernel CI (Galaxy A13 A135F, Exynos850, 4.19.325)

Upload everything in this folder to a GitHub repo. No kernel source goes here:
the workflow clones the kernel tree itself.

## Layout
```
.github/workflows/build-aria.yml        the workflow
.github/aria/selinux-always-permissive.diff   SELinux permissive patch
.github/aria/originsu/kernel-integration.diff OriginSU integration (from your reference)
.github/aria/susfs/                     SUSFS 2.3.0: 4.19 patch, inline-hook script, 2 compat diffs
.github/aria/mkdtbimg.py                builds dtb.img for AnyKernel3
anykernel/                              your A135F-Unbound AnyKernel3 (anykernel.sh, tools, META-INF)
```

## Run it
Actions -> "Build Aria Kernel (A135F)" -> Run workflow.

| Input | Default | Meaning |
|---|---|---|
| kernel_repo / kernel_branch | Samsung-Galaxy-A13-A135F-Development/android_kernel_samsung_exynos850 / lineage-24.0 | kernel tree cloned online |
| ksu | originsu | `originsu` (has SUSFS) or `backslashxx` (no SUSFS) |
| selinux | enforcing | `enforcing` or `permissive` |
| susfs | true | SUSFS 2.3.0, originsu only |
| ksu_hook | branch_link | backslashxx only: `branch_link` or `syscall_table` |
| ksu_repo / ksu_ref | empty | override KSU repo / branch / commit |
| defconfig | exynos850-a13nsxx_defconfig | |

Output: artifact `Aria-A135F-<date>-<ksu>-<selinux>[-susfs]-<hash>.zip` (flash in recovery),
plus Image, System.map and .config.

After the first green build, copy the KSU commit hash from the run summary into `ksu_ref` to pin it.
