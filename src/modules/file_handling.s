.global readfile

readfile:
    # a0 = pathname
    # a1 = buffer
    # a2 = buffer size
    # Returns: a0 = number of bytes read or negative error code
    beqz a2, readfile_error

    mv t0, a0  # Save pathname
    mv t1, a1  # Save buffer pointer
    mv t2, a2  # Save buffer size

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
        ret
    readfile_error:
        ret
