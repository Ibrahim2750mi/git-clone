.include "modules/constants.s"

.section .rodata

minus_m:
    .asciz "-m"
dirname:
    .asciz ".gitrv/"

newline:
    .asciz "\n"

configfilename:
    .asciz ".gitrv/config"

.section .bss
.align 3
commit_buffer:
    .space 4096
commit_dir:
    .space 4096
number_buffer:
    .space 21

.section .text
.global _start


_start:
    # Require: commit -m "message"
    ld t0, 0(sp)                 # argc
    li t1, 3
    bltu t0, t1, commit_failure
    ld t1, 16(sp)                # argv[1]
    ld t2, 24(sp)                # argv[2]

    la a1, minus_m
    mv a0, t1
    li a2, 3                     # "-m" including its NUL terminator
    call strcmpr
    bnez a0, commit_failure

    # strcmpr may overwrite temporary registers, so reload argv[2].
    ld t2, 24(sp)
    la a0, commit_buffer
    mv a1, t2
    call strcpy
    

    la a1, newline
    call strcat

    la a0, commit_buffer
    call strlen
    mv a2, a0
    la a1, commit_buffer
    la a0, configfilename
    call appendfile
    bltz a0, commit_failure

    la a0, configfilename
    call countlines
    bltz a0, commit_failure
    la a1, number_buffer
    call itoa

    # Build the writable path .gitrv/<commit-number>.
    la a0, commit_dir
    la a1, dirname
    call strcpy
    la a1, number_buffer
    call strcat

    li a0, AT_FDCWD
    la a1, commit_dir
    li a2, 0755
    li a7, SYS_MKDIRAT
    ecall
    bltz a0, commit_failure

    # now i wanna call init.s and repeat what it does in the .gitrv/number_of_lines folder, like all the current files of directory to this


    li a0, 0
    li a7, SYS_EXIT
    ecall

commit_failure:
    li a0, 1
    li a7, SYS_EXIT
    ecall
