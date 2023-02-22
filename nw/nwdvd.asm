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

	include	hrom.acm

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
	call	$TBRA	; preserves A
	db	nwrd-$		; READ - DC.REA - 0
	db	nwwr-$	 	; WRITE - DC.WRI - 1
	db	nwilr-$ 	; READR - DC.RER - 2
opr:	db	nwld-$ 		; OPENR - DC.OPR - 3
opw:	db	nwld-$ 		; OPENW - DC.OPW - 4
opu:	db	nwld-$	 	; OPENU - DC.OPU - 5
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

; AIO.DTA has our table entry?

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
	push	psw	; DC.* code
	call	$TYPTX
	db	NL,'_INIT',ENL
	pop	psw
	; must preserve op code in A
	push	psw	; DC.* code
	lhld	.UIVEC+18+1
	shld	hdose+1
	lxi	h,scint
	shld	.UIVEC+18+1
	; repair op table
	lxi	h,opr
	mvi	m,nwopr-opr
	inx	h
	mvi	m,nwopw-opw
	inx	h
	mvi	m,nwopu-opu
	lhld	AIO.DTA
	call	$HLIHL	; HL = two-char dev name
	shld	dvdnm
	pop	psw
	cpi	DC.LOD
	jnz	nwdvd	; now execute true function
	xra	a
	ret

nwul:	; driver kill - 3.0 only
	lhld	hdose+1
	shld	.UIVEC+18+1
	; TODO: shutdown network
	xra	a
	ret

nwcls:	call	dbgtyptx
	db	NL,'.CLOSE',' '+200q
	mvi	a,.CLOSE
	sta	mhdr+FNC
	call	setchZ
	mvi	m,0ffh
	xra	a
	jmp	nwfnc

nwrd:	call	dbgtyptx
	db	NL,'.READ',' '+200q
	mvi	a,.READ
	sta	mhdr+FNC
	call	setchZ
	; TODO: confirm is networked...
	mvi	a,EC.EOF
nwfnc:
	lxi	d,arg
	mvi	b,1
	jmp	donet

nwwr:	call	dbgtyptx
	db	NL,'.WRITE',' '+200q
	;lda	S.CACC	; channel num
	lda	arg0	; TODO: during debug only
	inr	a
	ori	80h
	sta	mhdr+FNC
	call	setchZ
	; TODO: confirm networked...
	xra	a	; no error
	lxi	d,arg	; will be DMA address
	mvi	b,0
	jmp	donet

; .OPENR

nwopr:	call	dbgtyptx
	db	NL,'.OPENR',' '+200q
	mvi	a,.OPENR
	jmp	nwoc

; .OPENW
nwopw:	call	dbgtyptx
	db	NL,'.OPENW',' '+200q
	mvi	a,.OPENW
	jmp	nwoc

; .OPENU
nwopu:	call	dbgtyptx
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
	call	setchZ
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
arg0:	db	0

chtbl:	db	0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; how many channels max?
	db	0ffh,0ffh

dvdnm:	db	'W','N'	; replaced at init with actual name

; returns with HL = &chtbl[ch]
setch:	lda	S.CACC
setch0:	inr	a
	sta	arg
	ani	7
	lxi	h,chtbl
	jmp	@DADA

setchZ:	lda	arg0
	jmp	setch0

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
	mov	a,b
	ora	a
	jz	nothing
	call	hxd0
	mvi	a,NL
	db	SYSCALL,.SCOUT
don0:	lda	retcod
	ora	a
	rz
	stc
	ret

nothing:
	call	$TYPTX
	db	' ...',ENL
	jmp	don0

dbgtyptx:
	lda	S.CACC
	sta	arg0
	jmp	$TYPTX

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
chkddn:	; BC = dvd name, HL = unit-1
	xchg
	lhld	dvdnm
	xchg
	mov	a,c
	xra	e
	jnz	pass2
	mov	b,b
	xra	d
	jnz	pass2
	inx	h	; unit number
	mov	a,m	; already - '0' ?
	call	chkloc
	jc	error
; debug
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
	lxi	b,fqfn
	call	hdose
	db	.DECODE
	pop	h	; new file name for .RENAM
	rc
	; TOFO: does 2nd file get decoded?
	lda	mhdr+FNC
	cpi	.RENAM
	jnz	chkd1
	lxi	d,$ZEROS
	lxi	b,fqfn2
	call	hdose
	db	.DECODE
	rc
chkd1:
	call	setrem	; set remote dev name
	lhld	netadr	; server ID
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

; A = unit number
chkloc:	add	a
	inr	a
	add	a	; A = (A * 4) + 2
	lxi	h,netcfg
	call	@DADA
	shld	netadr
	mov	a,m	; 0ffh = not configured
	adi	1	; CY if 0ffh
	mvi	a,EC.UND
	ret

setrem:	lhld	netadr	; server ID
	inx	h	; remote dev name/unit
	lxi	d,fqfn
	xchg
	lxi	b,3
	jmp	$MOVE

netcfg:	db	0,0	; TODO: node ID, status
	db	0,'sy0'	; NW0 => SY0[00]
	db	0,'sy1'	; NW1 => SY1[00]
	db	0,'sy2'	; NW2 => SY2[00]
	db	0,'sy3'	; NW3 => SY3[00]
	db	0,'sy4'	; NW4 => SY4[00]
	db	0,'sy5'	; NW5 => SY5[00]
	db	0,'sy6'	; NW6 => SY6[00]
	db	0,'sy7'	; NW7 => SY7[00]

; debug
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

	end
