# COMPX203 Exercise 4, Question 3
# Programmable timer can be stopped or started by push buttons
# The seconds and minutes are continously displayed on the SSDs

# Constants are from 'Parallel Interface' and 'Programmable Timer'
.equ parbttn, 0x73001               # Parallel Push Button Register
.equ parctrl, 0x73004               # Parallel Control Register
.equ parackn, 0x73005               # Parallel Acknowledge Register
.equ urssd,    0x73007               # Upper right SSD
.equ llssd,    0x73008               # Lower left SSD
.equ lrssd,    0x73009               # Lower right SSD
.equ tmrctrl, 0x72000               # Timer Control Register
.equ tmrload, 0x72001               # Timer Load Register
.equ tmrackn, 0x72003               # Timer Acknowledge Register

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

        # Set up 'Timer Control Register'
        lw    $2, tmrctrl($0)
        addi  $2, $0, 3             # Enable auto restart only
        sw    $2, tmrctrl($0)       # Set timer to GO

        # Setup 'Timer Load Register'
        addi  $2, $0, 0x960         # 2400hz * 1s = 2400
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

# Second loop reads count and displays as total seconds
seconds:
        lw    $1, counter($0)       # Get current counter value
        divi  $2, $1, 10            # Divide by '10' for tens-digit
        sw    $2, llssd($0)          # Write to lower left SSD
        remi  $2, $1, 10            # Modulus by '10' for ones-digit
        sw    $2, lrssd($0)          # Write to lower right SSD 

        lw    $2, endflag($0)       # Check if the user has pushed end
        bnez  $2, main              # If true branch to main to exit

        sgti  $2, $1, 59            # Check if we reached time 0:59
        beqz  $2, seconds           # If false loop to display seconds

# Minute loop reads count and displays as total minutes
minutes:
        lw    $1, counter($0)     # Get current counter value
        divi  $2, $1, 60          # Divide by '60' for 1 'minute'
        sw    $2, urssd($0)        # Write to upper right SSD
        remi  $2, $1, 60          # Modulus by '60' for 'seconds'
        divi  $2, $2, 10          # Divide by '10' for tens-digit
        sw    $2, llssd($0)        # Write to lower left SSD
        remi  $2, $1, 10          # Modulus by '10' for ones-digit
        sw    $2, lrssd($0)        # Write to lower right SSD

        lw    $2, endflag($0)     # Check if the user has pushed end
        bnez  $2, main            # If true branch to main to exit

        sgti  $2, $1, 599         # Check if we reached time 9:59
        beqz  $2, minutes          # If false loop to display minutes 

        j main                     # Loop to restart timer

# Handler checks 'Exception Status Register' to find the cause
handler:
        # Check if interrupt cause is 'Timer Interrupt'
        movsg $13, $estat           # Get current status value 
        andi  $13, $13, 0xffb0      # Mask for IRQ2 interrupt
        beqz  $13, handletimer      # Branch to handle time

        # Check if interrupt cause is 'Parallel Interrupt'
        movsg $13, $estat           # Get current status value 
        andi  $13, $13, 0xff70      # Mask for IRQ3 interrupt
        beqz  $13, handlepush       # Branch to handle time

        # If neither restore the 'Exception Vector Register'
        lw    $13, oldvector($0)    # Load the old address
        jr $13                      # Jump to default handler 
  
# Handle timer acknowledges 'Timer Interrupt' for IRQ2 then RFE
handletimer: 
        sw    $0, tmrackn($0)       # Acknowledge the interrupt
        lw    $13, counter($0)      
        addi  $13, $13, 1           # Increment the seconds count
        sw    $13, counter($0)      # Save update to the counter   
        rfe                         # Return from this exception

# Handle push acknowledges 'Parallel Interface' for IRQ2 then RFE
handlepush: 
        sw    $0, parackn($0)       # Acknowledge the interrupt

        # Check state of push buttons to determine user's request
        lw    $13, parbttn($0)      # Check if button 0 was pushed
        seqi  $13, $13, 1           # If true branch to handlestart
        bnez  $13, handlestart
        lw    $13, parbttn($0)      # Check if button 1 was pushed
        seqi  $13, $13, 2           # If true branch to handlereset
        bnez  $13, handlereset
        lw    $13, parbttn($0)      # Check if button 2 was pushed
        seqi  $13, $13, 4           # Set flag as result
        sw    $13, endflag($0)
        rfe                         # Return from this exception

# Handle start toggles 'Timer Control Register' enable bit then RFE
handlestart:
        lw    $13, tmrctrl($0)      # Load current control value
        xori  $13, $13, 1           # Flip all the bits to toggle
        ori   $13, $13, 2           # Keep bit '2' enabled
        sw    $13, tmrctrl($0)      # Save new control value
        rfe                         # Return from this exception

# Handle reset checks 'Timer Control Register' enable bit then RFE
handlereset:
        lw    $13, tmrctrl($0)      # Load current control value
        seqi  $13, $13, 3           # Check if timer is enabled
        beqz  $13, reset            # If false branch to reset
        rfe                         # Return from this exception

# Reset writes '0' to counter then RFE
reset:
        sw    $0, counter($0)       # Reset counter to '0'
        rfe                         # Return from this exception

# Data stores local variables to use for this program
.data
        oldvector:        
                .word 0             # The back of old exception
        counter:
                .word 0             # The current amount seconds
        endflag:
                .word 0             # If flag '1' then terminate program
# END PROGRAM MAIN