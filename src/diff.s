# my version give it a file, and it will compare if it exists or not first
.include "modules/constants.s"
.section .rodata

currentdir:
    .asciz "."

filepath:
    .asciz ".gitignore"

parentdir:
    .asciz ".gitrv/parent/"

new_string:
    .asciz "new: "

modified_string:
    .asciz "modified: "

buffer:
    .space BUFFER_SIZE

.section .text

.global _start

_start:
    la a1, buffer
    li a2, BUFFER_SIZE



.global recursedir

recursedir:
    # a0 = directory path
    # a1 = buffer for file contents
    # a2 = buffer size
    # Returns: a0 = 0 on success, negative error code on failure

    la s0, currentdir  # Save directory path
    mv s1, a1  # Save buffer pointer
    mv s2, a2  # Save buffer size

    li a0, AT_FDCWD
    mv a1, s0  # directory path
    li a2, O_RDONLY | O_DIRECTORY
    li a7, SYS_OPENAT
    ecall   
    bltz a0, recursedir_error
    mv s3, a0  # Save the opened directory file descriptor

    la a1, s1  # buffer for file contents
    la a2, s2  # buffer size
    li a7, SYS_GETDENTS64
    ecall
    bltz a0, recursedir_close_dir

    mv s0, a1
    recursedir_entry:
        lhu s5, 16(s0)  # Read the d_reclen
        lbu s6, 18(s0)  # Read the d_type

        beq s6, DT_REG, recursedir_process_file
    
    l1:
        add s0, s5, s0

    recursedir_process_file:
        # Process the regular file
        addi s4, s0, 19  # Move to the d_name field
        call diff  # Call the diff function to compare the file
        j l1
        


.global diff

diff:
    # get file path
    # s4 = filepath
    li t0, BUFFER_SIZE
    sub sp, sp, t0
    mv a0, sp
    la a1, parentdir
    call strcpy

    mv a1, s4
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


    ret
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

    ret
    
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

    ret
