# COMPX203 Exercise 4, Question 2
# Program counts number of seconds while running until 10 minutes
# Programmable timer generates an exception every second
# The seconds and minutes are continously displayed on the SSDs

# Constants are from 'Parallel Interface' and 'Programmable Timer'
.equ ursd,    0x73007               # Upper right SSD
.equ llsd,    0x73008               # Lower left SSD
.equ lrsd,    0x73009               # Lower right SSD
.equ tmrctrl, 0x72000               # Timer Control Register
.equ tmrload, 0x72001               # Timer Load Register
.equ tmrackn, 0x72003               # Timer Acknowledge Register

.text
# Global main prepares this program for IRQ2 interrupts
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
    ori   $2, $2, 0x41          # Enable IRQ2 and IE
    movgs $cctrl, $2            # Save new control settings

    # Setup 'Timer Load Register'
    addi  $2, $0, 0x960         # 2400hz * 1s = 2400
    sw    $2, tmrload($0)       # Save autorestart at 1s

# Time loop contains loops to count and display seconds and minutes
timeloop:
    # Set up 'Timer Control Register' and restart timer
    sw    $0, counter($0)       # Set counter to '0'
    addi  $2, $0, 3             # Enable auto restart timer
    sw    $2, tmrctrl($0)       # Set timer to GO

# Second loop reads count and displays as total seconds
secondloop:
    lw    $1, counter($0)     # Get current counter value
    divi  $2, $1, 10          # Divide by '10' for tens-digit
    sw    $2, llsd($0)        # Write to lower left SSD
    remi  $2, $1, 10          # Modulus by '10' for ones-digit
    sw    $2, lrsd($0)        # Write to lower right SSD

    sgti  $2, $1, 59          # Check if we reached time 0:59
    beqz  $2, secondloop      # If false loop to display seconds

# Minute loop reads count and displays as total minutes
minuteloop:
    lw    $1, counter($0)     # Get current counter value
    divi  $2, $1, 60          # Divide by '60' for 1 'minute'
    sw    $2, ursd($0)        # Write to upper right SSD
    remi  $2, $1, 60          # Modulus by '60' for 'seconds'
    divi  $2, $2, 10          # Divide by '10' for tens-digit
    sw    $2, llsd($0)        # Write to lower left SSD
    remi  $2, $1, 10          # Modulus by '10' for ones-digit
    sw    $2, lrsd($0)        # Write to lower right SSD

    sgti  $2, $1, 599         # Check if we reached time 9:59
    beqz  $2, minuteloop      # If false loop to display minutes 

    j timeloop                  # Loop to restart timer

# Handler checks 'Exception Status Register' to find the cause
handler:
    # Check if interrupt cause is 'Timer Interrupt'
    movsg $13, $estat           # Get current status value 
    andi  $13, $13, 0xffb0      # Mask for IRQ2 interrupt
    beqz  $13, handletimer      # Branch to handle time

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

# Data stores local variables to use for this program
.data
    oldvector:        
            .word 0             # The back of old exception
    counter:
            .word 0             # The current amount seconds
# END PROGRAM MAIN