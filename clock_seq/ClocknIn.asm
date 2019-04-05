; 
; ClocknIn.asm
;
; Created: 03.04.2019 21:33
; Author: mnasa
;
; for ATtiny45/85
; clocking a sequence to PB4

.nolist
.include "tn45def.inc"
.list

.def rmp = R16         ; ein Namen für ein Arbeitsregister
.dseg 
idle_time:  .byte 1 ; reserve 1 byte to start_time
init_time:  .byte 1 ; reserve 1 byte to init_time
start_time:  .byte 1 ; reserve 1 byte to start_time
; SRAM left: 253 Byte
.cseg

.macro ISP
LDI @0, LOW(@1)
OUT SPL, @0
LDI @0, HIGH(@1)
OUT SPH, @0
.endmacro

.org 0x0000
RJMP init
.org OC1Aaddr          ; Einsprung nach Timer/Counter1 Compare Match 1A
RJMP OC1A_ISR          ; Springe zum Label "oc1a_ISR"
.org INT_VECTORS_SIZE

.equ IDLELEN = 0x64 ; set to 100 x 1us = 100us
.equ INITLEN = 0x46 ; set to 70 x 0.256ms = 18ms
.equ STARTLEN = 0x50 ; set to 80 x 1us = 80ms

init:
ISP R16, RAMEND
LDI R16, (1<<DDB4)
OUT DDRB, R16          ; set PB4 as output PIN
LDI rmp, (1<<PINB4)    ; Baue Byte mit einer 1 an Bit für PINB4
OUT PINB, rmp          ; Schreibe Arbeitsregister ins Register PINB
IN rmp, GTCCR
CBR rmp, (1<<PWM1B) | (1<<COM1B1) | (1<<COM1B0)  ; Lösche Bits um
                       ; Comparator B von Output Pin OC1B (= PB4) zu trennen
OUT GTCCR, rmp         ; schreibe das Arbeitsregister nach GTCCR (Abschn 12.3.2 im Datenblatt)
IN rmp, PLLCSR         ; Lese Register PLLCSR ins Arbeitsregister
CBR rmp, (1<<PCKE)     ; Lösche Bits für externe Zeitgeber
OUT PLLCSR, rmp        ; schreibe PLLCSR (Abschn 12.3.9 im Datenblatt)
IN rmp, TCCR1          ; Lese TCCR1 ins Arbeitsregister
CBR rmp, (1<<PWM1A) | (1<<COM1A1) | (1<<COM1A0) ; Lösche Bits, um
                       ; Comparator A von Output Pin OC1A (= PB1) zu trennen
OUT TCCR1, rmp         ; schreibe Arbeitsregister nach TCCR1

;allocate_idle_time:
LDI R16, IDLELEN       ; Lade IDLELEN to R1
LDI R30,LOW(idle_time)  ; Lade Z register low 
LDI R31, HIGH(idle_time) ; Lade Z register high 
ST Z, R16               ; Speichere IDLETLEN in  timerval

;allocate_init_time:
LDI R16, INITLEN       ; Lade INITLEN to R1
LDI R30,LOW(init_time)  ; Lade Z register low 
LDI R31, HIGH(init_time) ; Lade Z register high 
ST Z, R16               ; Speichere INITLEN in  timerval

;allocate_start_time:
LDI R16, STARTLEN       ; Lade STARTLEN to R1
LDI R30,LOW(start_time)  ; Lade Z register low 
LDI R31, HIGH(start_time) ; Lade Z register high 
ST Z, R16               ; Speichere STARTLEN in  timerval


main:
; IDLE
RCALL config_us_timer
LDI R30,LOW(idle_time)  ; Lade Z register low 
LDI R31, HIGH(idle_time) ; Lade Z register high 
RCALL setup_timer
RCALL sleep_config
SLEEP  					; set MCU sleep
; INIT                
RCALL config_ms_timer
LDI R30,LOW(init_time)  ; Lade Z register low 
LDI R31, HIGH(init_time) ; Lade Z register high 
RCALL setup_timer
RCALL sleep_config
SLEEP                  ; set MCU sleep
; START
RCALL config_us_timer
LDI R30,LOW(start_time)  ; Lade Z register low 
LDI R31, HIGH(start_time) ; Lade Z register high 
RCALL setup_timer
RCALL sleep_config
SLEEP                  ; set MCU sleep
; READ
; CODE HERE FOR READ
; CYCLE
RCALL config_max_timer
LDI R30,LOW(init_time)  ; Lade Z register low 
LDI R31, HIGH(init_time) ; Lade Z register high 
RCALL setup_timer
RCALL sleep_config
SLEEP                  ; set MCU sleep
RJMP main

config_ms_timer:
IN rmp, TCCR1          ; Lese TCCR1 ins Arbeitsregister
SBR rmp, (1<<CTC1)     ; Setze Bit zum Zurücksetzen von Timer/Counter on Compare Match
ANDI rmp, 0xF0         ; Setze die letzen 4 Bit im Arbeitsregister auf 0
SBR rmp, (1<<CS13) | (1<<CS10) ; Setze Bits, um
                       ; den Takt für den Timer einzustellen (Abschn 13.3.1 im Datenblatt)
                       ; der Prescaler is dann CK/256 = 0.256ms bei 1 MHz CPU
OUT TCCR1, rmp         ; schreibe Arbeitsregister nach TCCR1
RET

config_us_timer:
IN rmp, TCCR1          ; Lese TCCR1 ins Arbeitsregister
SBR rmp, (1<<CTC1)     ; Setze Bit zum Zurücksetzen von Timer/Counter on Compare Match
ANDI rmp, 0xF0         ; Setze die letzen 4 Bit im Arbeitsregister auf 0
SBR rmp, (1<<CS10)     ; Setze Bits, um
                       ; den Takt für den Timer einzustellen (Abschn 13.3.1 im Datenblatt)
                       ; der Prescaler is dann CK/1 = 1us bei 1 MHz CPU
OUT TCCR1, rmp         ; schreibe Arbeitsregister nach TCCR1
RET

config_max_timer:
IN rmp, TCCR1          ; Lese TCCR1 ins Arbeitsregister
SBR rmp, (1<<CTC1)     ; Setze Bit zum Zurücksetzen von Timer/Counter on Compare Match
ANDI rmp, 0xF0         ; Setze die letzen 4 Bit im Arbeitsregister auf 0
SBR rmp, (1<<CS13) | (1<<CS12) | (1<<CS11) | (1<<CS10) ; Setze Bits, um
                       ; den Takt für den Timer einzustellen (Abschn 13.3.1 im Datenblatt)
                       ; der Prescaler is dann CK/256 = 0.256ms bei 1 MHz CPU
OUT TCCR1, rmp         ; schreibe Arbeitsregister nach TCCR1
RET


setup_timer:
LDI rmp, (1<<OCIE1A)   ; baue Byte für Timer/Counter1 Output Compare Interrupt
OUT TIMSK, rmp         ; Schreibe Arbeitsregister nach TIMSK (Abschn13.3.6 im Datenblatt)
LD R1, Z               ; Lade timerval ins register 1
MOV rmp, R1            ; Lade TIMERVAL ins Arbeitsregister
OUT OCR1A, rmp         ; Setze Timer/Counter1 Compare Register A auf TIMERVAL
OUT OCR1C, rmp         ; Setze Timer/Counter1 Compare Register C auf TIMERVAL
SEI                    ; Aktiviere Interrupts
IN rmp, GTCCR          ; Lade Register GTCCR ins Arbeitsregister
CBR rmp, (1<<TSM)      ; Setze Bit für Start von Timer0 (Abschn 11.9.1 im Datenblatt)
OUT GTCCR, rmp         ; schreibe Arbeitsregister nach Register GTCCR
RET

sleep_config:
IN rmp, MCUCR          ; Lade Register MCUCR ins Arbeitsregister
CBR rmp, (1<<SM1) | (1<<SM0) ; Lösche die Bits für andere SLEEP Modes
                       ; und stelle so SLEEP MODE auf Idle (Abschn 7.5.1 im Datenblatt)
SBR rmp, (1<<SE)	   ; enable sleep mode
OUT MCUCR, rmp
RET

OC1A_ISR:              ; Einsprung-Label für OC1A Interrupt
CLI
LDI rmp, (1<<PINB4)    ; Baue Byte mit einer 1 an Bit für PINB4
OUT PINB, rmp          ; Schreibe Arbeitsregister ins Register PINB
RETI                   ; kehre aus Interrupt zum Programm zurück

