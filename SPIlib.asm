;Routines for easily controlling the 65SPI and certain SPI peripherals

;SPI configuration:
MASK_MODE	= %11111100

;SPI constants
SPI_TxDone 	= %10000000
SPI_IRQen	= %01000000
SPI_Busy 	= %00100000
SPI_FastRx	= %00010000
SPI_HiZMOSI = %00001000
SPI_ExtClk	= %00000100
SPI_CPOL	= %00000010
SPI_CPHA	= %00000001

SPI.Init:
	LDA #$FF
	STA SPI.SSR		;deassert slave selects
	STZ SPI.CONTROL
	STZ SPI.DIVISOR
	RTS

;Mode number in A. Only the bottom two bits may be set, or crazies may occur.
;Disturbs SCRATCH1 and the N flag
SPI.SetMode:
	STA SCRATCH1	;save the mode for later. We can't use it from a register or the stack, so it must go in memory.
	LDA #MASK_MODE
	AND SPI.CONTROL	;remove the existing mode
	ORA SCRATCH1	;substitute in the new one.
	STA SPI.CONTROL
	RTS

;transmits the byte in A and receives one to A.
SPI.TRxByte:
	STA SPI.DATA	;Shift out the byte
	JSR SPI.WaitTRx
	LDA SPI.DATA	;get the received byte
	RTS

;Transmits byte in A.
SPI.TxByte:
	PHA
	STA SPI.DATA
	JSR SPI.WaitTRx
	PLA
	RTS

SPI.WaitTRx:
	LDA SPI.STATUS
	AND SPI_Busy	;mask out all but the BSY bit.
	BNE SPI.WaitTRx		;if that bit is set, the 65SPI is not ready for another byte.
	RTS
	
	
SPI.SelectSlave:
;Disturbs: SCRATCH1
;Parameters: A - bit number to lower(0-7)
;Returns: Nothing
;Lowers the slave-select line specified in A.
	PHA
	JSR ThreeToEight
	EOR #$FF			;NOT A
	STA SPI.SSR
	PLA
	RTS
	
ThreeToEight:
;Disturbs: SCRATCH1
;		   C
;Parameters: A - bit number to set(0-7)
;Returns: A - decoded bit pattern
;Sets the bit as specified in A
	STA SCRATCH1
	SEC						;I'll need to shift in a one, and the carry is where it comes from
	ASL A					;drop in a one into bit zero, to prevent off-by-one errors
	BBR2 SCRATCH1, .no4		;because SCRATCH1 is in ZP, I can make use of the fact that the W65C02 has these bit-branch instructions.
	ASL A					;If bit 2(4s place) is set, shift the bit over 4 places
	ASL A
	ASL A
	ASL A
.no4
	BBR1 SCRATCH1, .no2		;If bit 1(2s place) is set, shift the bit over 2 places
	ASL A
	ASL A
.no2
	BBR0 SCRATCH1, .no1		;If bit 0(is place) is set, shift the bit over 1 place
	ASL A
.no1
	RTS

;25AAxxx control implementation:

;Constants
AAROM_READ  = $03
AAROM_WRITE = $02
AAROM_WREN  = $06
AAROM_WRDI  = $04
AAROM_RDSR  = $05
AAROM_WRSR  = $01
AAROM_PE    = $42
AAROM_SE    = $D8
AAROM_CE    = $C7
AAROM_RDID  = $AB
AAROM_DPD   = $B9

;Expects:	16-bit EEPROM address      	in SCRATCH1 & SCRATCH2
;		 	16-bit destination address	in SCRATCH3 & SCRATCH4 (low-bytes first)
;		 	# of bytes to read			in Y (not zero-based!, and 0 copies 1B)
;Disturbs:	SCRATCH5, Y, A
;Data is copied to RAM starting at the address specified in SCRATCH3 and 4.
;This routine does not handle the select signal
SPI.AA_READ:
	LDA #AAROM_READ
	JSR SPI.TRxBYTE		;Send Command
	LDA SCRATCH2
	JSR SPI.TRxBYTE		;Send high byte of source address
	LDA SCRATCH1
	JSR SPI.TRxBYTE		;Send low byte of source address
	STY SCRATCH5	;The usual 6502-ism is to start at the count required and
	LDY #$00		;decrement to 0. The 25AAxxx chips start at the given
					;address and increments, so we must do the same.
.LoopTop:
	JSR SPI.TRxBYTE
	STA (SCRATCH3),Y	;Retrieve and store one byte.
	INY
	CPY SCRATCH5	;Have we copied all we need to?
	BMI	.LoopTop	;If zero, we are done, otherwise we need to copy more.
	
	RTS

;Expects:	16-bit EEPROM address      	in SCRATCH1 & SCRATCH2
;		 	16-bit source address		in SCRATCH3 & SCRATCH4 (low-bytes first)
;		 	# of bytes to write			in Y (not zero-based!, and 0 copies 1B)
;Disturbs:	SCRATCH5, Y, A
;Data is copied to RAM starting at the address specified in SCRATCH3 and 4.
;It is assumed that the appropriate select signal has been set, and that
;the write-protect has been disabled.
;Writing across a mod-128 byte boundary is impossible with the 25AA512.
SPI.AA_WRITE:
	LDA #AAROM_WRITE
	JSR SPI.TRxBYTE			;Write command
	LDA SCRATCH2
	JSR SPI.TRxBYTE			;Write Address
	LDA SCRATCH1
	JSR SPI.TRxBYTE
	STX SCRATCH5		;Save Y so we 
	LDX #00
	
.LoopTop
	LDA (SCRATCH3),Y
	JSR SPI.TRxBYTE			;Send one byte
	INY
	CPY SCRATCH5		;If zero, we are done
	BMI .LoopTop
	
	RTS

SPI.AA_WREN:
;Disturbs: None
;Parameters: None
;Returns: Nothing
;Enables writing to the EEPROM. Must be called before any write will stick.
	PHA
	LDA #AAROM_WREN
	JSR SPI.TRxByte
	PLA
	RTS
