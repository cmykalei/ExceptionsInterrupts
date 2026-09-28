# COMPX203 Exercise 4, Question 1
# Program counts each time a parallel button pressed
# Exceptions are generated when button is pressed
# The count is continously displayed on the SSDs

# Constants are from 'Parallel Interface'
.equ parbttn, 0x72001               # Parallel Push Button Register
.equ parctrl, 0x72004               # Parallel Control Register
.equ parackn, 0x72005               # Parallel Acknowledge Register
.equ llsd,    0x73008               # Lower left SSD
.equ lrsd,    0x73009               # Lower right SSD

.text
# Global main prepares program for button push interrupts
.global main 
main:
        # Acknowledge outstanding interrupts and reset count
        sw    $0, parackn($0)       # Parallel Interrupt 
        sw    $0, 0x7f000($0)       # User Interrupt
        sw    $0, counter($0)       # Set push count to '0'

        # Set 'Exception Vector Register'
        movsg $2, $evec             # Get old handler address
        sw    $2, oldvector($0)     # Save back up address
        la    $2, handler           # Load this handler address
        movgs $evec, $2             # Save as current address

        # Set 'CPU Control Register'
        movsg $2, $cctrl            # Get current control value
        andi  $2, $2, 0x000f        # Reset the mask setting
        ori   $2, $2, 0xa2          # Enable IRQ1, IRQ3 and IE
        movgs $cctrl, $2            # Save new control settings

        # Set 'Parallel Control Register'
        lw    $2, parctrl($0)       # Get current control value
        ori   $2, $2, 3             # Enable hex and interrupts
        sw    $2, parctrl($0)       # Save new control settings

# Push loop continuously reads count and displays total pushes
pushloop:      
        lw    $3, counter($0)       # Load current count
        sgti  $2, $3, 99            # Check if we reached 100
        bnez  $2, main              # Branch to restart if so

        divi  $2, $3, 10            # Get the tens-digit
        sw    $2, llsd($0)          # Write to lower left SSD
        remi  $3, $3, 10            # Get the ones-digit              
        sw    $3, lrsd($0)          # Write to lower right SSD
        j pushloop

# Handler checks 'Exception Status Register' to find the cause
handler:
        subui $sp, $sp, 1           # Push stack of '1' for $1
        sw    $1, 0($sp)          
        lw    $1, counter($0)       # Load in current counter

        # Check if interrupt cause is 'User Interrupt Button'
        movsg $13, $estat           # Get current status value 
        andi  $13, $13, 0xffd0      # Mask for IRQ1 interrupt
        beqz  $13, handleuser       # Branch to handle user
     
        # Check if interrupt cause is 'Parallel Interrupt'
        movsg $13, $estat           # Get current status value 
        andi  $13, $13, 0xff70      # Mask for IRQ3 interrupt
        beqz  $13, handlepush       # Branch to handle push

        lw    $1, 0($sp)          
        addui $sp, $sp, 1           # Restore stack

        # If neither restore the 'Exception Vector Register'
        lw    $13, oldvector($0)    # Load the old address
        jr    $13                   # Jump to default handler 
  
# Handle user acknowledges 'User Interrupt Button' then RFE
handleuser: 
        sw    $0, 0x7f000($0)       # Acknowledge the interrupt

        addi  $1, $1, 1             # Add '1' to count the push
        sw    $1, counter($0)       # Save result in counter
        lw    $1, 0($sp)            # Restore the stack
        addui $sp, $sp, 1         
        rfe                         # Return from this exception

# Handle push acknowledges 'Parallel Interrupt' then RFE
handlepush:
        sw    $0, 0x73005($0)       # Acknowledge the interrupt

        lw    $13, 0x73001($0)      # Check state of push buttons 
        sgti  $13, $13, 0           # Set to '1' if pushed
        add   $1, $1, $13           # Add '1' to count if pushed
        sw    $1, counter($0)       # Save result in counter
        lw    $1, 0($sp)            # Restore stack
        addui $sp, $sp, 1
        rfe                         # Return from this exception

# Data stores local variables to use for this program
.data
        oldvector:        
                .word 0             # The back of old exception
        counter:
                .word 0             # The current pushed total
# END PROGRAM MAIN
