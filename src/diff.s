# my version give it a file, and it will compare if it exists or not first
.include "modules/constants.s"
.section .rodata

filepath:
    .asciz ".gitignore"

parentdir:
    .asciz ".gitrv/parent/"

new_string:
    .asciz "new: "

modified_string:
    .asciz "modified: "

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
    mv a4, a0  # Save the full path for later use

    # check if file exists
    li a0, AT_FDCWD
    li a2, O_RDONLY
    li a7, SYS_OPENAT
    ecall
    li t0, BUFFER_SIZE
    add sp, sp, t0
    bltz a0, file_not_found
file_found:
    # file exists

    li t0, COPY_BUFFERS
    sub sp, sp, t0
    mv a1, sp
    li a2, BUFFER_SIZE
    la a0, filepath
    call readfile

    li t0, BUFFER_SIZE
    add a1, sp, t0
    mv a0, a4
    call readfile

    li t0, COPY_BUFFERS
    add a0, sp, t0
    call buffercmpr
    bnez a0, file_modified


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
    
file_modified:
    # file exists and is modified, do something else
    li t0, BUFFER_SIZE
    sub sp, sp, t0
    mv a0, sp
    la a1, modified_string
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
