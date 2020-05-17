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
; Timer0 in compare mode is used and generates an compare interrupt, 
; therefore the compare register of Timer0 needs to set to 104

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

.macro FLIP
LSL @0
ROR @1
LSL @0
ROR @1
LSL @0
ROR @1
LSL @0
ROR @1
LSL @0
ROR @1
LSL @0
ROR @1
LSL @0
ROR @1
LSL @0
ROR @1
MOV @0, @1
.endmacro

.org 0x0000
RJMP reset
.org 0x0001
RJMP INTO_ISR
.org 0x000E
RJMP USI_OVF_ISR
.org 0x000A
RJMP TIM0_COMPA_ISR
.org INT_VECTORS_SIZE

.equ TRX_PIN = PB1
.equ TIMER_SEED = 0x64  ; Timer0 Seed 100 setzen
.equ IDLE = 0x00
.equ TRANSMIT_START = 0x01
.equ TRANSMIT_HEAD = 0x02
.equ TRANSMIT_TAIL = 0x03
.equ TRANSMITTED = 0x04
.equ USI_SEED = 0x0C    ; USI_counter Seed auf 12 (von 15)
msg: .db "Hallo Welt!" , 0 ; Welt!\n", 0

reset:
ISP R16, RAMEND

main:
LDI R25, IDLE			      ; set STATE = IDLE      
RCALL sleep_config      ; prepare SLEEP 
;RCALL set_INT0
LDI R20, 0
RCALL transfer          ; transmit message
;RCALL set_INT0
loop:
SLEEP
RJMP loop

transfer:
IN R16, DDRB	
SBR R16, (1<<TRX_PIN)	  ; Lade Port B Data Direction Register Bit für PIN1
OUT DDRB, R16           ; set PB1 as output PIN
IN R16, PORTB
SBR R16, (1<<TRX_PIN)   ; Baue Byte mit einer 1 an Bit für PORTB1
OUT PORTB, R16          ; Schreibe Arbeitsregister in Port B Input Pins Address
RCALL init_Timer0
wait_for_idle:         ; warte auf IDLE STATE
LDI R16, IDLE
CPSE R25, R16
RJMP wait_for_idle
;RCALL clear_INT0
RCALL load_msg         ; load first byte of mesg from flash memory to R0
msg_loop:
LDI R25, TRANSMIT_START
FLIP R0, R17           ; reverse byte
LSR R0                 ; start bit should be LOW (0)
OUT USIDR, R0          ; Schreibe Byte in das USI Datenregister
RCALL set_Timer0
SEI
prepare_transmit:
LDI R16, IDLE
CPSE R25, R16
RJMP prepare_transmit
LDI R16, (1<<USIOIE)|(1<<USIWM0)|(1<<USICS0)|(1<<USICLK)
					             ; Setze:
                       ; USIWM1:USIWM0 0:1 = 3-Wire mode, 
                       ; USICS1:USICS0:USICLK 0:1:1 = Clock-Source auf Timer/Counter0 Compare Match
OUT USICR, R16         ; set USI config          
RCALL config_usi_counter ; set counter to USI_SEED
LDI R25, TRANSMIT_HEAD
RCALL set_Timer0
SEI
LDI R18, 0x00
wait_for_transmitted:
LDI R16, TRANSMITTED
CPSE R25, R16 
RJMP wait_for_transmitted
;RCALL stop_Timer0 
ADIW ZL, 1
LPM
TST R0
BREQ transfer_end
RJMP msg_loop
transfer_end:
LDI R25, IDLE          ; setze IDLE STATE
RET

debug_led:
IN R16, DDRB
SBR R16, (1<<DDB3)	   ; Lade Port B Data Direction Register Bit für PIN4
OUT DDRB, R16          ; set PB4 as output PIN
LDI R16, (1<<PINB3)    ; Baue Byte mit einer 1 an Bit für PINB4
OUT PINB, R16          ; Schreibe Arbeitsregister in Port B Input Pins Address
RET       

sleep_config:
IN R16, MCUCR          ; Lade Register MCUCR ins Arbeitsregister
CBR R16, (1<<SM1) | (1<<SM0) ; Lösche die Bits für andere SLEEP Modes
                       ; und stelle so SLEEP MODE auf Idle (Abschn 7.5.1 im Datenblatt)
SBR R16, (1<<SE)	     ; enable sleep mode
OUT MCUCR, R16
RET

init_UART: 
IN R16, DDRB	
SBR R16, (1<<TRX_PIN)	  ; Lade Port B Data Direction Register Bit für PIN1
OUT DDRB, R16           ; set PB1 as output PIN
IN R16, PORTB
SBR R16, (1<<TRX_PIN)   ; Baue Byte mit einer 1 an Bit für PORTB1
OUT PORTB, R16          ; Schreibe Arbeitsregister in Port B Input Pins Address
; Stelle USI auf 3-Wire mode und Clock source auf Timer0 Overflow
LDI R16, (1<<USIWM0)|(1<<USICS0)|(1<<USICLK)
					             ; Setze:
                       ; USIWM1:USIWM0 0:1 = 3-Wire mode, 
                       ; USICS1:USICS0:USICLK 0:1:1 = Clock-Source auf Timer/Counter0 Compare Match
OUT USICR, R16          
RET 

config_usi_counter:
IN R16, USISR          ; Lade USI Status Register
ANDI R16, 0xF0         ; Lösche unteres Half Byte mit dem USI counter
ORI R16, USI_SEED      ; Setze USI Counter auf USI_SEED
OUT USISR, R16         ; Schreibe USI Status Register
RET

init_Timer0:           ; konfiguriere Timer0 in Compare Mode
IN R16, GTCCR          ; Lade General Timer/Counter Control Register
SBR R16, (1<<PSR0)     ; Setze Prescaler Reset Timer/Counter0
OUT GTCCR, R16         ; 
IN R16, TCCR0A         ; Lese TCCR0A ins Arbeitsregister
CBR R16, (1<<COM0A1)|(1<<COM0A0)|	(1<<COM0B1)|(1<<COM0B0)
OUT TCCR0A, R16	       ; Normal port operation, OC0A/OC0B disconnected.
LDI R16, (1<<CS00)     ; Setze Bits, um
                       ; (1<<CS02)|(1<<CS00) 
                       ; den Takt für den Timer einzustellen (Abschn 13.3.1 im Datenblatt)
                       ; der Prescaler ist dann bei CS02:CS01:CS00 0:0:1 => CK/1 = 1us bei 1 MHz CPU
                       ; der Prescaler ist dann bei CS02:CS01:CS00 1:0:1 => CK/1024 = 1ms bei 1 MHz CPU
OUT TCCR0B, R16        ; schreibe Arbeitsregister nach TCCR1
RET

set_Timer0:
LDI R16, TIMER_SEED    ; seed Timer0 counter
OUT OCR0A, R16         ; 
IN R16, TIMSK          ; Lade Timer Interrupt Mask Register
SBR R16, (1<<OCIE0A)   ; Setze Timer0 compare A mode interrupt enable
OUT TIMSK, R16         ; 
LDI R16, 0x00
OUT TCNT0, R16		   ; clear counter Timer0
RET

;stop_Timer0:
;IN R16, TIMSK          ; Lade Timer Interrupt Mask Register
;CBR R16, (1<<OCIE0A)   ; Lösche Timer0 compare A mode interrupt enable
;OUT TIMSK, R16         ; 
;LDI R16, 0x00
;OUT TCNT0, R16		   ; clear counter Timer0
;RET

;set_INT0:
;; konfiguriere Interrupt 0 
;IN R16, MCUCR          ; Lade MCU Control Register
;SBR R16, (1<<ISC01)	   ; Interrupt INT0 at falling edge
;OUT MCUCR, R16
;LDI R16, (1<<INT0)     ; INT0 aktivieren
;OUT GIMSK, R16
;SEI
;RET

;clear_INT0:
;IN R16, GIMSK          ; Lösche INT0 Interrupt
;CBR R16, (1<<INT0)     ; INT0 deaktivieren
;OUT GIMSK, R16
;RET

load_msg:
LDI ZL,LOW(2*msg)       ; Lade Z register low 
LDI ZH, HIGH(2*msg)     ; Lade Z register high 
LPM 
RET

INTO_ISR:
RETI

TIM0_COMPA_ISR:
LDI R16, 0x00
OUT TCNT0, R16			   ; reset counter Timer0
CPI R25, TRANSMIT_START
BREQ set_idle
RJMP end_of_t0
set_idle:
LDI R25, IDLE
end_of_t0:
RETI

USI_OVF_ISR:           ; reconfigured while timer0 ticks (be quick!)
IN R16, USISR
SBR R16, (1<<USIOIF)   ; clear USI overflow flag
OUT USISR, R16
CPI R25, TRANSMIT_HEAD
BREQ  transmit_2nd_hb
CPI R25, TRANSMIT_TAIL
BREQ stop_usi
RJMP end_usi_ovf
transmit_2nd_hb:
LDI R25, TRANSMIT_TAIL
SWAP R17               ; shift last nibble 
ORI R17, 0x0F          ; set 4th bit as stop bit (all of low nibble to 1 
OUT USIDR, R17          ; Schreibe Byte in das USI Datenregister
IN R16, USISR          ; Lade USI Status Register
ANDI R16, 0xF0         ; Lösche unteres Half Byte mit dem USI counter
ORI R16, USI_SEED  ; Setze USI Counter auf USI_SEED
OUT USISR, R16         ; Schreibe USI Status Register
RJMP end_usi_ovf
stop_usi:
LDI R16, 0x00
OUT USICR, R16         ; stop USI clock
LDI R25, TRANSMITTED   ; setze TRANSMITTED STATE      
end_usi_ovf:
RETI
