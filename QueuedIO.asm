;QueuedIO.asm - Implements transmit and receive buffers for the 65SPI and DUART channel A.
;This was written with much reference to Garth Wilson's section on such buffers, which can
;be found here: http://wilsonminesco.com/6502interrupts/index.html#3.1

;wr ptr points to the next location to be written.
;If wr ptr == rd ptr-1 then buffer full.
;if wr ptr == rd ptr then buffer empty.

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
	STZ TERM_IN.RD
	STZ TERM_IN.WR
	RTS

;USER ROUTINE
;Disturbs:		None
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

;Disturbs:		A - As return (if successful)
;				C - As return
;Parameters:	None
;Returns:		A - data read
;				C - Error status(set if no data to retrieve)
; Removes and returns an element from the buffer, if present
TERM_OUT.Pull:
	PHX
	LDX TERM_OUT.RD		;Compare the write ptr to the read ptr
	CPX TERM_OUT.WR
	BNE .go				;If equal, queue is empty.
	SEC					;signal error
	BRA .out			;return
.go:
	LDA TERM_OUT, X		;read data
	INC TERM_OUT.RD		;move read ptr up one
	CLC					;signal all's well
.out:
	PLX
	RTS

;Disturbs:		A - As return
;				C
;Parameters:	None
;Returns:		A - number of bytes left. 0 means buffer empty, -1($FF) means buffer full
; Returns free space in the queue.
TERM_OUT.Space:
	LDA TERM_OUT.WR
	SEC
	SBC TERM_OUT.RD
	RTS


;Disturbs:		None
;Parameters:	None
;Returns:		None
;It is assumed that a TxEMT interrupt is known to have occurred from channel A.
;Checks for bytes in the queue. If there are none, the transmitter is disabled.
;Pushes characters into the DUART's output FIFO until it is full,
;or until there are no more characters left to push.
;DIRECTLY POKES HARDWARE
TERM_OUT.ISR:
	PHA
	PHP
	JSR TERM_OUT.Space	;if wr ptr == rd ptr then buffer empty.
	BNE .notEmpty
	LDA #$Tx_OFF		;if empty, shut down the transmitter
	STA  DUART.CRA
	BRA .out
.notEmpty
	JSR  TERM_OUT.Pull
	STA  DUART.FIFOA
	LDA  DUART.SRA
	;If TxFIFO is full, don't push any more.
	AND #TxRDY			;returns zero if TxFIFO full
	BEQ .out			;If TxFIFO is full, leave
	;If TERM_OUT is empty, fall out, else loop.
	JSR TERM_OUT.Space
	BNE .notEmpty
.out
	PLP
	PLA
	RTS

;USER ROUTINE
TERM_IN.Pull:
	;check that there is a byte to pull
	;if not, return with carry set
	SEC
	RTS
	;otherwise, pull the character...
	;...and return with carry clear
	CLC
	RTS
	
;It is assumed there is space to push(check before calling)
TERM_IN.Push:
	PHX
	LDX TERM_IN.WR
	STA TERM_IN, X
	INC TERM_IN.WR
	PLX

TERM_IN.Space:
	LDA TERM_IN.WR
	SEC
	SBC TERM_IN.RD
	RTS