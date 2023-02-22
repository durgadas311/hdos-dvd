; HDOS Device Driver for Networking over H8-SPI/WizNET
;
	aseg
	include	mtr.acm
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
	include	move.acm
	include	dada.acm

	include	dirdef.acm
	include	esint.acm

	include cpnet.acm

	cseg
base:
	phase	($-base)+PIC.COD

NDCAP	equ	DT.CR+DT.CW		;read/write
NDMAX	equ	8

	db	DVDFLV		;DEVICE DRIVER FLAG VALUE
	db	NDCAP		;DEVICE OF READ AND WRITE
	db	(1<<NDMAX)-1	;MOUNTED UNIT MASK
	db	NDMAX		;ONLY 1 UNIT
	db	NDCAP,NDCAP,NDCAP,NDCAP
	db	NDCAP,NDCAP,NDCAP,NDCAP
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
nwdvd:
	call	$TBRA
	db	nwrd-$		; READ - DC.REA - 0
	db	nwwr-$	 	; WRITE - DC.WRI - 1
	db	nwilr-$ 	; READR - DC.RER - 2
	db	nwopr-$ 	; OPENR - DC.OPR - 3
	db	nwopw-$ 	; OPENW - DC.OPW - 4
	db	nwopu-$ 	; OPENU - DC.OPU - 5
	db	nwcls-$		; CLOSE - DC.CLO - 6
	db	nwnop-$		; ABORT - DC.ABT - 7
	db	nwilr-$ 	; MOUNT - DC.MOU - 8
	db	nwld-$		; LOAD - DC.LOD - 9
	db	nwnop-$ 	; READY - DC.RDY - 10
	; HDOS 3.0
	db	nwilr-$ 	; SET - DC.SET - 11
	db	nwul-$	 	; UNLOAD - DC.UNL - 12
	db	nwilr-$ 	; INTERRUPT - DC.INT - 13
	db	nwilr-$ 	; DEVICE SPECIFIC - DC.DSF - 14

;*	Illegal Request
nwilr:	mvi	a,EC.ILR	;DEVICE DRIVER ABORT
	stc
	ret

;*	EOF
nweof:	mvi	a,EC.EOF
	stc
	ret

;*	No operation
nwnop:	ana	a
	ret			;DO NOTHING

nwld:	; driver init
	lhld	.UIVEC+18+1
	shld	hdose+1
	lxi	h,scint
	shld	.UIVEC+18+1
	xra	a
	ret

nwul:	; driver kill - 3.0 only
	lhld	hdose+1
	shld	.UIVEC+18+1
	; TODO: shutdown network
	xra	a
	ret

nwcls:	call	$TYPTX
	db	NL,'.CLOSE',' '+200q
	mvi	a,.CLOSE
	sta	mhdr+FNC
	call	setch
	mvi	m,0ffh
	xra	a
	jmp	nwfnc

nwrd:	call	$TYPTX
	db	NL,'.READ',' '+200q
	mvi	a,.READ
	sta	mhdr+FNC
	call	setch
	; TODO: confirm is networked...
	mvi	a,EC.EOF
nwfnc:
	lxi	d,arg
	mvi	b,1
	jmp	donet

nwwr:	call	$TYPTX
	db	NL,'.WRITE',' '+200q
	lda	S.CACC	; channel num
	ori	80h
	sta	mhdr+FNC
	call	setch
	; TODO: confirm networked...
	xra	a	; no error
	lxi	d,arg	; will be DMA address
	mvi	b,0
	jmp	donet

; .OPENR

nwopr:	call	$TYPTX
	db	NL,'.OPENR',' '+200q
	mvi	a,.OPENR
	jmp	nwoc

; .OPENW
nwopw:	call	$TYPTX
	db	NL,'.OPENW',' '+200q
	mvi	a,.OPENW
	jmp	nwoc

; .OPENU
nwopu:	call	$TYPTX
	db	NL,'.OPENU',' '+200q
	mvi	a,.OPENU
	;jmp	nwoc
nwoc:
	sta	mhdr+FNC
	lxi	d,AIO.DEV
	lxi	h,fqfn
	lxi	b,fqfnl-1
	call	$MOVE
	; TODO: translate device name: netcfg.map[unit].name
	; also, check if mapped.
	call	setch
	; TODO: not until after response
	mvi	m,0	; server ID hosting open file
	lxi	d,arg
	mvi	b,fqfnl
	xra	a	; no error
	jmp	donet

; SCALL intercept
scint:	sta	arg
	xthl
	mov	a,m
	sta	mhdr+FNC
	xthl	; TODO: wait to do this?
	cpi	.POSIT
	jz	check1
	cpi	.LINK
	jz	check2
	cpi	.RENAM
	jz	check2
	cpi	.DELET
	jz	check2
	cpi	.CHFLG
	jz	check2
pass:	lda	arg
hdose:	jmp	$-$	; link to HDOS

pass2:	pop	h
	pop	d
	pop	b
	jmp	pass

mhdr:	db	0,0,0,0,0
arg:	db	0	; channel number (typ)
fqfn:	db	'DDUFILENAMETYP'
fqfnl	equ	$-arg	; whole message length
fqfn2:	db	'DDUFILENAMETYP'
	db	0,0,0,0,0
retcod:	db	0
netadr:	dw	0

chtbl:	db	0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; how many channels max?
	db	0ffh,0ffh

; returns with HL = &chtbl[ch]
setch:	lda	S.CACC
setch0:	inr	a
	sta	arg
	ani	7
	lxi	h,chtbl
	jmp	@DADA

; check SCALL with channel number
; always, only, .POSIT
check1:	lda	arg
	call	setch0
	mov	a,m	; 0ffh = not networked
	inr	a
	jz	pass
	call	$TYPTX
	db	NL,'.POSIT',' '+200q
	xra	a	; no error
	lxi	d,arg	; DE => channel number
	mvi	b,1
; HL => server ID (&chtbl[ch])
; DE => payload
; B = payload length (00 = 256)
; A = return code
; TODO: need to translate local dev to remote dev...
donet:
	sta	retcod
	mov	a,m
	sta	mhdr+DID
	mov	a,b
	dcr	a
	sta	mhdr+SIZ
	; FNC already set
	mvi	a,FMT.HDOS
	sta	mhdr+FMT
	;... pass call to server...
; debug: print the message
	push	b
	push	d
	lxi	h,mhdr
	mvi	b,DAT
	call	hxd
	pop	h
	pop	b
	call	hxd0
	mvi	a,NL
	db	SYSCALL,.SCOUT
	lda	retcod
	ora	a
	rz
	stc
	ret

hxd0:	mvi	a,' '
	db	SYSCALL,.SCOUT
hxd:	mov	a,m
	call	hexout
	inx	h
	dcr	b
	jnz	hxd0
	ret

dbdel:	db	NL,'.DELET',' '+200q
dblnk:	db	NL,'.LINK',' '+200q
dbren:	db	NL,'.RENAM',' '+200q
dbchf:	db	NL,'.CHFLG',' '+200q

; check SCALL with file desc and default block
check2:	; might also have BC param
	push	b
	push	d
	push	h
	; try and do this quickly, else need to call .DECODE...
	; (which means doing that twice for the local case)
	mov	c,m	; possible device name
	inx	h
	mov	b,m
	inx	h
	mvi	a,':'
	cmp	m
	jz	chkddn
	inx	h
	cmp	m
	jz	chkddn
	xchg
	mov	c,m
	inx	h
	mov	b,m
chkddn:	; TODO: don't want to hard-code this...?
	mov	a,c
	cpi	'N'
	jnz	pass2
	mov	a,b
	cpi	'W'
	jnz	pass2
	inx	h	; unit number
	mov	a,m	; already - '0' ?
	add	a
	inr	a
	add	a
	lxi	h,netcfg
	call	@DADA
	mov	a,m	; 0 = not configured
	ani	80h
	mvi	a,EC.UND
	jz	error
	shld	netadr
	lda	mhdr+FNC
	cpi	.LINK
	lxi	h,dblnk
	jz	gotit
	cpi	.RENAM
	lxi	h,dbren
	jz	gotit
	cpi	.DELET
	lxi	h,dbdel
	jz	gotit
	lxi	h,dbchf
gotit:	call	$TYPTX.
	; TODO: translate device name
	pop	h
	pop	d
	push	d
	lxi	b,fqfn
	call	hdose
	db	.DECODE
	pop	d
	pop	h
	lda	mhdr+FNC
	cpi	.RENAM
	jnz	chkd1
	lxi	b,fqfn2
	call	hdose
	db	.DECODE
chkd1:	lhld	netadr
	inx	h
	inx	h
	inx	h	; server ID
	lxi	d,arg
	mvi	b,fqfnl
	xra	a	; no error
	jmp	donet

; A = error code
error:	pop	h
	pop	d
	pop	b
	stc
	ret

netcfg:	db	0,0	; TODO: node ID, status
	db	'sy0',0	; NW0 => SY0[00]
	db	'sy1',0	; NW1 => SY1[00]
	db	'sy2',0	; NW2 => SY2[00]
	db	'sy3',0	; NW3 => SY3[00]
	db	'sy4',0	; NW4 => SY4[00]
	db	'sy5',0	; NW5 => SY5[00]
	db	'sy6',0	; NW6 => SY6[00]
	db	'sy7',0	; NW7 => SY7[00]

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
