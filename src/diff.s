# my version give it a file, and it will compare if it exists or not first
.include "modules/constants.s"
.section .rodata

filepath:
    .asciz "file.txt"

parentdir:
    .asciz ".gitrv/parent/"

new_string:
    .asciz "new: "

.section .text
.global _start

_start:
    # get file path
    li t0, BUFFER_SIZE
    sub sp, sp, t0
    mv a0, sp
    la a1, parentdir
    call strcpy

    la a1, filepath
    call strcat

    mv a1, a0

    # check if file exists
    li a0, AT_FDCWD
    li a2, O_RDONLY
    li a7, SYS_OPENAT
    ecall
    li t0, BUFFER_SIZE
    add sp, sp, t0
    bltz a0, file_not_found
file_found:
    # file exists, do something
    li a0, 0
    li a7, SYS_EXIT
    ecall
file_not_found:
    # file does not exist, do something else
    li t0, BUFFER_SIZE
    sub sp, sp, t0
    mv a0, sp
    la a1, new_string
    call strcpy
    la a1, filepath
    call strcat

    mv a1, a0
    call strlen
    mv a2, a0
    
    li a0, STDOUT
    li a7, SYS_WRITE
    ecall

    li t0, BUFFER_SIZE
    add sp, sp, t0

    li a0, 0
    li a7, SYS_EXIT
    ecall
