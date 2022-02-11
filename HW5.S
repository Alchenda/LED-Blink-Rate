## Danny Webb-McClain
## EECE.3170: Microprocessors I
## UMass Lowell
## Homework 5
    
// Including xc.h allows use of SFR names, bit masks, etc.
#include <xc.h>
    
    .data
array:  .int       0x3FFF, 0x7FFE, 0xFFFC, 0x3FFF

    // Interrupt vector setup    
    .globl  __vector_dispatch_11    ## Timer 1 interrupt = vector #11
    .section .vector_11, code, keep
    .align 2
    .set nomips16
    .ent __vector_dispatch_11
__vector_dispatch_11:
    j  isrvector11	    ## Jump to actual ISR code, which is in text section
    nop
    .end __vector_dispatch_11
    .size __vector_dispatch_11, .-__vector_dispatch_11
    
    // Interrupt vector setup    
    .globl  __vector_dispatch_9    ## Port B change notification = vector #9
    .section .vector_9, code, keep
    .align 2
    .set nomips16
    .ent __vector_dispatch_9
__vector_dispatch_9:
    j  isrvector9	    ## Jump to actual ISR code, which is in text section
    nop
    .end __vector_dispatch_9
    .size __vector_dispatch_9, .-__vector_dispatch_9
    
    // Start of text section       
    .text		## Text section contains code
    .set noreorder	## Disable instruction reordering
    .globl main		## Define main label as a global entity
    .ent main		##   and an entry point    

main:
    #li	    s0, 0		    ## mode counter = start mode 0
    la	    s1, array		    ##	s1 = array address
    li	    s2, 4		    ##	i = size of array
    // Configure port A for output
    sw	    zero, TRISA		    ## TRISA = 0  --> all PORTA bits = output
    sw	    zero, ANSELA	    ## ANSELA = 0 --> all PORTA bits digital
    not	    t0, zero		    
    sw	    t0, TRISB		    ## TRISB = 0xFFFFFFFF --> all PORTB bits = input
    sw	    zero, ANSELB	    ## ANSELB = 0 --> all PORTB bits digital  
    sw	    zero, TRISC		    ## TRISC = 0  --> all PORTC bits = output
    sw	    zero, ANSELC	    ## ANSELC = 0 --> all PORTC bits digital
    li	    t0, _PORTA_RA0_MASK	    ## $t0 = 0x00000001    
    sw	    t0, LATASET		    ## Set Port A, bit 0 (turn LED1 on)
    li	    t1, _PORTC_RC9_MASK	    ## t1 = 0x00000200 --> control LED2
    sw	    t1, LATCSET		    ## Set Port C, bit 0 (turn LED2 on)
    
    // Configure Timer 1
    sw	    zero, T1CON		    ## Clear T1CON--disables timer to allow setup
    
    lw	    s3, 0(s1)		    ##	t0 = array[0]
    sw	    s3, PR1		    ##   (4095 cycles)
    
    li	    t2, _IFS0_T1IF_MASK	    ## t2 = bit mask for checking Timer 1 interrupt flag
    
    ## Prescale clock
    li	    t3, 0x00000030	    ## Prescale by factor of 256 (TCKPS = 11)
    sw	    t3, T1CONSET
    
    // Configure interrupts
    lui	    t3, 0x0001			## Want INTCON bit 16 (VS<0>) = 1
					##   so vectors 8 bytes apart
    ori	    t3, t3, _INTCON_MVEC_MASK   ## Enable multivectored interrupt mode
    sw	    t3, INTCON
    
    li	    t3, _IPC2_T1IP_MASK	    ## Set T1 interrupt priority level to 7
    ori	    t3, t3, _IPC2_CNBIP_MASK
    sw	    t3, IPC2		    ## Implicitly sets subpriority level to 0
    
    li	    t3, _IEC0_CNBIE_MASK    ## Enable Port B change 
    or	    t3, t3, t2
    sw	    t3, IEC0		    ## Enable Timer 1 interrupts (uses
				    ##   same bit mask as T1 interrupt flag)

    add	    t3, t4, zero	    ## Set bits in CNEN1B = 1 and CNEN0B = 0
    or	    t3, t3, t6		    ##   corresponding to switch positions
    sw	    t3, CNEN1B		    ##   (t4 = S1 bit mask; t6 = S2 bit mask)
    sw	    zero, CNEN0B	    ## Will detect falling edges on these pins
    
    li	    t3, _CNCONB_ON_MASK		    ## Enables Port B change notification
    ori	    t3, t3, _CNCONB_CNSTYLE_MASK    ## Enables edge detection
    sw	    t3, CNCONB
				    
    ei				    ## Enable interrupts globally
				    
    li	    t3, _T1CON_TON_MASK	    ## Enable Timer 1 by setting "ON" bit in T1CON
    sw	    t3, T1CONSET
    
  
    // Main loop--whole lotta nothing, just waiting for interrupt
mainloop:
    j	    mainloop
    nop
    
endmain:
    sw	    t0, LATACLR		    ## Turn off LED1
    sw	    t1,	LATCCLR		    ## Turn off LED2
    li	    t3, 0
    sw	    t3, IEC0
    
    .end main
    
    // Delay loop for switch debouncing
    .global delay
    .ent delay
delay:
    li	    t7, 0x61A8		    ## Set delay counter to 0x61A8 = 25,000
				    ## Since loop body has 3 instructions,
				    ##   loop takes 25,000 * 3 = 75,000
				    ##   cycles
				    ## Remaining 3 instructions take 3 cycles
				    ##  ~75,000 cycles / 8 MHz clock ~ 0.009375 sec delay
loop:
    addi    t7, t7, -1		    ## Decrement counter
    bne	    t7, zero, loop	    ##  and continue doing that until we hit 0
    nop				    
    jr	    ra
    nop

    .end delay
    
    // different modes
    .global modes
    .ent modes
modes:
    //check counter
    li	    t0, _PORTA_RA0_MASK	    ## $t0 = 0x00000001  
    li	    t1, _PORTC_RC9_MASK	    ## t1 = 0x00000200 --> control LED2
    beqz    s0, start
    nop
    li	    t5, 1
    beq    s0,t5, mode1
    nop
    li	    t5, 2
    beq    s0, t5, mode2
    nop
    
    
start:
    sw	    t0, LATAINV		    ## Flip LED1
    sw	    t1, LATCINV		    ## Flip LED2
    j	    end
    nop
mode1:
    j	    isrvector9
    nop
mode2: ##Reset S0
    li	    s0, 0
    j	    start
    nop
end:
    jr	    ra
    nop

    .end modes
    
    // Handle Timer1 interrupt--clear interrupt flag and toggle LED
    .global isrvector11
    .ent isrvector11
isrvector11:
    li	    t2, _IFS0_T1IF_MASK    
    sw	    t2, IFS0CLR		    ## Clear T1IF in software!
    jal	    modes
    nop

    eret		    ## Return from interrupt
    .end isrvector11
    
    // Handle Port B change interrupt--check switches and toggle appropriate LEDs
    .global isrvector9
    .ent isrvector9
isrvector9:   
    li	    t4, _PORTB_RB7_MASK	    ## t4 = 0x00000080 --> mask for S1
    li	    t6, _PORTB_RB13_MASK    ## t6 = 0x00002000 --> mask for S2
    
    // Check S1
    lw	    t8, CNFB
    and	    t9, t8, t4
    beq	    t9, zero, checkS2	    ## If bit 7 = 0, S1 wasn't pressed
    nop
    // S1 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t4, CNFBCLR		    ## Clear flag for S1
    jal	    delay		    ## Delay to debounce
    nop
    lw	    t2, PORTB		    
    and	    t2, t2, t4		    ## Is button still pressed?
    bne	    t2, zero, checkS2	    ## If not, leave LED alone and check S2
    nop
    li	    t0, _PORTA_RA0_MASK	    ## t0 = 0x00000001 --> control LED1
    li	    t1, _PORTC_RC9_MASK	    ## t1 = 0x00000200 --> control LED2
    sw	    t0, LATACLR		    ## Turn off LED1
    sw	    t1,	LATCCLR		    ## Turn off LED2
    addi    s0, s0, 1		    ## counter++
    j	    endmain
    nop
   
    // Check S2
checkS2:
    and	    t9, t8, t6
    beq	    t9, zero, intdone	    ## If bit 13 = 0, S2 wasn't pressed
    nop
    
    // S2 pressed--clear flag, then debounce and toggle if actually pressed
    sw	    t6, CNFBCLR		    ## Clear flag for S2
    jal	    delay		    ## Delay to debounce
    nop
    lw	    t2, PORTB		    
    and	    t2, t2, t6		    ## Is button still pressed?
    bne	    t2, zero, intdone	    ## If not, leave LED alone and check S2
    nop

    addi    s2, s2, -1		    ##	i--
    addi    s1, s1, 4		    ##	address of array[current]
    lw	    s3, 0(s1)		    ##	t0 = array[0]
    sw	    s3, PR1		    ##   (4095 cycles)
    
intdone:
    li	    t3, _IFS0_CNBIF_MASK    ## Clear Port B change notification flag
    sw	    t3, IFS0CLR		    ##    in IFS0
    eret		    ## Return from interrupt
    .end isrvector9
