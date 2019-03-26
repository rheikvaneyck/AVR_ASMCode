;
; Eeprom.asm
;
; Created: 23.03.2018 018:00:00
; Author : mnasa
;
; Das Programm liest den EEPROM an der Adresse 0x00 (von 0xff) 
; und schaut, ob der Wert COUNT dort steht.
; Die LED and PB3 leuchtet dann, PB4 ist aus (der Wert wurde gelesen)
; Falls nicht, wird der Wert COUNT an diese Adresse geschrieben
; Die LED and PB3 ist dann aus, PB4 leuchtet dann (es wurde geschrieben)
; die FUSE EESAVE sollte aktiviert werden (EEPROM memory is preserved through the Chip Erase)
; avrdude -c pizero -p t45 -P /dev/spidev0.0 -U lfuse:w:0x62:m -U hfuse:w:0xd7:m -U efuse:w:0xff:m

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
RJMP init              ; springe zum Label "init"

.org INT_VECTORS_SIZE
.equ COUNT = 1

init:                  ; Einsprung-Label
ISP rmp, RAMEND        ; Initialisiere Stackpoiter mit Macro
LDI R16, (1<<DDB3)|(1<<DDB4)     ; baue Byte zum Setzen von DDB3 für output
OUT DDRB, R16          ; Setze DDB3 (Abschnitt 10.2.1 im Datenblatt)
RCALL check_count

main:                  ; Label für Hauptprogramm
SLEEP                  ; CPU Schlafen legen bis von Interrupt geweckt und
                       ; Interrupt-Routine ausgeführt wurde
RJMP main              ; Zurück in den SLEEP MODE

check_count:
LDI R19, COUNT
RCALL EEPROM_read
CPSE R16, R19
RCALL EEPROM_write
RET

EEPROM_read:
LDI R16, (1<<PB3)|(0<<PB4)      ; PB3 output HIGH und PB4 output LOW
OUT PORTB, R16         ; Setze PB3 output auf HIGH (Abschn 10.2.1 im Datenblatt)
SBIC EECR, EEPE 	   ;  
RJMP EEPROM_read	   ; Schleife bis aktiver Schreibvorgang fertig
;LDI R18, 0 			   ; EEPROM address High
LDI R17, 0 			   ; EEPROM address Low
;OUT EEARH, R18	   	   ; Adresse (R17:R18) einstellen
OUT EEARL, R17	   	   ; 
SBI EECR, EERE	   	   ; Lesen starten indem EERE gesetzt wird
IN R16, EEDR 		   ; Datenregister lesen
RET

EEPROM_write:
LDI R16, (0<<PB3)|(1<<PB4)      ; PB3 output HIGH und PB4 output LOW
OUT PORTB, R16         ; Setze PB3 output auf HIGH (Abschn 10.2.1 im Datenblatt)
SBIC EECR, EEPE 		   ;  
RJMP EEPROM_write	   ; Schleife bis aktiver Schreibvorgang fertig
LDI R16, (0<<EEPM1)|(0<<EEPM0) ; Progamming Mode setzen (ERASE und WRITE in einer Operation)
OUT EECR, R16
LDI R18, 0 			   ; EEPROM address High
LDI R17, 0 			   ; EEPROM address Low
OUT EEARH, R18	   	   ; Adresse (R17:R18) einstellen
OUT EEARL, R17	   	   ; 
LDI R16, COUNT	   	   ; COUNT als Wert einstellen
OUT EEDR, R16		   ; Datenregister einstellen
SBI EECR, EEMPE  	   ; logische 1 in EEMPE schreiben um Schreibvorgang zu aktivieren 
SBI EECR, EEPE 		   ; Schreiben starten indem EEPE gesetzt wird
RET