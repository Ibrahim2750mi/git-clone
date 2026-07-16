.include "modules/constants.s"

.section .rodata
dot:
    .asciz "."
initdir:
    .asciz ".gitrv"
parentdir:
    .asciz ".gitrv/parent"

.section .text

# mkdir_path(a0 = pathname, a1 = mode)
# Returns 0 on success or a negative Linux error number.
mkdir_path:
    mv a2, a1
    mv a1, a0
    li a0, AT_FDCWD
    li a7, SYS_MKDIRAT
    ecall
    ret

# copy_file(a0 = source directory fd, a1 = destination directory fd,
#           a2 = filename, a3 = address of a BUFFER_SIZE-byte buffer)
# Copies one regular file. Symlinks are rejected with O_NOFOLLOW.
copy_file:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    sd s6, 0(sp)

    mv s1, a0                  # source directory fd
    mv s2, a1                  # destination directory fd
    mv s3, a2                  # filename
    mv s4, a3                  # data buffer

    mv a0, s1
    mv a1, s3
    li a2, O_NOFOLLOW          # O_RDONLY | O_NOFOLLOW
    li a7, SYS_OPENAT
    ecall
    bltz a0, copy_file_restore
    mv s5, a0                  # source file fd

    mv a0, s2
    mv a1, s3
    li a2, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW
    li a3, 0644
    li a7, SYS_OPENAT
    ecall
    bltz a0, copy_file_close_source
    mv s6, a0                  # destination file fd

copy_file_read:
    mv a0, s5
    mv a1, s4
    li a2, BUFFER_SIZE
    li a7, SYS_READ
    ecall
    bltz a0, copy_file_io_error
    beqz a0, copy_file_success

    mv t0, s4                  # current write position
    mv t1, a0                  # bytes still to write

copy_file_write:
    mv a0, s6
    mv a1, t0
    mv a2, t1
    li a7, SYS_WRITE
    ecall
    blez a0, copy_file_io_error
    add t0, t0, a0
    sub t1, t1, a0
    bnez t1, copy_file_write
    j copy_file_read

copy_file_success:
    li s0, 0
    j copy_file_close_both

copy_file_io_error:
    mv s0, a0                  # preserve error across close syscalls
    bnez s0, copy_file_close_both
    li s0, -EIO               # write returning zero cannot make progress

copy_file_close_both:
    mv a0, s5
    li a7, SYS_CLOSE
    ecall
    mv a0, s6
    li a7, SYS_CLOSE
    ecall
    mv a0, s0
    j copy_file_restore

copy_file_close_source:
    mv s0, a0
    mv a0, s5
    li a7, SYS_CLOSE
    ecall
    mv a0, s0

copy_file_restore:
    ld s6, 0(sp)
    ld s5, 8(sp)
    ld s4, 16(sp)
    ld s3, 24(sp)
    ld s2, 32(sp)
    ld s1, 40(sp)
    ld s0, 48(sp)
    ld ra, 56(sp)
    addi sp, sp, 64
    ret

# copy_dir(a0 = source directory fd, a1 = destination directory fd)
# Recursively copies regular files and directories. It skips ".", "..",
# every directory named ".gitrv", symlinks, and other special files.
copy_dir:
    addi sp, sp, -112
    sd s11, 0(sp)
    sd s10, 8(sp)
    sd s9, 16(sp)
    sd s8, 24(sp)
    sd s7, 32(sp)
    sd s6, 40(sp)
    sd s5, 48(sp)
    sd s4, 56(sp)
    sd s3, 64(sp)
    sd s2, 72(sp)
    sd s1, 80(sp)
    sd s0, 88(sp)
    sd ra, 96(sp)

    mv s0, sp
    li t0, COPY_BUFFERS
    sub sp, sp, t0

    mv s1, a0                  # source directory fd
    mv s2, a1                  # destination directory fd
    mv s5, sp                  # directory-entry buffer
    li t0, BUFFER_SIZE
    add s6, sp, t0             # file-data buffer
    li s11, 0                  # return status

copy_dir_getdents:
    mv a0, s1
    mv a1, s5
    li a2, BUFFER_SIZE
    li a7, SYS_GETDENTS64
    ecall
    bltz a0, copy_dir_error
    beqz a0, copy_dir_done

    mv s3, s5                  # current linux_dirent64
    add s4, s5, a0             # end of valid directory data

copy_dir_entry:
    bgeu s3, s4, copy_dir_getdents

    lhu t0, 16(s3)             # d_reclen
    beqz t0, copy_dir_bad_entry
    lbu s8, 18(s3)             # d_type
    addi s7, s3, 19            # d_name
    add s3, s3, t0             # advance before making function calls

    # Skip "." and "..".
    lbu t0, 0(s7)
    li t1, 46                    # '.'
    bne t0, t1, copy_dir_check_type
    lbu t0, 1(s7)
    beqz t0, copy_dir_entry
    bne t0, t1, copy_dir_check_gitrv
    lbu t0, 2(s7)
    beqz t0, copy_dir_entry

copy_dir_check_gitrv:
    # Skip a directory only when its complete name is ".gitrv".
    li t0, DT_DIR
    bne s8, t0, copy_dir_check_type
    lbu t0, 1(s7)
    li t1, 103                   # 'g'
    bne t0, t1, copy_dir_check_type
    lbu t0, 2(s7)
    li t1, 105                   # 'i'
    bne t0, t1, copy_dir_check_type
    lbu t0, 3(s7)
    li t1, 116                   # 't'
    bne t0, t1, copy_dir_check_type
    lbu t0, 4(s7)
    li t1, 114                   # 'r'
    bne t0, t1, copy_dir_check_type
    lbu t0, 5(s7)
    li t1, 118                   # 'v'
    bne t0, t1, copy_dir_check_type
    lbu t0, 6(s7)
    beqz t0, copy_dir_entry

copy_dir_check_type:
    li t0, DT_DIR
    beq s8, t0, copy_dir_directory
    li t0, DT_REG
    bne s8, t0, copy_dir_entry

    mv a0, s1
    mv a1, s2
    mv a2, s7
    mv a3, s6
    call copy_file
    bltz a0, copy_dir_error
    j copy_dir_entry

copy_dir_directory:
    # Create the destination child; an existing directory is acceptable.
    mv a0, s2
    mv a1, s7
    li a2, 0755
    li a7, SYS_MKDIRAT
    ecall
    bgez a0, copy_dir_open_source_child
    li t0, -EEXIST
    bne a0, t0, copy_dir_error

copy_dir_open_source_child:
    mv a0, s1
    mv a1, s7
    li a2, O_DIRECTORY | O_NOFOLLOW
    li a7, SYS_OPENAT
    ecall
    bltz a0, copy_dir_error
    mv s9, a0                  # source child directory fd

    mv a0, s2
    mv a1, s7
    li a2, O_DIRECTORY | O_NOFOLLOW
    li a7, SYS_OPENAT
    ecall
    bltz a0, copy_dir_close_source_child
    mv s10, a0                 # destination child directory fd

    mv a0, s9
    mv a1, s10
    call copy_dir
    mv s11, a0

    mv a0, s9
    li a7, SYS_CLOSE
    ecall
    mv a0, s10
    li a7, SYS_CLOSE
    ecall

    bltz s11, copy_dir_done
    j copy_dir_entry

copy_dir_close_source_child:
    mv s11, a0
    mv a0, s9
    li a7, SYS_CLOSE
    ecall
    j copy_dir_done

copy_dir_bad_entry:
    li s11, -EIO
    j copy_dir_done

copy_dir_error:
    mv s11, a0

copy_dir_done:
    mv a0, s11
    mv sp, s0

    ld s11, 0(sp)
    ld s10, 8(sp)
    ld s9, 16(sp)
    ld s8, 24(sp)
    ld s7, 32(sp)
    ld s6, 40(sp)
    ld s5, 48(sp)
    ld s4, 56(sp)
    ld s3, 64(sp)
    ld s2, 72(sp)
    ld s1, 80(sp)
    ld s0, 88(sp)
    ld ra, 96(sp)
    addi sp, sp, 112
    ret


# snapshot_copy(a0 = existing destination directory path)
# Copies the working tree into a0, excluding .gitrv.
.global snapshot_copy
snapshot_copy:
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    sd s2, 0(sp)
    mv s0, a0

    li a0, AT_FDCWD
    la a1, dot
    li a2, O_DIRECTORY
    li a7, SYS_OPENAT
    ecall
    bltz a0, snapshot_restore
    mv s1, a0

    li a0, AT_FDCWD
    mv a1, s0
    li a2, O_DIRECTORY | O_NOFOLLOW
    li a7, SYS_OPENAT
    ecall
    bltz a0, snapshot_close_source
    mv s2, a0

    mv a0, s1
    mv a1, s2
    call copy_dir
    mv s0, a0

    mv a0, s1
    li a7, SYS_CLOSE
    ecall
    mv a0, s2
    li a7, SYS_CLOSE
    ecall
    mv a0, s0
    j snapshot_restore

snapshot_close_source:
    mv s0, a0
    mv a0, s1
    li a7, SYS_CLOSE
    ecall
    mv a0, s0

snapshot_restore:
    ld s2, 0(sp)
    ld s1, 8(sp)
    ld s0, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

