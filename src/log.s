.include "modules/constants.s"

.section .rodata
configfile:
    .asciz ".gitrv/config"

.section .bss
log_buffer:
    .space 4096

print_buffer:
    .space 32

.section .text

.global _start

_start:
    # Read file
    la  a0, configfile
    la  a1, log_buffer
    li  a2, BUFFER_SIZE
    call readfile

    mv  s0, a0              # bytes remaining
    la  s1, log_buffer      # current input pointer
    li  s2, 1               # current row number

log_loop:
    beqz s0, exit

    #
    # Print row number
    #
    mv  a0, s2
    la  a1, print_buffer
    call itoa

    # strlen(print_buffer)
    la  t0, print_buffer
itoa_strlen:
    lbu t1, 0(t0)
    beqz t1, itoa_strlen_done
    addi t0, t0, 1
    j itoa_strlen

itoa_strlen_done:
    la  a1, print_buffer
    sub a2, t0, a1

    li  a0, STDOUT
    li  a7, SYS_WRITE
    ecall

print_line:
    beqz s0, exit

    lbu t0, 0(s1)

    li  a0, STDOUT
    mv  a1, s1
    li  a2, 1
    li  a7, SYS_WRITE
    ecall

    addi s1, s1, 1
    addi s0, s0, -1

    li  t1, '\n'
    bne t0, t1, print_line

    addi s2, s2, 1
    j log_loop

exit:
    li  a0, 0
    li  a7, SYS_EXIT
    ecall
