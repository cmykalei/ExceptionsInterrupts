# COMPX203 Exercise 4, Question 4
# Programmable timer can be stopped or started by push buttons
# Time elapsed with milliseconds are continously displayed on the SSDs
# Push button 1 prints current time to Serial Port 2 if running

# Constants are from 'Parallel Interface' and 'Programmable Timer'
.equ sertrns,  0x71000              # Serial Transmit Data
.equ serctrl,  0x71002              # Serial Control Register
.equ serstat,  0x71003              # Serial Status Register
.equ serackn,  0x71004              # Serial Acknowledge
.equ parbttn,  0x73001              # Parallel Push Button Register
.equ parctrl,  0x73004              # Parallel Control Register
.equ parackn,  0x73005              # Parallel Acknowledge Register
.equ ulssd,    0x73007              # Upper right SSD
.equ urssd,    0x73007              # Upper right SSD
.equ llssd,    0x73008              # Lower left SSD
.equ lrssd,    0x73009              # Lower right SSD
.equ tmrctrl,  0x72000              # Timer Control Register
.equ tmrload,  0x72001              # Timer Load Register
.equ tmrackn,  0x72003              # Timer Acknowledge Register

.text
# Global main prepares this program for IRQ2 and IRQ3 interrupts
.global main 
main:
        # Setup 'Exception Vector Register'
        movsg $2, $evec             # Get old handler address
        sw    $2, oldvector($0)     # Save back up address
        la    $2, handler           # Load this handler address
        movgs $evec, $2             # Save as current address
       
        # Setup 'CPU Control Register'
        movsg $2, $cctrl            # Get current control value
        andi  $2, $2, 0x000f        # Reset the mask setting
        ori   $2, $2, 0xc2          # Enable IRQ2, IRQ3 and IE
        movgs $cctrl, $2            # Save new control settings

        # Set 'Parallel Control Register'
        lw    $2, parctrl($0)       # Get current control value
        ori   $2, $2, 3             # Enable hex and interrupts
        sw    $2, parctrl($0)       # Save new control settings

        # Set 'Serial Control Register'
        lw    $2, serctrl($0)       # Get current control value
        andi  $2, $2, 0x203         # Enable Interrupts + linespeed?
        sw    $2, serctrl($0)       # Save new control setting

        # Set up 'Timer Control Register'
        lw    $2, tmrctrl($0)
        addi  $2, $0, 3             # Enable auto restart only
        sw    $2, tmrctrl($0)       # Set timer to GO

        # Setup 'Timer Load Register'
        addi  $2, $0, 24            # 2400hz * 0.001s = 24
        sw    $2, tmrload($0)       # Save autorestart at 1s

        # Disable the timer to start with 
        lw    $2, tmrctrl($0)
        andi  $2, $2, 2
        sw    $2, tmrctrl($0)

        lw    $3, endflag($0)
        beqz  $3, seconds

        sw    $0, endflag($0)
        sw    $0, urssd($0)
        sw    $0, llssd($0)
        sw    $0, lrssd($0)
        sw    $0, counter($0)
        jr    $ra

centisecs:             
        lw $1, centiseconds($0)     # Get current centiseconds value
        divi  $2, $1, 10            # Divide by '10' for tens-digit
        sw    $2, llssd($0)         # Write to lower left SSD
        remi  $2, $1, 10            # Modulus by '10' for ones-digit
        sw    $2, lrssd($0)         # Write to lower right SSD 
        remi  $2, $1, 100
        beqz  $2, seconds        
        j centisecs      

# Second loop reads count and displays as total seconds
seconds:
        lw    $1, counter($0)       # Get current counter value
        divi  $2, $1, 10            # Divide by '10' for tens-digit
        sw    $2, llssd($0)         # Write to lower left SSD
        remi  $2, $1, 10            # Modulus by '10' for ones-digit
        sw    $2, lrssd($0)         # Write to lower right SSD 

        lw    $2, endflag($0)       # Check if the user has pushed end
        bnez  $2, main              # If true branch to main to exit

        sgti  $2, $1, 59            # Check if we reached time 0:59
        beqz  $2, centiseconds      # If false loop to display seconds

# Handler checks 'Exception Status Register' to find the cause
handler:
        # Check if interrupt cause is 'Timer Interrupt'
        movsg $13, $estat           # Get current status value 
        andi  $13, $13, 0xffb0      # Mask for IRQ2 interrupt
        beqz  $13, handletimer1     # Branch to handle time

        # Check if interrupt cause is 'Parallel Interrupt'
        movsg $13, $estat           # Get current status value 
        andi  $13, $13, 0xff70      # Mask for IRQ3 interrupt
        beqz  $13, handlepush       # Branch to handle time

        # Check if interrupt cause is 'Serial Port Interrupt'
        movsg $13, $estat           # Get current status value 
        andi  $13, $13, 0xfdf0      # Mask for IRQ5 interrupt
        beqz  $13, handleport      # Branch to handle serial port

        # If neither restore the 'Exception Vector Register'
        lw    $13, oldvector($0)    # Load the old address
        jr $13                      # Jump to default handler 
  
# Handle timer acknowledges 'Timer Interrupt' for IRQ2 then RFE
handletimer1: 
        sw    $0, tmrackn($0)       # Acknowledge the interrupt
        lw    $13, centiseconds($0)      
        remi  $13, $13, 100
        beqz  $13, handletimerb
        addi  $13, $13, 1           # Increment the centiseconds 
        sw    $13, centiseconds($0)   
        rfe                         # Return from this exception

handletimer2:
        sw    $0, tmrackn($0)       # Acknowledge the interrupt
        lw    $13, counter($0)      
        addi  $13, $13, 1           # Increment the seconds count
        sw    $13, counter($0)      # Save update to counterws   
        rfe                         # Return from this exception

# Handle push acknowledges 'Parallel Interface' for IRQ2 then RFE
handlepush: 
        sw    $0, parackn($0)       # Acknowledge the interrupt
        lw    $13, parbttn($0)      # Check if button 0 was pushed
        seqi  $13, $13, 1           # If true branch to handlestart
        bnez  $13, handlestart
        lw    $13, parbttn($0)      # Check if button 1 was pushed
        seqi  $13, $13, 2           # If true branch to handleprint
        bnez  $13, handleprint
        lw    $13, parbttn($0)      # Check if button 2 was pushed
        seqi  $13, $13, 4           # Set flag as result
        sw    $13, endflag($0)
        rfe                         # Return from this exception

# Handle start toggles 'Timer Control Register' enable bit then RFE
handlestart:
        sw    $0, parackn($0)       # Acknowledge the interrupt
        lw    $13, tmrctrl($0)      # Load current control value
        xori  $13, $13, 1           # Flip all the bits to toggle
        ori   $13, $13, 2           # Keep bit '2' enabled
        sw    $13, tmrctrl($0)      # Save new control value
        rfe                         # Return from this exception

# Handle reset checks 'Timer Control Register' enable bit then RFE
handleprint:
        sw    $0, parackn($0)       # Acknowledge the interrupt
        lw    $13, tmrctrl($0)      # Load current control value
        seqi  $13, $13, 3           # Check if timer is enabled
        beqz  $13, reset            # If false branch to reset
        j print                     # Else jump print
        rfe                         # Return from this exception

handleport:
        sw $0, serackn($0)
        rfe

# Reset writes '0' to counter then RFE
reset:
        sw    $0, parackn($0)       # Acknowledge the interrupt
        sw    $0, counter($0)       # Reset counter to '0'
        rfe                         # Return from this exception

print:
        lw    $13, timevalue($0)
        sw    $13, lrssd($0)        
        addi  $13, $13, 1
        lw    $13, timevalue($13)
        sw    $13, lrssd($0)
        addi  $13, $13, 1
        lw    $13, timevalue($13)
        sw    $13, lrssd($0) 
        addi  $13, $13, 1
        lw    $13, timevalue($13)
        sw    $13, lrssd($0) 
        rfe 

# Data stores local variables to use for this program
.data
        oldvector:        
                .word 0             # The back of old exception
        counter:
                .word 0             # The current amount seconds
        centiseconds:
                .word 0
        endflag:
                .word 0             # If flag '1' then terminate program
        printflag:
                .word 0

        timevalue:
                .asciiz "\r"
                .asciiz "\n"
                .word la counter($0)
                .word la centiseconds($0)

# END PROGRAM MAIN