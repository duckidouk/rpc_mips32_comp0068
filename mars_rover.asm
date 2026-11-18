	.data 
	
mbc_str: .asciiz "Welcome operator. Please enter the Maximum battery capacity: "
ibc_str: .asciiz "Please enter the initial battery charge: "
pdr_str: .asciiz "Please enter the power drain rate: "
time_display_str: .asciiz "Amount of seconds since beginning of mission: t= "
mission_start_display: .asciiz "Mission starts! Good luck! " 
error_ibc_isgreaterthan_mbc: .asciiz "Error: The Initial Battery Charge is greater than the Maximum Battery Capacity. \n"

#mbc:.word 0
#ibc: .word 0 
#pdr: .word 0 

 	.text
 	.globl main


.macro print_string (%str_input)
	li $v0, 4 
	la $a0, %str_input
	syscall
.end_macro 




.macro save_stack 
.end_macro 
 
main: 

# initialisation, we ask the user to input mbc int 
init:   

print_string(mbc_str)
 	
# user input, then copy to register $s1  	
 	li $v0, 5 
 	syscall 
 	add $s1, $0, $v0

ibc_init: 	 	
# we ask the user to input ibc
print_string(ibc_str)

# user inputs ibc	
 	addi $v0, $0, 5 
 	syscall
 	
# save ibc to $t1 for check 
	add $t1, $0, $v0   
		
#check for ibc <= mbc. If 1-> batt_save; Else 0 -> go to ibc_init
 	ble $t1, $s1, batt_save_ibc
 	
 	print_string(error_ibc_isgreaterthan_mbc)
 	j ibc_init
 	

batt_save_ibc:
# save ibc to $s2	
 	add $s2, $zero, $t1

#should probably be nested inside batt_save_ibc
#saves pre-checked battery $t1 --> $t0 current battery charge
batt_save_temporary:
	add $t0, $zero, $t1

# user inputs pdr int 	
print_string(pdr_str)

# copy to register $s3 	 	
 	li $v0, 5 
 	syscall 
 	add $s0, $0, $v0
 	
# itialise start [t=0] seconds. Load to $t1: POSSIBLY REDUNDANT
	addi $t1, $zero, 0
	
print_string(mission_start_display)







# program starts: 

# 3s passed --> [t=3]
	addi $t2, $zero, 3 

# pdr happens: pdr * cycle/second 

#	jal pdr 


# MAIN LOOP: 

# program asks the operator for input 
	#jal op_input 

# program executes operation:
	#jal c, d, r, q, etc... 
# 1s passed --> t += 1
	#jal pdr
	 
# program asks the operator for input




# Input: $t0 = current charge, $s4 = offline flag.
# Updates $t0 and $s4. Uses $t3, $a0 and $v0.
Check_Battery:
	#check if current charge over than zero or not
	slt $t2, $zero, $t0 
	bne $t2, $zero, Check_Battery_Done
	
	#if current charge lower than zero, then make the battery to zero and offline setting.
	addu $t0, $zero, $zero
	bne $s4, $zero, Check_Battery_Done
	addiu $s4, $zero, 1
	
	#print failure infor	
	li $v0, 4 
 	la $a0, checked_offline
 	syscall 
	
Check_Battery_Done:
	jr $ra
	
