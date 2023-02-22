;	TITLE	'NDDVD - ND DEVICE DRIVER'
;**	NDDVD - ND DEVICE DRIVER.
;
;	J.G. LETWIN

	aseg
	include	ascii.acm
	include	dddef.acm
	include	hosdef.acm
	include	hosequ.acm
	include	ecdef.acm
	include	esval.acm
	include	devdef.acm
	include	fildef.acm
	include	picdef.acm
	include	dvddef.acm

	include	setcal.acm

	include	hrom.acm

	cseg
BASE:
	phase	($-BASE)+PIC.COD

NDCAP	EQU	DT.CR+DT.CW		;read/write
NDMAX	EQU	1

	DB	DVDFLV		;DEVICE DRIVER FLAG VALUE
	DB	NDCAP		;DEVICE OF READ AND WRITE
	DB	1<<NDMAX-1	;MOUNTED UNIT MASK
	DB	NDMAX		;ONLY 1 UNIT
	db	NDCAP		;0:    CAPABLE OF READ AND WRITE
	ds	8-NDMAX		;1-7:  IGNORED
	DB	DVDFLV		;DEVICE DRIVER FLAG
	DW	0		;No INIT Parameters		/80.09.gc/
	DB	DVDFLV
	DB	SPL-1
	ds	20

;**	SET CODE ENTRY POINT
;
;
;	ENTRY:	(DE)	=  LINE POINTER
;		(A)	=  UNIT NUMBER
;
;	EXIT:	(PSW)	=  'C' CLEAR IF NO ERROR
;			=  'C' SET   IF    ERROR
;
;	USES:	ALL
;
SETNTR:
	ANA	A
	JNZ	SET1
	MOV	B,D
	MOV	C,E		;(BC) = PARAMETER LIST ADDRESS
	LXI	D,PRCTAB	;(DE) = PROCESSOR TABLE ADDRESS
	LXI	H,OPTTAB	;(HL) = OPTION TABLE ADDRESS
	CALL	$SOP
	RC			;THERE WAS AN ERROR
	CALL	$SNA
	RZ			;AT THE END OF THE LINE
	MVI	A,EC.ILO
	STC
	RET

SET1:	MVI	A,EC.UUN	;UNKNOWN UNIT NUMBER
	STC
	RET

;**	PROCESSORS
;
;*	HELP	-  PROCESS HELP OPTION
;
;	LIST THE VALID OPTIONS ON THE USER CONSOLE
;
HELP:	CALL	$TYPTX
	DB	NL,'Set Options for NULL Device',NL
	DB	NL
	DB	'HELP	Type this message',NL
	DB	NL
	DB	'This is the only valid option for the NULL device',NL
	DB	ENL
	XRA	A
	RET

;**	SET TABLES
;
;
;*	OPTAB	-  OPTION TABLE
;
OPTTAB:	DW	OPTTABE		;END OF THE TABLE
	DB	1

	DB	'HEL','P'+200Q,HELPI
OPTTABE:	DB	0

;*	PRCTAB	-  PROCESSOR TABLE
;
PRCTAB:
HELPI	EQU	($-PRCTAB)/2
	DW	HELP
;*	"what" identification
	DB	'@(#)HDOS 3.0 Null Driver',NL
	DW	0
	DW	0
;**	End of Preamble
;

PAD	EQU	(($+01ffh) and 0fe00h)-$
SPL	EQU	(PAD+511)/512

	ds	PAD

NDDVD:
	CALL	$TBRA
	DB	NDREAD-$	; READ
	DB	NDNOP-$ 	; WRITE
	DB	NDILR-$ 	; READR
	DB	NDNOP-$ 	; OPENR
	DB	NDNOP-$ 	; OPENW
	DB	NDILR-$ 	; OPENU
	DB	NDNOP-$		; CLOSE
	DB	NDNOP-$		; ABORT
	DB	NDILR-$ 	; MOUNT
	DB	NDNOP-$		; LOAD
	DB	NDNOP-$ 	; READY
	DB	NDILR-$ 	; SET
	DB	NDILR-$ 	; UNLOAD
	DB	NDILR-$ 	; INTERRUPT
	DB	NDILR-$ 	; DEVICE SPECIFIC

;*	Illegal Request
NDILR:	MVI	A,EC.ILR	;DEVICE DRIVER ABORT
	DB	0x21	; lxi h, to hide next instr


;*	Read
NDREAD:	MVI	A,EC.EOF
	STC
	RET


;*	No operation
NDNOP:	ANA	A
	RET			;DO NOTHING

	END
