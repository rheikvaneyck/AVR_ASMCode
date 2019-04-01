; 
; TimerPin.asm
;
; Created: 31.03.2019 19:53
; Author: mnasa
;

.nolist
.include "tn85def.inc"
.list

.cseg

.macro ISP
LDI @0, LOW(@1)
OUT SPL, @0
LDI @0, HIGH(@1)
OUT SPH, @0
.endmacro

.org 0x0000
RJMP init

.org INT_VECTORS_SIZE
.equ TIMERVAL = 0x40 ; set to 64x0.0164s = 1.0496s

init:
ISP R16, RAMEND
LDI R16, (1<<DDB4)
OUT DDRB, R16        ; set PB4 as output PIN

timer:
LDI R16, (1<<COM1B0) ; set COM1B1:COM1B0 0:1 = Toogle OC1B output line
OUT GTCCR, R16
LDI R16, (1<<CTC1) | (1<<CS13) | (1<<CS12) | (1<<CS11) | (1<<CS10)
OUT TCCR1, R16       ; set CTC1 to reset Timer1 and
                     ; set CS13:CS12:CS11:CS10 to 1:1:1:1 for CPU/16384
                     ; that's 0.0164s bei 1 MHz CPU
LDI R16, TIMERVAL    ;
OUT OCR1B, R16       ; set Output Compate Register B to TIMERVAL
OUT OCR1C, R16       ; set Output Compate Register C to TIMERVAL 
                     ; to reset Timer to 0x00 after match

sleep_config:
IN R16, MCUCR
SBR R16, (1<<SE)	 ; enable sleep mode
OUT MCUCR, R16

main:
SLEEP                ; set MCU sleep
RJMP main
