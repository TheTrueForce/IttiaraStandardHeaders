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
	BPL SPI.WaitTRx		;TC is bit 7 - if set, shift complete.
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
	
	;TODO: This routine produces incorrect results.
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

AAROM_StagingArea = $7E00	;This is where the AAROM driver puts and gets its data from.

;Disturbs: None
;Parameters: A 	Slave Mask
;			 X	Page address
;Returns: Nothing
;Reads the given page into the SPI storage Staging Area($7E00 - $7EFF).
;Handles chip select signal.
SPI.AA_Read:
	PHA
	PHX
	
	STA  SPI.SSR	;Select SPI-10 #1
	
	LDA #AAROM_Read
	JSR  SPI.TxByte	;Read command
	;PLA
	;PHA
	TXA
	JSR  SPI.TxByte	;Page number
	LDA #$00
	JSR  SPI.TxByte	;Low byte == 0
	
	LDX #$00
.loop
	JSR  SPI.TRxByte
	STA  AAROM_StagingArea, X
	INX
	BNE .loop
	
	LDA #$FF
	STA  SPI.SSR	;Deselect all SPI devices.
	
	PLX
	PLA
	RTS

;Disturbs: None
;Parameters: A 	Slave Mask
;			 X	Page address
;Returns: Nothing
;Writes the 256 bytes in the SPI storage Staging Area($7E00 - $7EFF).
;Handles chip select signal and write-enable.

SPI.AA_Write:
	PHA
	PHX
	
	STA  SPI.SSR				;Select the SPI device
	PHA							;Also stack it; we'll need it again.
	JSR SPI.AA_WREN				;Enable writing
	LDA #$FF
	STA  SPI.SSR				;deselect
	PLA
	PHA
	STA  SPI.SSR				;select again
	
	LDA #AAROM_WRITE
	JSR  SPI.TxByte				;Send write command
	TXA
	JSR  SPI.TxByte				;Send page address
	LDA #$00
	JSR  SPI.TxByte				;Send zero(low EEPROM page)
	
	LDX #$00
.lowerLoop
	 LDA  AAROM_StagingArea, X
	 JSR  SPI.TxByte				;send a byte
	 INX
	 CPX #$80
	BNE .lowerLoop				;If we reach byte $80(copied up to $7F), this loop is complete.
	
	LDA #$FF
	STA  SPI.SSR				;deselect everything
	
	;Polling the eeprom's status register is the proper way to do it, but it will be far simpler to simply wait for 5 ms, which is the maximum time a page write takes.
	JSR  Delay_5ms
	
	;Now write the next half.
	
	PLA							;retrieve the select pattern
	PHA
	STA  SPI.SSR				;Select the EEPROM
	JSR SPI.AA_WREN				;enable writing again(The write operation before disabled it)
	LDA #$FF
	STA  SPI.SSR
	
	PLA							;select the EEPROM one last time(it won't be needed again)
	STA  SPI.SSR				
	LDA #AAROM_WRITE
	JSR  SPI.TxByte				;Send write command
	PLA							;Get the original contents of X(page address) into A
	PHA
	JSR  SPI.TxByte				;Send page address
	LDA #$80
	JSR  SPI.TxByte				;Send $80(high EEPROM page)
	
	LDX #$80
.upperLoop
	 LDA  AAROM_StagingArea, X
	 JSR  SPI.TxByte				;send a byte
	 INX
	BNE .upperLoop				;If we reach byte $100(copied up to $FF), this loop is complete.
	
.end
	LDA #$FF
	STA  SPI.SSR
	
	;Wait 5ms for write to complete
	JSR  Delay_5ms
	
	PLX
	PLA
	RTS


;Calculated for a 1MHz clock frequency. Uses 5001 cycles
;Any routine of this form will take (2y + 3(y-1) + 4)x + 2x + 2(x-1) + 4 + 12 + 12.
;The constant fours are the last BNE(where the branch is not taken) and the decrement operation.
;The constant twelves are the JSR/RTS used to enter the routine, and the stack operations at the beginning and end.
Delay_5ms:
	PHX				;3 cycles
	PHY				;3 cycles
	
	;Outer loop uses 4977 cycles. The remaining 24 is in the JSR/RTS and stack ops
	LDX #$05		;2 cycles
.outerLoop

		;comes to 991 cycles, which is just under 1ms, but there is other overhead that will pick up the difference.
		LDY #198		;2 cycles		; - decimal 198
.innerLoop								;4 + 2y + 3(y-1) cycles
		DEY				;2y cycles		;
		BNE .innerLoop	;3y-1 + 2 cycles; - 3y for branches taken, 2 for exit.
	
	DEX				;2x cycles
	BNE .outerLoop	;2x-1 + 2 cycles
	
	PLY				;3 cycles
	PLX				;3 cycles
	RTS

SPI.AA_WREN:
;Disturbs: None
;Parameters: None
;Returns: Nothing
;Enables writing to the EEPROM. Must be called before any write will stick.
	PHA
	LDA #AAROM_WREN
	JSR SPI.TxByte
	PLA
	RTS
