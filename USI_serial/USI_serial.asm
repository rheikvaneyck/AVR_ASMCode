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

.cseg

.macro ISP
LDI @0, LOW(@1)
OUT SPL, @0
LDI @0, HIGH(@1)
OUT SPH, @0
.endmacro

.org 0x0000
RJMP reset
.org 0x0005
RJMP TIMER0_ISR
.org 0x0009
RJMP USI_OVF_ISR
.org INT_VECTORS_SIZE

.equ TIMER_SEED = 0x98  ; Timer0 Seed auf 256 - 104 = 152 setzen
.equ USI_SEED_HB1 = 0x0B    ; USI__counter Seed für 1. Half Byte auf 11
.equ USI_SEED_HB2 = 0x0A    ; USI__counter Seed für 1. Half Byte auf 10
msg: .db "Hallo Welt!\n", 0


reset:
ISP R16, RAMEND

init:
;  	
LDI R16, (1<<DDB4)	   ; Lade Port B Data Direction Register Bit für PIN4
OUT DDRB, R16          ; set PB4 as output PIN
LDI R16, (1<<PINB4)    ; Baue Byte mit einer 1 an Bit für PINB4
OUT PINB, R16          ; Schreibe Arbeitsregister in Port B Input Pins Address


main:
; Lade Daten Byte ins USI 
LDI R30,LOW(msg)       ; Lade Z register low 
LDI R31, HIGH(msg)     ; Lade Z register high 
LD R16, Z+
OUT USIDR, R16         ; Lade Byte in das USI Datenregiste

; Stelle UART Pin ein (Pin1)
RCALL config_UART_pin

; Stelle USI Mode, USI OVF INT und Clock Source
RCALL config_usi

; Stelle USI Counter
RCALL config_usi_counter

; Stelle Timer0 auf UART Takt 9600 Baud
RCALL config_usi_timer
SEI


;Transfer_loop:
;OUT USICR, R16
;IN R16, USISR
;SBRS R16, USIOIF
;RJMP Transfer_loop
RCALL sleep_config
SLEEP                  ; set MCU sleep
RJMP main

config_UART_pin:
LDI R16, (1<<DDB1)	   ; Lade Port B Data Direction Register Bit für PIN1 (DO)
OUT DDRB, R16          ; set PB1 as output PIN
LDI R16, (1<<PINB1)    ; Baue Byte mit einer 1 an Bit für PINB1
OUT PINB, R16          ; Schreibe Arbeitsregister in Port B Input Pins Address
RET

config_usi:
; Stelle USI auf 3-Wire mode und Clock source auf Timer0 Overflow
LDI R16, (1<<USIOIF)   ; Setze Counter Overflow Interrupt Flag
OUT USISR, R16         ; 
LDI R16, (1<<USIWM0)|(1<<USICS1)|(1<<USICLK)|(1<<USITC) ; Setze:
                       ; USIWM1:USIWM0 0:1 = 3-Wire mode, 
                       ; USICS1:USICS0:USICLK 1:0:1 = Clock-Source auf Timer/Counter0 Compare Match
                       ; USITC 1 = Toggle Clock Port Pin
OUT USISR, R16                
RET

config_usi_counter:
IN R16, USISR          ; Lade USI Status Register
ANDI R16, 0xF0         ; Lösche unteres Half Byte mit dem USI counter
ORI R16, USI_SEED_HB1  ; Setze USI Counter auf USI_SEED_HB1
OUT USISR, R16         ; Schreibe USI Status Register
RET

config_usi_timer:
IN R16, GTCCR          ; Lade General Timer/Counter Control Register
SBR R16, (1<<PSR0)     ; Setze Prescaler Reset Timer/Counter0
OUT GTCCR, R16         ; 
IN R16, TCCR0A         ; Lese TCCR0A ins Arbeitsregister
CBR R16, (1<<COM0A1)|(1<<COM0A0)|	(1<<COM0B1)|(1<<COM0B0)
OUT TCCR0A, R16	       ; Normal port operation, OC0A/OC0B disconnected.
LDI R16, TIMER_SEED    ; seed Timer0 counter
OUT TCNT0, R16         ;
IN R16, TIMSK          ; Lade Timer Interrupt Mask Register
SBR R16, (1<<TOIE0)    ; Setze Timer0 overflow interrupt enable
OUT TIMSK, R16         ; 
IN R16, TCCR0B         ; Lade Timer/Counter Control Register B
ANDI R16, 0x07         ; Setze die letzen 3 Bit im Arbeitsregister auf 0
SBR R16, (1<<CS02)|(1<<CS00)     ; Setze Bits, um
                       ; den Takt für den Timer einzustellen (Abschn 13.3.1 im Datenblatt)
                       ; der Prescaler ist dann bei CS02:CS01:CS00 0:0:1 => CK/1 = 1us bei 1 MHz CPU
                       ; der Prescaler ist dann bei CS02:CS01:CS00 1:0:1 => CK/1024 = 1ms bei 1 MHz CPU
OUT TCCR0B, R16         ; schreibe Arbeitsregister nach TCCR1
RET

sleep_config:
IN R16, MCUCR          ; Lade Register MCUCR ins Arbeitsregister
CBR R16, (1<<SM1) | (1<<SM0) ; Lösche die Bits für andere SLEEP Modes
                       ; und stelle so SLEEP MODE auf Idle (Abschn 7.5.1 im Datenblatt)
SBR R16, (1<<SE)	   ; enable sleep mode
OUT MCUCR, R16
RET

TIMER0_ISR:
LDI R16, TIMER_SEED    ; seed Timer0 counter
IN R17, TCNT0          ; Lade aktuellen Timerwert 
ADD R16, R17           ; Addiere aktuellen Timerwert zu TIMERSEED,  da bereits ein paar Takte vergangen sind
OUT TCNT0, R16         ; Setze Timerwert
RETI                   ; kehre aus Interrupt zum Programm zurück

USI_OVF_ISR:

RETI
