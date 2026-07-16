# Recursive extension of the original recursedir -> diff design.
.include "modules/constants.s"

.section .rodata
currentdir:      .asciz "."
parentdir:       .asciz ".gitrv/parent/"
gitrvdir:        .asciz ".gitrv/"
zero_string:     .asciz "0"
slash:           .asciz "/"
new_string:      .asciz "new: "
modified_string: .asciz "modified: "
deleted_string:  .asciz "deleted: "
newline:         .asciz "\n"

.section .bss
comparebase:     .space 4096

.section .text
.global _start
.global recursedir
.global recurse_deleted
.global diff

_start:
    ld t0, 0(sp)                 # argc
    li t1, 2
    blt t0, t1, use_parent_base

    ld t0, 16(sp)                # argv[1]
    lbu t1, 0(t0)
    li t2, '0'
    bne t1, t2, use_commit_base
    lbu t1, 1(t0)
    bnez t1, use_commit_base
use_parent_base:
    la a0, comparebase
    la a1, parentdir
    call strcpy
    j start_diff

use_commit_base:
    la a0, comparebase
    la a1, gitrvdir
    call strcpy
    ld a1, 16(sp)                # argv[1]
    call strcat
    la a1, slash
    call strcat

start_diff:
    la a0, currentdir
    call recursedir
    bltz a0, exit_failure
    mv s0, a0
    la a0, comparebase
    call recurse_deleted
    bltz a0, exit_failure
    add a0, a0, s0
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

# recurse_deleted(a0 = snapshot directory path)
# Walks the selected snapshot tree and reports files missing from the working tree.
recurse_deleted:
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
    bltz a0, recurse_deleted_restore
    mv s3, a0
recurse_deleted_read:
    mv a0, s3
    mv a1, s1
    li a2, BUFFER_SIZE
    li a7, SYS_GETDENTS64
    ecall
    bltz a0, recurse_deleted_close
    beqz a0, recurse_deleted_success
    mv s5, s1
    add s6, s1, a0
recurse_deleted_entry:
    bgeu s5, s6, recurse_deleted_read
    lhu t0, 16(s5)
    beqz t0, recurse_deleted_bad_entry
    add t1, s5, t0
    bgtu t1, s6, recurse_deleted_bad_entry
    lbu s7, 18(s5)               # d_type
    addi s8, s5, 19              # d_name
    mv s5, t1

    # Ignore . and ..
    lbu t0, 0(s8)
    li t1, '.'
    bne t0, t1, recurse_deleted_child
    lbu t0, 1(s8)
    beqz t0, recurse_deleted_entry
    bne t0, t1, recurse_deleted_child
    lbu t0, 2(s8)
    beqz t0, recurse_deleted_entry
recurse_deleted_child:
    mv a0, s2
    mv a1, s0
    call strcpy
    la a1, slash
    call strcat
    mv a1, s8
    call strcat

    li t0, DT_REG
    beq s7, t0, recurse_deleted_file
    li t0, DT_DIR
    bne s7, t0, recurse_deleted_entry
    mv a0, s2
    call recurse_deleted
    bltz a0, recurse_deleted_close
    add s4, s4, a0
    j recurse_deleted_entry
recurse_deleted_file:
    mv a0, s2
    call check_deleted
    bltz a0, recurse_deleted_close
    add s4, s4, a0
    j recurse_deleted_entry
recurse_deleted_bad_entry:
    li a0, EIO
    neg a0, a0
    j recurse_deleted_close
recurse_deleted_success:
    mv a0, s4
recurse_deleted_close:
    sd a0, 8(sp)
    mv a0, s3
    li a7, SYS_CLOSE
    ecall
    ld a0, 8(sp)
recurse_deleted_restore:
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
# Builds <selected-base>/<current-file path>, then reports new/modified files.
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
    la a1, comparebase
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

# check_deleted(a0 = snapshot-file path)
# Reports deleted files by checking whether the working-tree counterpart exists.
check_deleted:
    addi sp, sp, -48
    sd ra, 40(sp)
    sd s0, 32(sp)
    sd s1, 24(sp)
    sd s2, 16(sp)
    mv s0, a0
    li t0, BUFFER_SIZE
    sub sp, sp, t0
    mv s1, sp                    # current pathname

    # Skip comparebase and keep the leading '.' from paths like "./sub/file".
    la t0, comparebase
    mv t1, s0
check_deleted_strip:
    lbu t2, 0(t0)
    beqz t2, check_deleted_build
    addi t0, t0, 1
    addi t1, t1, 1
    j check_deleted_strip
check_deleted_build:
    lbu t2, 0(t1)
    li t3, '/'
    beq t2, t3, check_deleted_from_slash
    li t3, '.'
    beq t2, t3, check_deleted_copy
    li t2, '.'
    sb t2, 0(s1)
    li t2, '/'
    sb t2, 1(s1)
    addi a0, s1, 2
    mv a1, t1
    call strcpy
    j check_deleted_open
check_deleted_from_slash:
    li t2, '.'
    sb t2, 0(s1)
    addi a0, s1, 1
    mv a1, t1
    call strcpy
    j check_deleted_open
check_deleted_copy:
    mv a0, s1
    mv a1, t1
    call strcpy

check_deleted_open:
    li a0, AT_FDCWD
    mv a1, s1
    li a2, O_RDONLY
    li a7, SYS_OPENAT
    ecall
    bgez a0, check_deleted_exists
    li t0, ENOENT
    neg t0, t0
    bne a0, t0, check_deleted_restore_error
    la a0, deleted_string
    mv a1, s1
    call report
    li s2, 1
    j check_deleted_restore
check_deleted_exists:
    mv s2, zero
    sd a0, 8(sp)
    li a7, SYS_CLOSE
    ecall
    j check_deleted_restore
check_deleted_restore_error:
    mv s2, a0
check_deleted_restore:
    li t0, BUFFER_SIZE
    add sp, sp, t0
    mv a0, s2
    ld s2, 16(sp)
    ld s1, 24(sp)
    ld s0, 32(sp)
    ld ra, 40(sp)
    addi sp, sp, 48
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
