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
        beqz t2, strcat_copy     # If null terminator, go to copy source
        addi t0, t0, 1    # Move to next byte in destination
        j find_end
    strcat_copy:
        lbu t2, 0(t1)      # Load byte from source
        sb t2, 0(t0)       # Store byte to destination
        beqz t2, strcat_done      # If null terminator, we're done
        addi t0, t0, 1     # Move to next byte in destination
        addi t1, t1, 1     # Move to next byte in source
        j strcat_copy
    strcat_done:
        ret          # Return destination pointer in a0

.global strlen
strlen:
    # a0 = string (char *)
    # Returns: a0 = length of string (size_t)

    mv t0, a0  # Save string pointer
    li t1, 0   # Initialize length counter

    strlen_count:
        lb t2, 0(t0)      # Load byte from string
        beqz t2, strlen_done     # If null terminator, we're done
        addi t1, t1, 1    # Increment length counter
        addi t0, t0, 1    # Move to next byte in string
        j strlen_count
    strlen_done:
        mv a0, t1         # Return length in a0
        ret

.global strcpy
strcpy:
    # a0 = destination string (char *)
    # a1 = source string (char *)
    # Returns: a0 = destination string (char *)

    mv t0, a0  # Save destination pointer
    mv t1, a1  # Save source pointer

    strcpy_copy:
        lbu t2, 0(t1)      # Load byte from source
        sb t2, 0(t0)       # Store byte to destination
        beqz t2, strcpy_done      # If null terminator, we're done
        addi t0, t0, 1     # Move to next byte in destination
        addi t1, t1, 1     # Move to next byte in source
        j strcpy_copy
    strcpy_done:
        ret          # Return destination pointer in a0
