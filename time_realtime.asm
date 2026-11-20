# =====================================================================
# time_realtime.asm  --  Time passing (t += 1, natural drain PDR)
#                        version for REAL-TIME input (MMIO polling)
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
#   loop:                         # never waits for input
#       jal  time_second_passed             # $v0 = 1 if a full second has passed
#       beq  $v0, $zero, keys
#       (end the open prompt line, if any)
#       jal  time_update            # settle that second: t += 1, drain
#       (print telemetry and prompt again)
#   keys:
#       (check the MMIO keyboard; on Enter run the command right away;
#        R must also  jal time_skip_next_drain.  Do NOT drain here:
#        time_update drains when the second ends.)
#       j    loop
#
# RULES FOR THE REST OF THE PROGRAM (read before merging):
#   1. Call time_init once, right before the main loop starts, after
#      PDR/MBC/IBC have been read and $s3 = IBC, $s5 = 0.
#   2. The main loop must never stop and wait. Do not use syscall 5, 8
#      or 12 (they wait for Enter) and do not sleep for a second or
#      more (syscall 32). Otherwise the clock freezes.
#   3. Every pass of the loop: jal time_second_passed. Each call of
#      time_update settles at most ONE second; if the loop was held up
#      for longer, the next passes catch up one second each.
#   4. Calling any time_ function changes $t0-$t2, $v0, $a0, $a1 (and
#      $at). Do not keep a value there that you still need after the
#      call. $s3, $s4, $s5 are changed on purpose (charge, time,
#      offline flag); $s0-$s2, $s6, $s7, $sp and $ra are kept.
#   5. Commands must NOT drain power themselves. Run the command as
#      soon as Enter is pressed; time_update drains when that second
#      ends (command first, drain second).
#   6. Any command that brings the charge to 0 (T) must also set
#      $s5 = 1. If $s5 stays 0, the next second prints the offline
#      error a second time.
#   7. R must set $s3 = $s2 (IBC) and $s5 = 0, then
#      jal time_skip_next_drain, so the reset second shows exactly IBC.
#   8. time_update can print the offline error. If a prompt line is
#      still open on screen, print '\n' first so the error starts on a
#      new line.
#   9. time_offline_msg has the same text as checked_offline in
#      Check_Battery. Keep only one of them when merging.
#  10. Keys can only be typed in Tools -> Keyboard and Display MMIO
#      Simulator ("Connect to MIPS"). Tell the user at start-up.
#
# EXTRA RULES IF KEYBOARD INPUT USES INTERRUPTS
# (handler at .ktext 0x80000180):
#   a. An interrupt can happen between ANY two instructions, also in
#      the middle of time_update. The handler may only use $k0 and $k1.
#      Any other register it touches ($t0, $v0, $a0, ...) must be saved
#      first and restored before eret.
#   b. Pseudo-instructions (li, la, lw label, ...) use $at, and syscall
#      changes $v0/$a0: save these too, or avoid them in the handler.
#   c. The handler must not change $s3, $s4, $s5 (charge, time,
#      offline flag). It only stores the key in a buffer.
#   d. Commands run in the main loop, never inside the handler.
#   e. Keep the handler short and end it with eret.
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

# time_second_passed : has a full second passed? Only checks, settles nothing.
# Returns $v0 = 1 if yes, 0 if not.
time_second_passed:
        li    $v0, 30
        syscall
        lw    $t0, time_second_start
        subu  $t1, $a0, $t0             # elapsed ms
        slti  $v0, $t1, 1000            # 1 if elapsed < 1000
        xori  $v0, $v0, 1               # flip: 1 if a second is due
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

# time_skip_next_drain : called by R, so the reset second shows IBC
time_skip_next_drain:
        li    $t0, 1
        sw    $t0, time_skip_flag
        jr    $ra
