.include "modules/constants.s"

.section .rodata
parentdir: .asciz ".gitrv/"
dot:       .asciz "."

.section .bss
.align 3
snapshot_path: .space 4096

.section .text
.global _start
_start:
    # Require: checkout <commit-number>
    ld t0, 0(sp)
    li t1, 2
    bltu t0, t1, checkout_failure
    ld t1, 16(sp)                # argv[1]

    la a0, snapshot_path
    la a1, parentdir
    call strcpy
    # strcpy may overwrite temporary registers; reload argv[1].
    ld t1, 16(sp)
    mv a1, t1
    call strcat

    # Validate that the requested snapshot directory exists before deleting.
    li a0, AT_FDCWD
    la a1, snapshot_path
    li a2, O_DIRECTORY | O_NOFOLLOW
    li a7, SYS_OPENAT
    ecall
    bltz a0, checkout_failure
    mv t0, a0
    mv a0, t0
    li a7, SYS_CLOSE
    ecall

    la a0, dot
    call clean_directory
    bltz a0, checkout_failure

    la a0, snapshot_path
    la a1, dot
    call snapshot_copy
    bltz a0, checkout_failure

    li a0, 0
    li a7, SYS_EXIT
    ecall
checkout_failure:
    li a0, 1
    li a7, SYS_EXIT
    ecall
