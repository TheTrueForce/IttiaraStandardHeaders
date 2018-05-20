;QueuedIO.asm - Implements transmit and receive buffers for the 65SPI and DUART channel A.
;This was written with much reference to Garth Wilson's section on such buffers, which can
;be found here: http://wilsonminesco.com/6502interrupts/index.html#3.1

;Actual buffer locations
TERM_IN		= $0300
TERM_OUT	= $0400
SPI_IN		= $0500
SPI_OUT		= $0600

;Pointer locations
TERM_IN.RD	=
TERM_IN.WR	=
TERM_OUT.RD	=
TERM_OUT.WR	=
SPI_IN.RD	=
SPI_IN.WR	=
SPI_OUT.RD	=
SPI_OUT.WR	=

;Disturbs: 		Nothing
;Parameters: 	None
;Returns: 		Nothing
;Initialises buffer pointers to zero; as empty.
Buffers.init:
	STZ TERM_OUT.RD
	STZ TERM_OUT.WR		;set up buffer as empty
	RTS

;Disturbs:
;Parameters:	A - the byte to enqueue.
;Returns:		C - if buffer is full before insertion.
;Inserts a character into the terminal output queue. Does not block.
;Returns with carry set if buffer is full, and does not push.
;;check for space, insert, inc ptr. Wr ptr always one ahead.
;;Then enable TxA, if it isn't already.
TERM_OUT.Push:
	PHA					;Save A. Space disturbs A, and we want to preserve it.
	JSR TERM_OUT.Space	;find out how much space is left in the buffer
	BEQ .overflow		;if there is none, return with CS. Else, push the byte.
	PLA					;We need A back now.
	PHX					;Preserve X. There might be something important in there.
	LDX TERM_OUT.WR		;get the write pointer...
	STA TERM_OUT, X		;and use it to push to the buffer
	PLX					;get X back.
	INC TERM_OUT.WR		;increment the write pointer.
	CLC					;no error, so clear carry
	BRA .out
.overflow:
	PLA					;restore A
	SEC					;signal error
.out:
	PHA
	LDA #Tx_ON			;Enable TxA
	STA DUART.CRA
	RTS

TERM_OUT.Pull:

TERM_OUT.Space: