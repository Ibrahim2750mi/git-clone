.include "modules/constants.s"

.global readfile

readfile:
    # a0 = pathname
    # a1 = buffer
    # a2 = buffer size
    # Returns: a0 = number of bytes read or negative error code
    # Returns: a1 = buffer (unchanged)

    mv t0, a0  # Save pathname
    mv t1, a1  # Save buffer pointer
    mv t2, a2  # Save buffer size

    beqz a2, readfile_error

    li a0, AT_FDCWD
    mv a1, t0  # pathname
    li a2, O_RDONLY
    li a7, SYS_OPENAT
    ecall   
    bltz a0, readfile_error
    mv t4, a0  # Save the opened file descriptor


    mv a1, t1  # buffer
    addi a2, t2, -1  # buffer size
    li a7, SYS_READ
    ecall
    mv t5, a0  # Save number of bytes read
    bltz a0, readfile_close_file

    add t3, t1, a0
    sb zero, 0(t3)  # Null-terminate the buffer

    readfile_close_file:
        mv a0, t4  # file descriptor
        li a7, SYS_CLOSE
        ecall
        j readfile_done
    readfile_done:
        mv a0, t5  # Return number of bytes read
        mv a2, t2  # Restore buffer size
        ret
    readfile_error:
        mv a2, t2  # Restore buffer size
        ret

.global appendfile
appendfile:
    # a0 = pathname
    # a1 = data buffer
    # a2 = number of bytes to append
    # Returns: a0 = bytes appended, or a negative Linux error code.
    mv t0, a0                  # pathname
    mv t1, a1                  # current data position
    mv t2, a2                  # bytes still to write
    mv t3, a2                  # original byte count / return value

    li a0, AT_FDCWD
    mv a1, t0
    li a2, O_RDWR | O_CREAT | O_APPEND
    li a3, 0644
    li a7, SYS_OPENAT
    ecall
    bltz a0, appendfile_done
    mv t4, a0                  # file descriptor

appendfile_write:
    beqz t2, appendfile_close
    mv a0, t4
    mv a1, t1
    mv a2, t2
    li a7, SYS_WRITE
    ecall
    blez a0, appendfile_write_error
    add t1, t1, a0
    sub t2, t2, a0
    j appendfile_write

appendfile_write_error:
    bnez a0, appendfile_save_error
    li t3, EIO                # a zero-byte write cannot make progress
    neg t3, t3
    j appendfile_close

appendfile_save_error:
    mv t3, a0

appendfile_close:
    mv a0, t4
    li a7, SYS_CLOSE
    ecall
    mv a0, t3

appendfile_done:
    ret

.global countlines
countlines:
    # a0 = pathname
    # Returns: a0 = number of '\n' bytes in the file, or a negative Linux error.
    li t6, 4112
    sub sp, sp, t6
    sd ra, 0(sp)
    mv t0, a0                  # pathname
    addi t2, sp, 16            # read buffer
    li t1, 0                   # line count

    li a0, AT_FDCWD
    mv a1, t0
    li a2, O_RDONLY
    li a7, SYS_OPENAT
    ecall
    bltz a0, countlines_restore
    mv t0, a0                  # file descriptor

countlines_read:
    mv a0, t0
    mv a1, t2
    li a2, BUFFER_SIZE
    li a7, SYS_READ
    ecall
    bltz a0, countlines_close_error
    beqz a0, countlines_close_success

    mv t3, t2
    add t4, t2, a0
countlines_scan:
    bgeu t3, t4, countlines_read
    lbu t5, 0(t3)
    li t6, 10                  # '\n'
    bne t5, t6, countlines_next
    addi t1, t1, 1
countlines_next:
    addi t3, t3, 1
    j countlines_scan

countlines_close_success:
    mv t5, t1
    mv a0, t0
    li a7, SYS_CLOSE
    ecall
    bltz a0, countlines_restore
    mv a0, t5
    j countlines_restore

countlines_close_error:
    mv t5, a0
    mv a0, t0
    li a7, SYS_CLOSE
    ecall
    mv a0, t5

countlines_restore:
    ld ra, 0(sp)
    li t6, 4112
    add sp, sp, t6
    ret

.global clean_directory
clean_directory:
    # a0 = directory pathname
    # Removes every entry below it except a directory named ".gitrv".
    # Returns: a0 = 0 on success, or a negative Linux error code.
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0
    li a0, AT_FDCWD
    mv a1, s0
    li a2, O_DIRECTORY | O_NOFOLLOW
    li a7, SYS_OPENAT
    ecall
    bltz a0, clean_directory_restore
    mv s1, a0
    mv a0, s1
    call clean_directory_fd
    mv s0, a0
    mv a0, s1
    li a7, SYS_CLOSE
    ecall
    mv a0, s0
clean_directory_restore:
    ld s1, 8(sp)
    ld s0, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret

# clean_directory_fd(a0 = directory fd)
clean_directory_fd:
    addi sp, sp, -96
    sd ra, 88(sp)
    sd s0, 80(sp)
    sd s1, 72(sp)
    sd s2, 64(sp)
    sd s3, 56(sp)
    sd s4, 48(sp)
    sd s5, 40(sp)
    sd s6, 32(sp)
    sd s7, 24(sp)
    mv s0, a0
    li s6, 0
    li t0, BUFFER_SIZE
    sub sp, sp, t0
    mv s1, sp

clean_directory_read:
    mv a0, s0
    mv a1, s1
    li a2, BUFFER_SIZE
    li a7, SYS_GETDENTS64
    ecall
    bltz a0, clean_directory_error
    beqz a0, clean_directory_done
    mv s2, s1
    add s3, s1, a0
clean_directory_entry:
    bgeu s2, s3, clean_directory_read
    lhu t0, 16(s2)
    beqz t0, clean_directory_bad_entry
    add t1, s2, t0
    bgtu t1, s3, clean_directory_bad_entry
    lbu s5, 18(s2)
    addi s4, s2, 19
    mv s2, t1

    # Skip . and ..
    lbu t0, 0(s4)
    li t1, '.'
    bne t0, t1, clean_directory_type
    lbu t0, 1(s4)
    beqz t0, clean_directory_entry
    bne t0, t1, clean_directory_type
    lbu t0, 2(s4)
    beqz t0, clean_directory_entry

clean_directory_type:
    li t0, DT_DIR
    bne s5, t0, clean_directory_unlink_file
    # Preserve the repository data directory.
    lbu t0, 0(s4)
    li t1, '.'
    bne t0, t1, clean_directory_open_child
    lbu t0, 1(s4)
    li t1, 'g'
    bne t0, t1, clean_directory_open_child
    lbu t0, 2(s4)
    li t1, 'i'
    bne t0, t1, clean_directory_open_child
    lbu t0, 3(s4)
    li t1, 't'
    bne t0, t1, clean_directory_open_child
    lbu t0, 4(s4)
    li t1, 'r'
    bne t0, t1, clean_directory_open_child
    lbu t0, 5(s4)
    li t1, 'v'
    bne t0, t1, clean_directory_open_child
    lbu t0, 6(s4)
    beqz t0, clean_directory_entry

clean_directory_open_child:
    mv a0, s0
    mv a1, s4
    li a2, O_DIRECTORY | O_NOFOLLOW
    li a7, SYS_OPENAT
    ecall
    bltz a0, clean_directory_error
    mv s7, a0
    mv a0, s7
    call clean_directory_fd
    mv s6, a0
    mv a0, s7
    li a7, SYS_CLOSE
    ecall
    bltz s6, clean_directory_done
    mv a0, s0
    mv a1, s4
    li a2, AT_REMOVEDIR
    li a7, SYS_UNLINKAT
    ecall
    bltz a0, clean_directory_error
    j clean_directory_entry

clean_directory_unlink_file:
    mv a0, s0
    mv a1, s4
    li a2, 0
    li a7, SYS_UNLINKAT
    ecall
    bltz a0, clean_directory_error
    j clean_directory_entry

clean_directory_bad_entry:
    li s6, EIO
    neg s6, s6
    j clean_directory_done
clean_directory_error:
    mv s6, a0
clean_directory_done:
    mv a0, s6
    li t0, BUFFER_SIZE
    add sp, sp, t0
    ld s7, 24(sp)
    ld s6, 32(sp)
    ld s5, 40(sp)
    ld s4, 48(sp)
    ld s3, 56(sp)
    ld s2, 64(sp)
    ld s1, 72(sp)
    ld s0, 80(sp)
    ld ra, 88(sp)
    addi sp, sp, 96
    ret
