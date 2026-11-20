# =====================================================================
# time_blocking.asm  --  Time passing (t += 1, natural drain PDR)
#                        version for BLOCKING input (syscall 8)
# COMP0068 Rover Power Controller
# ---------------------------------------------------------------------
# Only the time-passing functions. No main: merge into mars_rover.asm
# (put the .data lines into its .data section, the functions anywhere
# after main).
#
# Registers used (group convention):
#   $s0 = PDR                  (read)
#   $s3 = current charge       (read and written)
#   $s4 = elapsed seconds      (written)
#   $s5 = offline flag, 1 = offline (read and written)
#         ** $s5 is proposed, not yet on the whiteboard **
#
# Rules implemented (coursework brief):
#   - every second: t += 1, then charge -= PDR
#   - commands typed in a second run BEFORE that second's drain
#   - charge never below 0; reaching 0 by drain alone -> offline,
#     same offline error message
#   - while offline: no drain (time still counts)
#   - the second in which R happens: no drain (shows exactly IBC)
#
# How the main program uses it:
#       jal  time_init            # once, after the configuration
#   loop:
#       (print prompt, read a line with syscall 8)
#       jal  time_catch_up        # settle seconds that passed while waiting
#                                 # $v0 = how many (print telemetry if > 0)
#       (run the command; R must also  jal time_skip_next_drain)
#       jal  time_after_command   # drain for the command's own second
#       (print telemetry)
#       j    loop
#
# RULES FOR THE REST OF THE PROGRAM (read before merging):
#   1. Call time_init once, right before the main loop starts, after
#      PDR/MBC/IBC have been read and $s3 = IBC, $s5 = 0.
#   2. After EVERY line read with syscall 8, call time_catch_up FIRST,
#      before looking at the command. Otherwise the seconds spent
#      waiting are drained after the command instead of before it.
#   3. Use the $v0 returned by time_catch_up straight away (print the
#      telemetry line if it is > 0); the next call changes $v0.
#   4. After the command has run, call time_after_command exactly once.
#      Suggested: also call it for rejected input (invalid command,
#      "Rover is offline" reply), so every line moves the clock by one
#      second. Do not call it for Q.
#   5. Never call time_after_command twice for one line, and do not
#      call time_update yourself: time_catch_up already does that.
#   6. Calling any time_ function changes $t0-$t2, $v0, $a0, $a1 (and
#      $at). Do not keep a value there that you still need after the
#      call. $s3, $s4, $s5 are changed on purpose (charge, time,
#      offline flag); $s0-$s2, $s6, $s7, $sp and $ra are kept.
#   7. Commands must NOT drain power themselves; time_after_command
#      does it (command first, drain second).
#   8. Any command that brings the charge to 0 (T) must also set
#      $s5 = 1. If $s5 stays 0, the next second prints the offline
#      error a second time.
#   9. R must set $s3 = $s2 (IBC) and $s5 = 0, then
#      jal time_skip_next_drain, so the reset second shows exactly IBC.
#  10. time_offline_msg has the same text as checked_offline in
#      Check_Battery. Keep only one of them when merging.
#  11. This file is for input read with syscall 8 only. Nothing is
#      printed while the program waits; the waited seconds appear
#      after Enter. If input is changed to MMIO polling or interrupts,
#      use time_realtime.asm instead.
# =====================================================================

        .data
time_second_start:  .word 0             # time (ms) at which the current second started
time_skip_flag:     .word 0             # 1 = do not drain on the next settled second
time_offline_msg:   .asciiz "Error, charge level equal to or less than 0. Rover is offline!\n"

        .text
# time_init : start the mission clock at t = 0
time_init:
        li    $v0, 30                   # syscall 30: system time in ms
        syscall                         # $a0 = low 32 bits, $a1 = high 32 bits
        sw    $a0, time_second_start    # the first second starts now
        sw    $zero, time_skip_flag
        move  $s4, $zero                # t = 0
        jr    $ra

# time_pass_one_second : settle ONE simulated second
#   t += 1; if offline -> no drain; if skip flag -> clear it, no drain;
#   else charge -= PDR; if charge <= 0 -> charge = 0, offline, message
time_pass_one_second:
        addi  $s4, $s4, 1               # t += 1
        bne   $s5, $zero, time_pass_end # offline: drain suspended

        lw    $t0, time_skip_flag
        beq   $t0, $zero, time_pass_drain
        sw    $zero, time_skip_flag     # skip only once
        j     time_pass_end

time_pass_drain:
        sub   $s3, $s3, $s0             # charge -= PDR
        bgt   $s3, $zero, time_pass_end # still above 0: nothing else to do

        move  $s3, $zero                # clamp at 0, never negative
        li    $s5, 1                    # rover goes offline
        li    $v0, 4
        la    $a0, time_offline_msg
        syscall
time_pass_end:
        jr    $ra

# time_update : if a full second has passed, settle it.
# Returns $v0 = 1 if one second was settled, 0 otherwise.
time_update:
        addi  $sp, $sp, -4
        sw    $ra, 0($sp)

        li    $v0, 30
        syscall                         # $a0 = now (ms, low 32 bits)
        lw    $t0, time_second_start
        subu  $t1, $a0, $t0             # elapsed = now - start of this second
        slti  $t2, $t1, 1000            # elapsed < 1000 ? (negative also counts)
        bne   $t2, $zero, time_update_no

        addiu $t0, $t0, 1000            # next second starts exactly 1000 ms later
        sw    $t0, time_second_start
        jal   time_pass_one_second
        li    $v0, 1
        j     time_update_end
time_update_no:
        li    $v0, 0
time_update_end:
        lw    $ra, 0($sp)
        addi  $sp, $sp, 4
        jr    $ra

# time_catch_up : settle every full second that passed while waiting.
# Returns $v0 = number of seconds settled (0 if none).
time_catch_up:
        addi  $sp, $sp, -8
        sw    $ra, 4($sp)
        sw    $zero, 0($sp)             # counter lives on the stack
time_catch_up_loop:
        jal   time_update
        beq   $v0, $zero, time_catch_up_end
        lw    $t0, 0($sp)
        addi  $t0, $t0, 1
        sw    $t0, 0($sp)
        j     time_catch_up_loop
time_catch_up_end:
        lw    $v0, 0($sp)
        lw    $ra, 4($sp)
        addi  $sp, $sp, 8
        jr    $ra

# time_after_command : call right AFTER a command has run.
# Settles the second in which the command was typed.
time_after_command:
        addi  $sp, $sp, -4
        sw    $ra, 0($sp)
        lw    $t0, time_second_start
        addiu $t0, $t0, 1000            # this second is now used up
        sw    $t0, time_second_start
        jal   time_pass_one_second
        lw    $ra, 0($sp)
        addi  $sp, $sp, 4
        jr    $ra

# time_skip_next_drain : called by R, so the reset second shows IBC
time_skip_next_drain:
        li    $t0, 1
        sw    $t0, time_skip_flag
        jr    $ra
