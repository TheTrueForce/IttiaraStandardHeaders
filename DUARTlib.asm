;DUARTlib.asm - Contains routines and constants to operate the 28L92 DUART.
;Is currently concerned only with serial transmission and reception, but will
;include the other functions as well, if necessary.

;====================== DEFINITIONS START ========================
;Definitions used in the programming of the NXP 28L92 DUART

XTAL_FREQ = 3686400		;3.6864MHz

; Status Registers |
;------------------+

RxRDY   = %00000001		;0 if Rx FIFO empty
RxFULL  = %00000010		;1 if Rx FIFO full
TxRDY   = %00000100		;0 if Tx FIFO full
TxEMT   = %00001000		;0 if Tx FIFO empty
OVERRUN = %00010000		;Signals an Overrun Error (FIFOs overflowed?)
PAR_ERR = %00100000		;Signals a Parity Error   (Parity doesn't match data)
FRM_ERR = %01000000		;Signals a Framing Error  (Wrong number of bits)
RxBRK   = %10000000		;Signals that a Break has been received.


; Interrupt Status/Mask Registers |
;---------------------------------+

;All are 1 if active/enabled
TxA_FILL = %00000001	;TxA FIFO at programmed fill level
RxA_FILL = %00000010	;RxA FIFO at programmed fill level
BBRK_CHG = %00000100	;Break Change on channel A (Break received or
						;transmission resumed)
COUNTRDY = %00001000	;Counter has reached terminal count
TxB_FILL = %00010000	;TxB FIFO at programmed fill level
RxB_FILL = %00100000	;RxB FIFO at programmed fill level
ABRK_CHG = %01000000	;Break Change on channel B
INP_CHNG = %10000000	;Input port change

; Command Registers |
;-------------------+

Rx_ON   = %00000001	;Enable Rx
Rx_OFF  = %00000010	;Disable Rx
Tx_ON   = %00000100	;Enable Tx
Tx_OFF  = %00001000	;Disable Tx

NO_CMD     = $00
MRtoONE    = $10
RST_Rx     = $20
RST_Tx     = $30
RST_ERR    = $40
RST_BRK    = $50
ST_BRK     = $60
END_BRK    = $70
RTS_ON     = $80
RTS_OFF    = $90
TIMOUT_ON  = $A0
MRtoZERO   = $B0
TIMOUT_OFF = $C0
POWER_DOWN = $E0
POWER_UP   = $F0


; Mode Register 0 |
;-----------------+

Rx_WATCH		= %10000000
MR0RxINT_full	= %01000000
MR0RxINT_th_q	= MR0RxINT_full
MR0RxINT_half	= %00000000
MR0RxINT_one	= MR0RxINT_half
TxINT_empt		= %00000000
TxINT_half		= %00010000
TxINT_qrtr		= %00100000
TxINT_one		= %00110000
FIFO16			= %00001000
FIFO8			= %00000000
BAUD_norm		= %00000000
BAUD_ext1		= %00000001
BAUD_ext2		= %00000100


; Mode Register 1 |
;-----------------+

RxRTS			= %10000000
MR1RxINT_full	= %01000000
MR1RxINT_th_q	= %00000000
MR1RxINT_half	= MR1RxINT_full
MR1RxINT_one	= MR1RxINT_th_q
ERR_PER_CHAR	= %00000000
ERR_PER_BLOCK	= %00100000
PARITY_ON		= %00000000
PARITY_FORCED	= %00001000
PARITY_NONE		= %00010000
PARITY_MULTIDROP = %00011000
PARITY_even		= %00000000
PARITY_odd		= %00000100
CHAR_IS_8_bits	= %00000011
CHAR_IS_7_bits	= %00000010
CHAR_IS_6_bits	= %00000001
CHAR_IS_5_bits	= %00000000


; Mode Register 2 |
;-----------------+

CHANNEL_normal	= %00000000
CHANNEL_AutoEcho = %01000000
CHANNEL_LclLoop	= %10000000
CHANNEL_RmtLoop	= %11000000
TxRTS_CTRL		= %00100000
TxCTS_CTRL		= %00010000
STP_BITS_1		= $07
STP_BITS_2		= $0F


; Auxiliary Control Register |
;----------------------------+

BAUD_GRP_1	= %10000000
BAUD_GRP_0	= %00000000
COUNT_IP2	= %00000000
COUNT_TxCA	= %00010000
COUNT_TxCB	= %00100000
COUNT_XTL16	= %00110000
TIMER_IP2	= %01000000
TIMER_IP2_16 = %01010000
TIMER_XTL	= %01100000
TIMER_XTL16	= %01110000

;====================== CODE START ========================

;Configures the 28L92 for 115,200 8N1, no handshake.
;Leaves interrupts disabled.
INIT_DUART:
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
	AND #RxRDY		;Determine whether or not there is a character to receive.
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
	AND #TxRDY			;get the TxRDY bit.
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
	AND #RxRDY		;Determine whether or not there is a character to receive.
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
	AND #TxRDY			;get the TxRDY bit.
	LSR
	LSR
	LSR					;put that bit in the carry. It will provide the return value.
	PLA
	BCC .out
	STA DUART.FIFOB		;send the byte
.out
	RTS
