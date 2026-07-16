.include "modules/constants.s"

.section .rodata
dot:       .asciz "."
initdir:   .asciz ".gitrv"
parentdir: .asciz ".gitrv/parent"

.section .text
.global _start
_start:
    li a0, AT_FDCWD
    la a1, initdir
    li a2, 0755
    li a7, SYS_MKDIRAT
    ecall
    bgez a0, init_parent
    li t0, EEXIST
    neg t0, t0
    bne a0, t0, init_failure

init_parent:
    li a0, AT_FDCWD
    la a1, parentdir
    li a2, 0755
    li a7, SYS_MKDIRAT
    ecall
    bgez a0, init_snapshot
    li t0, EEXIST
    neg t0, t0
    bne a0, t0, init_failure

init_snapshot:
    la a0, dot
    la a1, parentdir
    call snapshot_copy
    bltz a0, init_failure
    li a0, 0
    li a7, SYS_EXIT
    ecall

init_failure:
    li a0, 1
    li a7, SYS_EXIT
    ecall
