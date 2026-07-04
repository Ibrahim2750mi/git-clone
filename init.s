.section .rodata

initdir: .asciz ".gitrv"
parentdir: .asciz ".gitrv/parent"

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

    li a0, -100
    li a2, 0
    li a7, 56 // openat "."
    ecall
    mv s3, a0 // s3 = fd
    
    li t0, 4096
    sub sp, sp, t0
    
    mv a0, s3
    mv a1, sp
    li a2, 4096
    li a7, 61 // getdents
    ecall
    mv s4, a0 // s4 = size

    bltz s4, error
    beqz s4, entries_done

    mv t0, sp
    add t1, sp, s4

entry_loop:
    beq t0, t1, entries_done

    lhu t2, 16(t0) // t2 = d_reclen
    lbu t3, 18(t0) // t3 = d_type
    addi t4, t0, 19 // t4 = d_name

    // Check if the entry is a directory (d_type == DT_DIR)
    li t5, 4       // DT_DIR = 4
    beq t3, t5, is_directory
    // Not a directory, open and read file
    mv a0, s3      // fd
    mv a1, t4      // buffer = d_name
    li a2, 4096    // size
    li a7, 56      // openat
    ecall
    mv t6, a0      // t6 = file descriptor
    // open destination file in parentdir
    la a0, parentdir
    mv a1, t4      // buffer = d_name
    li a2, 64      // flags = O_WRONLY | O_CREAT
    li a3, 0644    // mode
    li a7, 56      // openat
    ecall
    mv t7, a0      // t7 = destination file descriptor
    // read and write loop
read_write_loop:
    li a0, 0       // fd = source file descriptor
    mv a1, sp      // buffer
    li a2, 4096    // size
    li a7, 63      // read
    ecall
    mv t8, a0      // t8 = bytes read
    beqz t8, close_files // If no more bytes to read, close files
    mv a0, t7      // fd = destination file descriptor
    mv a1, sp      // buffer
    mv a2, t8      // size = bytes read
    li a7, 64      // write
    ecall
    j read_write_loop
    // close source and destination files
close_files:
    mv a0, t6      // fd = source file descriptor
    li a7, 57      // close
    ecall
    mv a0, t7      // fd = destination file descriptor
    li a7, 57      // close
    ecall
is_directory:
    // loop this process until is directory is false
    beqz t3, not_directory // If d_type is not DT_DIR, skip



    beqz t2, error // If d_reclen is 0, it's an error
    add t0, t0, t2

    j entry_loop

error:
    li a7, 93       # x17 = exit
    ecall

entries_done:
    li a7, 93       # x17 = exit
    ecall
