;Memory.asi - Memory manipulation routines

;Copies a block of memory 
;Disturbs A and Y
;Expects the source start address in $00 and $01, the destination start address in $02 and $03, and the offset to the end byte in Y
MEMCPY:
	LDA ($00),Y
	STA ($02),Y
	DEY
	BMI MEMCPY
	RTS

;Copies a block of memory to ROM. This cannot run from the ROM, as it goes
;unresponsive after every write operation.
;Disturbs A and Y
;NOP delay set up for 1MHz clock frequency. Arguments as for MEMCPY.
ROMCPY:
	LDA ($00),Y
	STA ($02),Y
	NOP
	NOP
	NOP
	NOP
	NOP
	DEY
	BMI CPY2ROM
	RTS
ROMCPYEND:

;Copies ROMCPY to $04, and runs it with the arguments given
;Disturbs A, Y, and the zero-page locations from $04 to $11
;Arguments as for MEMCPY
ZP_ROMCPY = $04
CPY2ROM:
	LDA $00			;Push the arguments to the stack
	PHA
	LDA $01
	PHA
	LDA $02
	PHA
	LDA $03
	PHA
	PHY
	
	LDA #ROMCPY		;Insert arguments to copy ROMCPY to RAM
	STA  $00
	LDA /ROMCPY
	STA  $01
	LDA #ZP_ROMCPY
	STA  $02
	STZ  $03
	LDY #ROMCPYEND-ROMCPY
	JSR MEMCPY
	
	PLY				;Restore the original arguments
	PLA
	STA $03
	PLA
	STA $02
	PLA
	STA $01
	PLA
	STA $00
	
	JSR ZP_ROMCPY	;Run the ZP routine and return
	RTS