solar_ok_str1:  .asciiz "Solar array aligned: +"
solar_ok_str2:  .asciiz " units.\n"
err_max_str:    .asciiz "Error, maximum battery capacity reached! Capped to the Max.\n"

# =====================================================================
# solar_align : command  S n
# ---------------------------------------------------------------------
# Effect   : charge += 2 x n, capped at MBC
# Input    : $a0 = n  (positive integer, already validated by the
#                      command parser)
# Uses     : $s1 = MBC, $s4 = current battery charge (read AND written)
# Output   : $s4 updated; message printed (confirmation OR cap error)
# Registers : $v0, $a0, $t0, $t3
# Notes    : - Does NOT apply the natural drain; the main loop calls the
#              pdr procedure afterwards (command first, drain second).
#            - Offline check (charge == 0 -> reject) is the caller's job.
#            - Landing exactly on MBC no error.
# =====================================================================
solar_align:
    bgt  $a0, $s1, solar_cap        # n > MBC => 2n > MBC (also avoids overflow)
    sll  $t0, $a0, 1                # 2 x n
    add  $t3, $s3, $t0              # pre-checked charge
    bgt  $t3, $s1, solar_cap
    add  $s3, $0, $t3               # commit

    li   $v0, 4
    la   $a0, solar_ok_str1
    syscall
    li   $v0, 1
    add  $a0, $0, $t0
    syscall
    li   $v0, 4
    la   $a0, solar_ok_str2
    syscall
    jr   $ra

solar_cap:
    add  $s3, $0, $s1               # clamp to MBC
    li   $v0, 4
    la   $a0, err_max_str
    syscall
    jr   $ra