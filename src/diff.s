# Recursive extension of the original recursedir -> diff design.
.include "modules/constants.s"

.section .rodata
currentdir:      .asciz "."
parentdir:       .asciz ".gitrv/parent/"
slash:           .asciz "/"
new_string:      .asciz "new: "
modified_string: .asciz "modified: "
newline:         .asciz "\n"

.section .text
.global _start
.global recursedir
.global diff

_start:
    la a0, currentdir
    call recursedir
    bltz a0, exit_failure
    li a0, 0
    li a7, SYS_EXIT
    ecall
exit_failure:
    li a0, 1
    li a7, SYS_EXIT
    ecall

# recursedir(a0 = directory path)
# Returns the count of new/modified regular files, or a negative error.
recursedir:
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
    sd s8, 16(sp)
    mv s0, a0
    li s4, 0
    li t0, COPY_BUFFERS
    sub sp, sp, t0
    mv s1, sp                    # getdents buffer
    li t0, BUFFER_SIZE
    add s2, sp, t0               # child-path buffer

    li a0, AT_FDCWD
    mv a1, s0
    li a2, O_RDONLY | O_DIRECTORY
    li a7, SYS_OPENAT
    ecall
    bltz a0, recursedir_restore
    mv s3, a0
recursedir_read:
    mv a0, s3
    mv a1, s1
    li a2, BUFFER_SIZE
    li a7, SYS_GETDENTS64
    ecall
    bltz a0, recursedir_close
    beqz a0, recursedir_success
    mv s5, s1
    add s6, s1, a0
recursedir_entry:
    bgeu s5, s6, recursedir_read
    lhu t0, 16(s5)
    beqz t0, recursedir_bad_entry
    add t1, s5, t0
    bgtu t1, s6, recursedir_bad_entry
    lbu s7, 18(s5)               # d_type
    addi s8, s5, 19              # d_name
    mv s5, t1

    # Ignore . and ..
    lbu t0, 0(s8)
    li t1, '.'
    bne t0, t1, recursedir_child
    lbu t0, 1(s8)
    beqz t0, recursedir_entry
    bne t0, t1, recursedir_child
    lbu t0, 2(s8)
    beqz t0, recursedir_entry
recursedir_child:
    mv a0, s2
    mv a1, s0
    call strcpy
    la a1, slash
    call strcat
    mv a1, s8
    call strcat

    li t0, DT_REG
    beq s7, t0, recursedir_file
    li t0, DT_DIR
    bne s7, t0, recursedir_entry

    # Do not scan the snapshot directory as part of the working tree.
    lbu t0, 0(s8)
    li t1, '.'
    bne t0, t1, recursedir_dir
    lbu t0, 1(s8)
    li t1, 'g'
    bne t0, t1, recursedir_dir
    lbu t0, 2(s8)
    li t1, 'i'
    bne t0, t1, recursedir_dir
    lbu t0, 3(s8)
    li t1, 't'
    bne t0, t1, recursedir_dir
    lbu t0, 4(s8)
    li t1, 'r'
    bne t0, t1, recursedir_dir
    lbu t0, 5(s8)
    li t1, 'v'
    bne t0, t1, recursedir_dir
    lbu t0, 6(s8)
    beqz t0, recursedir_entry
recursedir_dir:
    mv a0, s2
    call recursedir
    bltz a0, recursedir_close
    add s4, s4, a0
    j recursedir_entry
recursedir_file:
    mv a0, s2
    call diff
    bltz a0, recursedir_close
    add s4, s4, a0
    j recursedir_entry
recursedir_bad_entry:
    li a0, EIO
    neg a0, a0
    j recursedir_close
recursedir_success:
    mv a0, s4
recursedir_close:
    sd a0, 8(sp)
    mv a0, s3
    li a7, SYS_CLOSE
    ecall
    ld a0, 8(sp)
recursedir_restore:
    li t0, COPY_BUFFERS
    add sp, sp, t0
    ld s8, 16(sp)
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

# diff(a0 = current-file path)
# Builds .gitrv/parent/<current-file path>, then reports new/modified files.
diff:
    addi sp, sp, -80
    sd ra, 72(sp)
    sd s0, 64(sp)
    sd s1, 56(sp)
    sd s2, 48(sp)
    sd s3, 40(sp)
    sd s4, 32(sp)
    sd s5, 24(sp)
    sd s6, 16(sp)
    mv s0, a0
    li t0, BUFFER_SIZE
    sub sp, sp, t0
    mv s1, sp                    # snapshot pathname
    mv a0, s1
    la a1, parentdir
    call strcpy
    mv a1, s0
    call strcat

    li a0, AT_FDCWD
    mv a1, s0
    li a2, O_RDONLY
    li a7, SYS_OPENAT
    ecall
    bltz a0, diff_restore
    mv s2, a0
    li a0, AT_FDCWD
    mv a1, s1
    li a2, O_RDONLY
    li a7, SYS_OPENAT
    ecall
    bgez a0, diff_opened
    li t0, ENOENT
    neg t0, t0
    bne a0, t0, diff_current_error
    la a0, new_string
    mv a1, s0
    call report
    li s6, 1
    j diff_close_current
diff_opened:
    mv s3, a0
    li t0, COPY_BUFFERS
    sub sp, sp, t0
    mv s4, sp
    li t0, BUFFER_SIZE
    add s5, sp, t0
diff_read:
    mv a0, s2
    mv a1, s4
    li a2, BUFFER_SIZE
    li a7, SYS_READ
    ecall
    bltz a0, diff_read_error
    mv s6, a0
    mv a0, s3
    mv a1, s5
    li a2, BUFFER_SIZE
    li a7, SYS_READ
    ecall
    bltz a0, diff_read_error
    bne a0, s6, diff_modified
    beqz s6, diff_same
    mv t0, s4
    mv t1, s5
    mv t2, s6
diff_bytes:
    lbu t3, 0(t0)
    lbu t4, 0(t1)
    bne t3, t4, diff_modified
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, diff_bytes
    j diff_read
diff_same:
    li s6, 0
    j diff_close_both
diff_modified:
    la a0, modified_string
    mv a1, s0
    call report
    li s6, 1
    j diff_close_both
diff_read_error:
    mv s6, a0
diff_close_both:
    li t0, COPY_BUFFERS
    add sp, sp, t0
    mv a0, s3
    li a7, SYS_CLOSE
    ecall
diff_close_current:
    mv a0, s2
    li a7, SYS_CLOSE
    ecall
    mv a0, s6
    j diff_restore
diff_current_error:
    mv s6, a0
    j diff_close_current
diff_restore:
    li t0, BUFFER_SIZE
    add sp, sp, t0
    ld s6, 16(sp)
    ld s5, 24(sp)
    ld s4, 32(sp)
    ld s3, 40(sp)
    ld s2, 48(sp)
    ld s1, 56(sp)
    ld s0, 64(sp)
    ld ra, 72(sp)
    addi sp, sp, 80
    ret

report:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd a1, 0(sp)
    call write_string
    ld a0, 0(sp)
    call write_string
    la a0, newline
    call write_string
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
write_string:
    mv t0, a0
    li t1, 0
write_string_count:
    lbu t2, 0(t0)
    beqz t2, write_string_go
    addi t0, t0, 1
    addi t1, t1, 1
    j write_string_count
write_string_go:
    mv a2, t1
    mv a1, a0
    li a0, STDOUT
    li a7, SYS_WRITE
    ecall
    ret
