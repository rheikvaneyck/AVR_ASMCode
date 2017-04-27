;
; TimerBlink.asm
;
; Created: 14.04.2017 09:00:00
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
RJMP start             ; springe zum Label "start"
.org OC1Aaddr          ; Einsprung nach Timer/Counter1 Compare Match 1A
RJMP oc1a_ISR          ; Springe zum Label "oc1a_ISR"
 
.org INT_VECTORS_SIZE  ; Hier hören die Interrupt-Einsprungadressen auf
 
.equ TIMERVAL = 0x40   ; Setze Konstante zwischen 0x00 und 0xFF (0x40 = 64 von 256)
 
start:                 ; Einsprung-Label
ISP rmp, RAMEND        ; Initialisiere Stackpoiter mit Macro
LDI rmp, (1<<DDB3)     ; baue Byte zum Setzen von DDB3 für output
OUT DDRB, rmp          ; Setze DDB3 (Abschnitt 10.2.1 im Datenblatt)
LDI rmp, (1<<PB3)      ; PB3 output HIGH
OUT PORTB, rmp         ; Setze PB3 output auf HIGH (Abschn 10.2.1 im Datenblatt)
                       ; Init Timer:
IN rmp, GTCCR          ; Lese Register GTCCR ins Arbeitsregister
CBR rmp, (1<<PWM1B) | (1<<COM1B1) | (1<<COM1B0)  ; Lösche Bits um
                       ; Comparator B von Output Pin OC1B (= PB4) zu trennen
OUT GTCCR, rmp         ; schreibe das Arbeitsregister nach GTCCR (Abschn 12.3.2 im Datenblatt)
IN rmp, PLLCSR         ; Lese Register PLLCSR ins Arbeitsregister
CBR rmp, (1<<PCKE)     ; Lösche Bits für externe Zeitgeber
OUT PLLCSR, rmp        ; schreibe PLLCSR (Abschn 12.3.9 im Datenblatt)
IN rmp, TCCR1          ; Lese TCCR1 ins Arbeitsregister
CBR rmp, (1<<PWM1A) | (1<<COM1A1) | (1<<COM1A0) ; Lösche Bits, um
                       ; Comparator A von Output Pin OC1A (= PB1) zu trennen
SBR rmp, (1<<CTC1)     ; Setze Bit zum Zurücksetzen von Timer/Counter on Compare Match
ANDI rmp, 0xF0         ; Setze die letzen 4 Bit im Arbeitsregister auf 0
SBR rmp, (1<<CS13) | (1<<CS12) | (1<<CS11) | (1<<CS10) ; Setze Bits, um
                       ; den Takt für den Timer einzustellen (Abschn 13.3.1 im Datenblatt)
                       ; der Prescaler is dann CK/16384 = 0.5s bei 8 MHz CPU
OUT TCCR1, rmp         ; schreibe Arbeitsregister nach TCCR1
                       ; Set Timer Interrupt:
LDI rmp, (1<<OCIE1A)   ; baue Byte für Timer/Counter1 Output Compare Interrupt
OUT TIMSK, rmp         ; Schreibe Arbeitsregister nach TIMSK (Abschn13.3.6 im Datenblatt)
LDI rmp, 0x01          ; schreibe 1 ins Arbeitsregister
OUT OCR1A, rmp         ; Setze Timer/Counter1 Compare Register A auf 1
LDI rmp, TIMERVAL      ; Lade TIMERVAL ins Arbeitsregister
OUT OCR1C, rmp         ; Setze Time/Counter1 Compare Register C auf TIMERVAL
SEI                    ; Aktiviere Interrupts
IN rmp, GTCCR          ; Lade Register GTCCR ins Arbeitsregister
CBR rmp, (1<<TSM)      ; Setze Bit für Start von Timer0 (Abschn 11.9.1 im Datenblatt)
OUT GTCCR, rmp         ; schreibe Arbeitsregister nach Register GTCCR
IN rmp, MCUCR          ; Lade Register MCUCR ins Arbeitsregister
CBR rmp, (1<<SM1) | (1<<SM0) ; Lösche die Bits für andere SLEEP Modes
                       ; und stelle so SLEEP MODE auf Idle (Abschn 7.5.1 im Datenblatt)
SBR rmp, (1<<SE)       ; setze Bit fürs Aktiveren des SLEEP MODE
OUT MCUCR, rmp         ; schreibe Arbeitsregister ins Register MCUCR
main:                  ; Label für Hauptprogramm
SLEEP                  ; CPU Schlafen legen bis von Interrupt geweckt und
                       ; Interrupt-Routine ausgeführt wurde
RJMP main              ; Zurück in den SLEEP MODE
oc1a_ISR:              ; Einsprung-Label für OC1A Interrupt
LDI rmp, (1<<PINB3)    ; Baue Byte mit einer 1 an Bit für PINB3
OUT PINB, rmp          ; Schreibe Arbeitsregister ins Register PINB
RETI                   ; kehre aus Interrupt zum Programm zurück
