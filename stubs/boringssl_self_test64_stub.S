/*
 * Copyright (C) 2026 The Android Open Source Project
 * Copyright (C) 2026 Shripad
 * SPDX-License-Identifier: Apache-2.0
 *
 * Motorola Edge 70 Fusion (marvel)
 * Minimal 0-dependency static stub for boringssl_self_test64.
 *
 * Executes Linux AArch64 sys_exit(0) via kernel syscall (svc #0) with zero
 * Bionic dynamic linker or C runtime dependencies. Neutralizes reboot loops
 * triggered by boringssl-self-check-failed during early init or before APEX
 * decompressions have completed.
 */

    .global _start
    .text
    .align 4

_start:
    /* Status 0 */
    mov     x0, #0
    /* AArch64 sys_exit syscall nr = 93 */
    mov     x8, #93
    /* Enter Linux kernel */
    svc     #0

    /* Safety loop in the impossible case syscall returns */
1:
    b       1b
