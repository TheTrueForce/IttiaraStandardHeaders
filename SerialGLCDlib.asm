; Routines for operating the special features of the SparkFun Serial Graphical LCD.

LCD_CtrlCode = $7C
LCD_CmdRVS = $12
LCD_CmdDutyCycle = $02
LCD_CmdXoffs = $18
LCD_CmdYoffs = $19
LCD_CmdPset = $10
LCD_CmdLine = $0C
LCD_CmdCircle = $03
LCD_CmdBox = $0F
LCD_CmdBlkErase = $05

;11 bytes
CLS:
	PHA
	LDA #LCD_CtrlCode
	STA DUART.FIFOA
	STZ DUART.FIFOA
	PLA
	RTS

;13 bytes
RVS_toggle:
	PHA
	LDA #LCD_CtrlCode
	STA DUART.FIFOA
	LDA #LCD_CmdRVS
	STA DUART.FIFOA
	PLA
	RTS

;11 bytes
;Expects the duty cycle(0-100; $00-$63) to be in A.
SetDutyCycle:
	PHX
	LDX #LCD_CtrlCode
	STX DUART.FIFOA
	STA DUART.FIFOA
	PLX
	RTS

;Expects the X offset in A
;16 bytes
SetXOffs:
	PHX
	LDX #LCD_CtrlCode
	STX DUART.FIFOA
	LDX #LCD_CmdXoffs
	STX DUART.FIFOA
	STA DUART.FIFOA
	PLX
	RTS

;Expects the Y offset in A
;16 bytes
SetYOffs:
	PHX
	LDX #LCD_CtrlCode
	STX DUART.FIFOA
	LDX #LCD_CmdYoffs
	STX DUART.FIFOA
	STA DUART.FIFOA
	PLX
	RTS

;Expects Xpos on X and Ypos in Y. Sets pixel if CS, Clears it if CC. Clears Carry.
;25 bytes
Pset:
	PHA
	LDA #LCD_CtrlCode
	STA DUART.FIFOA
	LDA #LCD_CmdPset
	STA DUART.FIFOA
	STX DUART.FIFOA
	STY DUART.FIFOA
	LDA #00
	ROL A
	STA DUART.FIFOA
	PLA
	RTS
	
; Expects x1 in $00,X, x2 in $01,X, y1 in $00,Y, and y2 in $01,Y.
; Sets line if CS, Clears line if CC, Clears Carry.
; 41 bytes
DrawLine:
	PHA
	LDA #LCD_CtrlCode
	STA DUART.FIFOA
	LDA #LCD_CmdLine
	STA DUART.FIFOA
	LDA $00,X
	STA DUART.FIFOA
	LDA $0000,Y
	STA DUART.FIFOA
	LDA $01,X
	STA DUART.FIFOA
	LDA $0001,Y
	STA DUART.FIFOA
	LDA #$00
	ROL A
	STA DUART.FIFOA
	PLA
	RTS

; Expects x1 in $00,X, x2 in $01,X, y1 in $00,Y, and y2 in $01,Y.
; Sets line if CS, Clears line if CC, Clears Carry.
; 41 bytes
DrawBox:
	PHA
	LDA #LCD_CtrlCode
	STA DUART.FIFOA
	LDA #LCD_CmdBox
	STA DUART.FIFOA
	LDA $00,X
	STA DUART.FIFOA
	LDA $0000,Y
	STA DUART.FIFOA
	LDA $01,X
	STA DUART.FIFOA
	LDA $0001,Y
	STA DUART.FIFOA
	LDA #$00
	ROL A
	STA DUART.FIFOA
	PLA
	RTS

; Expects x1 in $00,X, x2 in $01,X, y1 in $00,Y, and y2 in $01,Y.
; 35 bytes
EraseBlock:
	PHA
	LDA #LCD_CtrlCode
	STA DUART.FIFOA
	LDA #LCD_CmdBlkErase
	STA DUART.FIFOA
	LDA $00,X
	STA DUART.FIFOA
	LDA $0000,Y
	STA DUART.FIFOA
	LDA $01,X
	STA DUART.FIFOA
	LDA $0001,Y
	STA DUART.FIFOA
	PLA
	RTS
	
; Expects x in X, y in Y, and radius in A
; Sets line if CS, clears line if CC, and clears carry.
; 24 bytes
DrawCircle:
	PHA					;save radius
	LDA #LCD_CtrlCode
	STA DUART.FIFOA
	LDA #LCD_CmdCircle
	STA DUART.FIFOA
	PLA					;restore radius
	STX DUART.FIFOA		;X coordinate
	STY DUART.FIFOA		;Y coordinate
	STA DUART.FIFOA		;Radius
	RTS