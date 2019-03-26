;
; SleepnWakeup.asm
;
; Created: 23.03.2018 018:00:00
; Author : mnasa
;
.nolist                ; Ausgabe ausschalten
.include "tn85def.inc" ; AVR Header-Datei laden
.list                  ; Ausgabe wieder anschalten
.def rmp = R16         ; ein Namen für ein Arbeitsregister
.cseg                  ; Start des Code-Segments
 
.macro ISP             ; MACRO für die Initialisierung des Stackpointers
LDI @0, LOW(@1)        ; unteres Byte von @1 in Register @0 laden
OUT SPL, @0            ; Register @0 in unteres Byte des Stackpointers
LDI @0, HIGH(@1)       ; oberes Byte von @1 in Register @0 laden
OUT SPH, @0            ; Register @0 in oberes Byte des Stackpointers
.endmacro              ; @0 und @1 sind erster und zweiter Parameter des Macros
 
.org 0x0000            ; Einsprungadresse nach RESET
RJMP START              ; springe zum Label "START"
.org 0x000C            ; Einsprungadresse nach Watchdog timeout
RJMP WDT_ISR

.org INT_VECTORS_SIZE

START:                  ; Einsprung-Label
BRIE WDT_ISR
ISP rmp, RAMEND        ; Initialisiere Stackpoiter mit Macro
LDI rmp, (1<<DDB3)|(1<<DDB4)     ; baue Byte zum Setzen von DDB3 für output
OUT DDRB, rmp          ; Setze DDB3 (Abschnitt 10.2.1 im Datenblatt)
LDI rmp, (1<<PB3)|(0<<PB4)      ; PB3 output HIGH
OUT PORTB, rmp         ; Setze PB3 output auf HIGH (Abschn 10.2.1 im Datenblatt)
;RJMP main

WDT_INIT:
CLI
WDR
LDI R16, (0<<WDRF)
OUT MCUSR, R16
IN R16, WDTCR
ORI R16, (1<<WDCE)|(1<<WDE)
OUT WDTCR, R16
LDI R16, (1<<WDP2)|(1<<WDP0)|(1<<WDIE)
OUT WDTCR, R16
SEI

main:                  ; Label für Hauptprogramm
IN R16, MCUCR
SBR R16, (1<<SE)|(1<<SM1)
CBR R16, (1<<SM0)	   ; SM1:SM0 = 1 0 -> Power down mode 
OUT MCUCR, R16         ; SE Sleep enable
SLEEP                  ; CPU Schlafen legen bis von Interrupt geweckt und
IN R16, MCUCR
CBR R16, (1<<SE)
OUT MCUCR, R16
RJMP main              ; Zurück in den SLEEP MODE

WDT_ISR:
IN R16, WDTCR
ORI R16, (1<<WDIE)
OUT WDTCR, r16
LDI rmp, (1<<PINB3)    ; Baue Byte mit einer 1 an Bit für PINB3
OUT PINB, rmp          ; Schreibe Arbeitsregister ins Register PINB
LDI rmp, (1<<PINB4)    ; Baue Byte mit einer 1 an Bit für PINB3
OUT PINB, rmp          ; Schreibe Arbeitsregister ins Register PINB                       ; Interrupt-Routine ausgeführt wurde
RETI