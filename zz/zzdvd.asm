; Experimental Hdos device driver
; for seeing when HDOS calls the driver and how.
;
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

	include	tbra.acm
	include	typtx.acm

	include	dirdef.acm
	include	esint.acm

	cseg
base:
	phase	($-base)+PIC.COD

NDCAP	equ	DT.CR+DT.CW		;read/write
NDMAX	equ	1

	db	DVDFLV		;DEVICE DRIVER FLAG VALUE
	db	NDCAP		;DEVICE OF READ AND WRITE
	db	1<<NDMAX-1	;MOUNTED UNIT MASK
	db	NDMAX		;ONLY 1 UNIT
	db	NDCAP		;0:    CAPABLE OF READ AND WRITE
	ds	8-NDMAX		;1-7:  IGNORED
	db	DVDFLV		;DEVICE DRIVER FLAG
	DW	0		;No INIT Parameters		/80.09.gc/
	db	DVDFLV
	db	SPL-1
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
setntr:
	ana	a
	jnz	set1
	mov	b,d
	mov	c,e		;(BC) = PARAMETER LIST ADDRESS
	lxi	d,prctab	;(DE) = PROCESSOR TABLE ADDRESS
	lxi	h,opttab	;(HL) = OPTION TABLE ADDRESS
	call	$SOP
	rc			;THERE WAS AN ERROR
	call	$SNA
	rz			;AT THE END OF THE LINE
	mvi	a,EC.ILO
	stc
	ret

set1:	mvi	a,EC.UUN	;UNKNOWN UNIT NUMBER
	stc
	ret

;**	PROCESSORS
;
;*	HELP	-  PROCESS HELP OPTION
;
;	LIST THE VALID OPTIONS ON THE USER CONSOLE
;
help:	call	$TYPTX
	db	NL,'No Options for Test Device',NL
	db	NL
	db	'HELP	Type this message',NL
	db	NL
	db	'This is the only valid option for the NULL device',NL
	db	ENL
	xra	a
	ret

;**	SET TABLES
;
;
;*	OPTAB	-  OPTION TABLE
;
opttab:	dw	opttabe		;END OF THE TABLE
	db	1

	db	'HEL','P'+200Q,HELPI
opttabe: db	0

;*	PRCTAB	-  PROCESSOR TABLE
;
prctab:
;	none - yet
helpi	equ	($-prctab)/2
	dw	help
;*	"what" identification
	db	'@(#)HDOS 3.0 Test Driver',NL
	dw	0
	dw	0
;**	End of Preamble
;

PAD	equ	(($+01ffh) and 0fe00h)-$
SPL	equ	(PAD+511)/512

	ds	PAD
; The resident portion of the driver
zzdvd:
	call	$TBRA
	db	zzrd-$		; READ
	db	zzwr-$	 	; WRITE
	db	zzilr-$ 	; READR
	db	zzopr-$ 	; OPENR
	db	zzopw-$ 	; OPENW
	db	zzopu-$ 	; OPENU
	db	zzcls-$		; CLOSE
	db	zznop-$		; ABORT
	db	zzilr-$ 	; MOUNT
	db	zznop-$		; LOAD
	db	zznop-$ 	; READY
	db	zzilr-$ 	; SET
	db	zzilr-$ 	; UNLOAD
	db	zzilr-$ 	; INTERRUPT
	db	zzilr-$ 	; DEVICE SPECIFIC

;*	Illegal Request
zzilr:	mvi	a,EC.ILR	;DEVICE DRIVER ABORT
	stc
	ret

;*	EOF
zzeof:	mvi	a,EC.EOF
	stc
	ret

zzcls:	call	$TYPTX
	db	NL,'.CLOSE',' '+200q
	mvi	a,NL
	call	hexcha
	xra	a
	ret

zzrd:	call	$TYPTX
	db	NL,'.READ',' '+200q
	mvi	a,EC.EOF
	stc
	jmp	zz00

zzwr:	call	$TYPTX
	db	NL,'.WRITE',' '+200q
	xra	a
zz00:	push	psw
	push	b
	push	d
	mvi	a,' '
	call	hexcha
	pop	h
	call	hexwrd
	mvi	a,' '
	db	SYSCALL,.SCOUT
	pop	h
	call	hexwrd
	mvi	a,' '
	db	SYSCALL,.SCOUT
	pop	psw	; may be CY
	ret

;*	No operation
zznop:	ana	a
	ret			;DO NOTHING

; .OPENR

zzopr:	call	$TYPTX
	db	NL,'.OPENR',' '+200q
zzoc:
	mvi	a,' '
	call	hexcha
	lxi	h,AIO.DEV
	mvi	b,16
zzoc0:	mov	a,m
	cpi	' '
	jc	zzoc1
	cpi	'~'
	jnz	zzoc2
zzoc1:	mvi	a,'_'
zzoc2:	db	SYSCALL,.SCOUT
	inx	h
	dcr	b
	jnz	zzoc0
	mvi	a,NL
	db	SYSCALL,.SCOUT
	xra	a
	ret

; .OPENW
zzopw:	call	$TYPTX
	db	NL,'.OPENW',' '+200q
	jmp	zzoc

; .OPENU
zzopu:	call	$TYPTX
	db	NL,'.OPENU',' '+200q
	jmp	zzoc

; A=last char
hexcha:	push	psw
	lhld	AIO.CHA
	call	hexwrd
	pop	psw
	db	SYSCALL,.SCOUT
	ret

hexwrd:	mov	a,h
	call	hexout
	mov	a,l
hexout:	push	psw
	rlc
	rlc
	rlc
	rlc
	call	hexdig
	pop	psw
hexdig:	ani	0fh
	adi	90h
	daa
	aci	40h
	daa
	db	SYSCALL,.SCOUT
	ret
