.section .rodata

initdir: .asciz ".gitrv"
parentdir: .asciz "..gitrv/parentdir"

.section .text
.global _start

mkdir: // a0 = dirname, a1 = mode
    mv a2, a1       # x12 = mode
    mv a1, a0       # x11 = pathname
    li a0, -100     # x10 = AT_FDCWD
    li a7, 34       # x17 = mkdirat
    ecall
    ret             # jalr x0, 0(ra)


_start:

    la a0, initdir
    li a1, 0755
    jal x1, mkdir

    bnez a0, error
    
    la a0, parentdir
    li a1, 0755
    jal x1, mkdir

error:
    li a7, 93       # x17 = exit
    ecall
