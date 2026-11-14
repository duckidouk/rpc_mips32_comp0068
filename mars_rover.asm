	.data 
mbc_str: .asciiz "Welcome operator. Please enter the Maximum battery capacity: "
ibc_str: .asciiz "Please enter the initial battery charge: "
pdr_str: .asciiz "Please enter the power drain rate: "
time_display_str: .asciiz "Amount of seconds since beginning of mission: t= "
error_ibc_isgreaterthan_mbc: .asciiz "Error: The Initial Battery Charge is greater than the Maximum Battery Capacity. \n"

mbc:.word 0
ibc: .word 0 
pdr: .word 0 







 	.text
 	.globl main
 
main: 

# initialisation, we ask the user to input mbc int 
init:   li $v0, 4
	la $a0, mbc_str
 	syscall
 	
# user input, then copy to register $s1  	
 	li $v0, 5 
 	syscall 
 	add $s1, $0, $v0

ibc_init: 	 	
# we ask the user to input ibc
 	addi $v0, $0, 4 
 	la $a0, ibc_str
 	syscall 

# user inputs ibc	
 	addi $v0, $0, 5 
 	syscall
 	
# save ibc to $t2 for check 
	add $t2, $0, $v0   
		
#check for ibc <= mbc. If 1-> batt_save; Else 0 -> go to ibc_init
 	ble $t2, $s1, batt_save
 	li $v0, 4
 	la $a0, error_ibc_isgreaterthan_mbc
 	syscall
 	
 	j ibc_init
 	

batt_save:
# save ibc to $s2	
 	add $s2, $0, $v0


# user inputs pdr int 	
 	li $v0, 4 
 	la $a0, pdr_str
 	syscall 

# copy to register $s3 	 	
 	li $v0, 5 
 	syscall 
 	add $s3, $0, $v0
 	
# itialise start [t=0] seconds. Load to $t1: POSSIBLY REDUNDANT
	addi $t1, $zero, 0








# program starts: 

# 3s passed --> [t=3]
	addi $t1, $zero, 3 

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
