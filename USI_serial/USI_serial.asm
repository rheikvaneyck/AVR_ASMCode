; 
; USI_serial.asm
;
; Created: 06.04.2019 18:00
; Author: mnasa
;
; for ATtiny45/85
; serial com with USI
; 
; CPU = 1MHz
; Baud rate 9600
; Cycles per Bit = CPU/Baud = 104
; Timer0 is used and generates an overflow interrupt, therefore 
; the seed of Timer0 needs to set to 256 - 104 = 152

.nolist
.include "tn45def.inc"
.list

.dseg
msg:
.db "Hallo Welt!", '\n', 0x00

.cseg

.macro ISP
LDI @0, LOW(@1)
OUT SPL, @0
LDI @0, HIGH(@1)
OUT SPH, @0
.endmacro

.org 0x0000
RJMP reset
.org INT_VECTORS_SIZE

reset:
ISP R16, RAMEND

init:
LDI R30,LOW(msg)       ; Lade Z register low 
LDI R31, HIGH(msg)     ; Lade Z register high 
LD Z+, R16
OUT USIDR, R16
LDI R16, (1<<USIOIF)
OUT USISR, R16
LDI R16, (1<<USIWM0)|(1<<USICS1)|(1<<USICLK)|(1<<USITC)

Transfer_loop:
OUT USICR, R16
IN R16, USISR
SBRS R16, USIOIF
RJMP Transfer_loop

main:
RJMP main

