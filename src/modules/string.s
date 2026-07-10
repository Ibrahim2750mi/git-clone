.global strcat

strcat:
    # a0 = destination string (char *)
    # a1 = source string (char *)
    # Returns: a0 = destination string (char *)

    mv t0, a0  # Save destination pointer
    mv t1, a1  # Save source pointer

    # Find the end of the destination string
    find_end:
        lb t2, 0(t0)      # Load byte from destination
        beqz t2, copy     # If null terminator, go to copy source
        addi t0, t0, 1    # Move to next byte in destination
        j find_end
    copy:
        lbu t2, 0(t1)      # Load byte from source
        sb t2, 0(t0)       # Store byte to destination
        beqz t2, done      # If null terminator, we're done
        addi t0, t0, 1     # Move to next byte in destination
        addi t1, t1, 1     # Move to next byte in source
        j copy
    done:
        ret          # Return destination pointer in a0

strlen:
    # a0 = string (char *)
    # Returns: a0 = length of string (size_t)

    mv t0, a0  # Save string pointer
    li t1, 0   # Initialize length counter

    count:
        lb t2, 0(t0)      # Load byte from string
        beqz t2, done     # If null terminator, we're done
        addi t1, t1, 1    # Increment length counter
        addi t0, t0, 1    # Move to next byte in string
        j count
    done:
        mv a0, t1         # Return length in a0
        ret

strcpy:
    # a0 = destination string (char *)
    # a1 = source string (char *)
    # Returns: a0 = destination string (char *)

    mv t0, a0  # Save destination pointer
    mv t1, a1  # Save source pointer

    copy:
        lbu t2, 0(t1)      # Load byte from source
        sb t2, 0(t0)       # Store byte to destination
        beqz t2, done      # If null terminator, we're done
        addi t0, t0, 1     # Move to next byte in destination
        addi t1, t1, 1     # Move to next byte in source
        j copy
    done:
        ret          # Return destination pointer in a0