;DUARTlib.asm - Contains routines and constants to operate the 28L92 DUART.
;Is currently concerned only with serial transmission and reception, but will
;include the other functions as well, if necessary.

;====================== DEFINITIONS START ========================
;Definitions used in the programming of the NXP 28L92 DUART

DUART_XtalFreq = 3686400		;3.6864MHz

; Status Registers |
;------------------+

DUART_RxRDY			= %00000001		;0 if Rx FIFO empty
DUART_RxFull		= %00000010		;1 if Rx FIFO full
DUART_TxRDY			= %00000100		;0 if Tx FIFO full
DUART_TxEmpty		= %00001000		;0 if Tx FIFO empty
DUART_Overrun		= %00010000		;Signals an Overrun Error (FIFOs overflowed?)
DUART_ParityError	= %00100000		;Signals a Parity Error   (Parity doesn't match data)
DUART_FramingError	= %01000000		;Signals a Framing Error  (Wrong number of bits)
DUART_ReceivedBreak	= %10000000		;Signals that a Break has been received.


; Interrupt Status/Mask Registers |
;---------------------------------+

;All are 1 if active/enabled
DUART_TxAFill		= %00000001	;TxA FIFO at programmed fill level
DUART_RxAFill		= %00000010	;RxA FIFO at programmed fill level
DUART_BreakChangeA	= %00000100	;Break Change on channel A (Break received or
								;transmission resumed)
DUART_CountReady	= %00001000	;Counter has reached terminal count
DUART_TxBFill		= %00010000	;TxB FIFO at programmed fill level
DUART_RxBFill		= %00100000	;RxB FIFO at programmed fill level
DUART_BreakChangeB	= %01000000	;Break Change on channel B
DUART_InPortChange	= %10000000	;Input port change

; Command Registers |
;-------------------+

DUART_RxOn   = %00000001	;Enable Rx
DUART_RxOff  = %00000010	;Disable Rx
DUART_TxOn   = %00000100	;Enable Tx
DUART_TxOff  = %00001000	;Disable Tx

DUART_NOP			= $00
DUART_MRtoOne		= $10
DUART_ResetRx		= $20
DUART_ResetTx		= $30
DUART_ResetError	= $40
DUART_ResetBreak	= $50
DUART_SetBreak		= $60
DUART_EndBreak		= $70
DUART_RTS_On		= $80
DUART_RTS_Off		= $90
DUART_TimeoutOn		= $A0
DUART_MRtoZero		= $B0
DUART_TimeoutOff	= $C0
DUART_PowerDown		= $E0
DUART_Power_Up		= $F0


; Mode Register 0 |
;-----------------+

DUART_RxWatchdog	= %10000000
DUART_MR0RxIRQ_Full	= %01000000
DUART_MR0RxIRQ_Th_Q	= DUART_MR0RxIRQ_Full
DUART_MR0RxIRQ_Half	= %00000000
DUART_MR0RxIRQ_One	= DUART_MR0RxIRQ_Half
DUART_TxIRQ_Empty	= %00000000
DUART_TxIRQ_Half	= %00010000
DUART_TxIRQ_Quarter	= %00100000
DUART_TxIRQ_One		= %00110000
DUART_FIFO16		= %00001000
DUART_FIFO8			= %00000000
DUART_BaudNorm		= %00000000
DUART_BaudExt1		= %00000001
DUART_BaudExt2		= %00000100


; Mode Register 1 |
;-----------------+

DUART_RxRTS				= %10000000
DUART_MR1RxIRQ_Full		= %01000000
DUART_MR1RxIRQ_Th_Q		= %00000000
DUART_MR1RxIRQ_Half		= DUART_MR1RxIRQ_Full
DUART_MR1RxIRQ_One		= DUART_MR1RxIRQ_Th_Q
DUART_ErrorPerChar		= %00000000
DUART_ErrorPerBlock		= %00100000
DUART_ParityOn			= %00000000
DUART_ParityForced		= %00001000
DUART_NoParity			= %00010000
DUART_ParityMultidrop	= %00011000
DUART_EvenParity		= %00000000
DUART_OddParity			= %00000100
DUART_8bitsPerChar		= %00000011
DUART_7bitsPerChar		= %00000010
DUART_6bitsPerChar		= %00000001
DUART_5bitsPerChar		= %00000000


; Mode Register 2 |
;-----------------+

DUART_ChMode_Normal		= %00000000
DUART_ChMode_AutoEcho	= %01000000
DUART_ChMode_LocalLoop	= %10000000
DUART_ChMode_RemoteLoop	= %11000000
DUART_TxRTSControl		= %00100000
DUART_TxCTSControl		= %00010000
DUART_OneStopBit		= $07
DUART_TwoStopBits		= $0F


; Auxiliary Control Register |
;----------------------------+

DUART_BaudrateGroup1	= %10000000
DUART_BaudrateGroup2	= %00000000
DUART_CountIP2			= %00000000
DUART_CountTxCA			= %00010000
DUART_CountTxCB			= %00100000
DUART_CountXTL16		= %00110000
DUART_TimerIP2			= %01000000
DUART_TimerIP2_16 		= %01010000
DUART_TimerXTL			= %01100000
DUART_TimerXTL16		= %01110000

;====================== CODE START ========================

;Configures the 28L92 for 115,200 8N1, no handshake.
;Leaves interrupts disabled.
DUART.Init:
	STZ  DUART.IMR		;Disable IRQs
	LDA #$BA
	STA  DUART.CRA		;Disable Tx & Rx; MRA -> MR0
	STA  DUART.CRB
	LDA #$66
	STA  DUART.CSRA		; - Select 115,200 baud
	STA  DUART.CSRB
	LDA #%01001100		;MRA0
	STA  DUART.MRA
	LDA #%01001000		;MRB0 - Bits 2 & 0 are also reserved in Ch B
	STA  DUART.MRB
	LDA #%01010011		;MRA1 & MRB1
	STA  DUART.MRA
	STA  DUART.MRB
	LDA #%00000111		;MRA2 & MRB2
	STA  DUART.MRA
	STA  DUART.MRB
	LDA #%00110000
	STA  DUART.ACR
	LDA #$05			;enable Tx & Rx
	STA  DUART.CRA
	STA  DUART.CRB
	RTS
	
DUART.INA:
;Disturbs: A - if byte recieved
;Parameters: None
;Returns: A - if byte received, it goes in here.
;		  C - set if byte received, clear if not
;Gets a byte from serial port A, if present.
	PHA
	LDA DUART.SRA
	AND #DUART_RxRDY		;Determine whether or not there is a character to receive.
	LSR
	PLA
	BCC .out
	LDA DUART.FIFOA
.out
	RTS
	
DUART.OUTA:
;Disturbs: C - as return
;Parameters: A - Byte to send
;Returns: C - Clear if not sent, set if byte sent.
;Pushes a byte out serial port A, if it can be done. If it cannot be sent, then returns with carry clear.
	PHA					;get A out of the way, so we can use it.
	LDA DUART.SRA
	AND #DUART_TxRDY			;get the TxRDY bit.
	LSR
	LSR
	LSR					;put that bit in the carry. It will provide the return value.
	PLA
	BCC .out
	STA DUART.FIFOA		;send the byte
.out
	RTS
	
DUART.INB:
;Disturbs: A - if byte recieved
;Parameters: None
;Returns: A - if byte received, it goes in here.
;		  C - set if byte received, clear if not
;Gets a byte from serial port B, if present.
	PHA
	LDA DUART.SRB
	AND #DUART_RxRDY		;Determine whether or not there is a character to receive.
	LSR
	PLA
	BCC .out
	LDA DUART.FIFOB
.out
	RTS
	
DUART.OUTB:
;Disturbs: C - as return
;Parameters: A - Byte to send
;Returns: C - Clear if not sent("error" condition), set if byte sent.
;Pushes a byte out serial portB, if it can be done. If it cannot be sent, then returns with carry clear.
	PHA					;get A out of the way, so we can use it.
	LDA DUART.SRB
	AND #DUART_TxRDY			;get the TxRDY bit.
	LSR
	LSR
	LSR					;put that bit in the carry. It will provide the return value.
	PLA
	BCC .out
	STA DUART.FIFOB		;send the byte
.out
	RTS
