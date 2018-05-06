;MemoryMap.asm - Describes the special memory locations available on Ittiara v3.1

;Overall memory map; Base addresses of hardware
RAM		= $0000
DUART	= $7FD0
VIA		= $7FE0
SPI		= $7FF0
ROM		= $8000

VECTORS	= $FFFA

;DUART registers
DUART.MRA		= DUART
DUART.SRA		= DUART+1
DUART.CSRA		= DUART+1
DUART.CRA		= DUART+2
DUART.FIFOA		= DUART+3
DUART.IPCR		= DUART+4	;input port change register
DUART.ACR		= DUART+4
DUART.ISR		= DUART+5	;Interrupt status register
DUART.IMR		= DUART+5	;Interrupt mask register
DUART.CTU		= DUART+6	;counter/timer upper
DUART.CTPU		= DUART+6	;counter/timer preset upper
DUART.CTL		= DUART+7	;counter/timer lower
DUART.CTPL		= DUART+7	;counter/timer preset lower
DUART.MRB		= DUART+8
DUART.CSRB		= DUART+9
DUART.SRB		= DUART+9
DUART.CRB		= DUART+$A
DUART.FIFOB		= DUART+$B
DUART.MISC		= DUART+$C
DUART.IPR		= DUART+$D	;input port register
DUART.OPCR		= DUART+$D	;output port config register
DUART.SOPR		= DUART+$E	;set output bits command(write only)
DUART.START_CT	= DUART+$E	;start counter/timer command(triggers on read)
DUART.ROPR		= DUART+$F	;reset output bits (write only)
DUART.STOP_CT	= DUART+$F	;stop counter/timer command(triggers on read)

;VIA registers
VIA			= $6000
VIA.IORB	= VIA
VIA.IORA	= VIA+1
VIA.DDRB	= VIA+2
VIA.DDRA	= VIA+3
VIA.T1C_L	= VIA+4
VIA.T1C_H	= VIA+5
VIA.T1L_L	= VIA+6
VIA.T1L_H	= VIA+7
VIA.T2C_L	= VIA+8
VIA.T2C_H	= VIA+9
VAI.SR		= VIA+$A
VIA.ACR		= VIA+$B
VIA.PCR		= VIA+$C
VIA.IFR		= VIA+$D
VIA.IER		= VIA+$E
VIA.IORANS	= VIA+$F

;65SPI registers
SPI			= $7000
SPI.DATA	= SPI
SPI.CONTROL	= SPI+1	;the control reg is basically the status reg, except that certain bits cannot be written to.
SPI.STATUS	= SPI+1
SPI.DIVISOR	= SPI+2	;divisor = 2(SPI.DIVISOR + 1), SPI.DIVISOR = (divisor / 2) + 1
SPI.SSR		= SPI+3	;this is put out verbatim on the slave select pins