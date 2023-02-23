; HDOS Device Driver for Networking over H8-SPI/WizNET
;
DEBUG	equ	1

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

 if DEBUG
	;
 else
	extern	netcfg,netini,netdei,rcvhdr,rcvdat,sndhdr,snddat
 endif
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
; We cannot depend on DC.LOD, as an on-demand load
; never calls it. We must detect this by trapping the
; initial call to any DC.OPx method and then initialize
; and repair the ops table.
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
	lhld	S.SYSM	; make us resident...
	shld	S.RFWA	; (how does this work?)
	lhld	AIO.DTA	; Flag this driver as perm-res
	lxi	d,DEV.RES
	dad	d
	mov	a,m
	ori	DR.PR	; keep ourself in memory
	mov	m,a
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

nwcls:
 if DEBUG
	lxi	h,dbcls
	shld	dbtag
 endif
	lda	S.CACC	; channel num
	sta	arg0
	mvi	a,.CLOSE
	sta	mhdr+FNC
	call	setch
 if DEBUG
	mov	a,m
	sta	mhdr+DID
	mvi	m,0ffh
	lxi	h,mhdr+DID	; no-op later setting
	xra	a	; no error
 else
	mov	a,m
	inr	a
	rz	; already closed
 endif
	lxi	d,arg
	mvi	b,1
	jmp	donet

; DE = dma addr, BC = xfer count (C==0)
nwrd:
 if DEBUG
	lxi	h,dbrd
	shld	dbtag
 endif
	lda	S.CACC	; channel num
	sta	arg0
	mvi	a,.READ
	sta	mhdr+FNC
	call	savio	; save I/O params
	call	setch
 if DEBUG
	; TODO: confirm is networked...
	mvi	a,EC.EOF
 else
	mov	a,m
	inr	a
	mvi	a,EC.FNO
	stc
	rz	; nothing open
 endif
	; TODO: need to loop until count == 0
	lxi	d,arg
	mvi	b,1
	jmp	donet

; DE = dma addr, BC = xfer count (C==0)
nwwr:
 if DEBUG
	lxi	h,dbwr
	shld	dbtag
 endif
	lda	S.CACC	; channel num
	sta	arg0
	inr	a
	ori	80h
	sta	mhdr+FNC
	call	savio	; save I/O params
	call	setch
 if DEBUG
	xra	a
	lxi	d,arg	; will be DMA address
 else
	mov	a,m	; 0ffh = not open
	inr	a
	mvi	a,EC.FNO
	stc
	rz	; nothing open
	; DE = dma addr (data to write)
 endif
	; TODO: need to loop until count == 0
	mvi	b,0
	jmp	donet

; .OPENR

nwopr:
 if DEBUG
	lxi	h,dbopr
	shld	dbtag
 endif
	mvi	a,.OPENR
	jmp	nwoc

; .OPENW
nwopw:
 if DEBUG
	lxi	h,dbopw
	shld	dbtag
 endif
	mvi	a,.OPENW
	jmp	nwoc

; .OPENU
nwopu:
 if DEBUG
	lxi	h,dbopu
	shld	dbtag
 endif
	mvi	a,.OPENU
	;jmp	nwoc
nwoc:
	sta	mhdr+FNC
	lda	S.CACC	; channel number
	sta	arg0
	lxi	d,AIO.DEV
	lxi	h,fqfn
	lxi	b,fqfnl-1
	call	$MOVE
	; check if device is remote
	lda	fqfn+2	; unit num
	call	chkloc
	rc	; device has no remote mapping
	; TODO: server ID is in (HL) (netadr)
 if DEBUG
	; TODO: not until after response
	mov	a,m	; NID of server
	push	psw
	call	setch
	pop	psw
	mov	m,a	; server ID hosting open file
 endif
	call	setrem	; change "NWx" to mapped remote device/unit
	lhld	netadr
	lxi	d,arg
	mvi	b,fqfnl
 if DEBUG
	xra	a	; no error
 endif
	jmp	donet

; save DE and BC for .READ/.WRITE ops
savio:	xchg
	shld	dmaadr
	xchg
	push	b
	xthl
	shld	iocnt
	pop	h
	ret

; SCALL intercept
scint:	sta	arg0
	xthl
	mov	a,m
	sta	mhdr+FNC
	xthl	; TODO: wait to do this?
	cpi	.POSIT
	jz	intpos
	cpi	.LINK
	jz	check2
	cpi	.RENAM
	jz	check2
	cpi	.DELET
	jz	check2
	cpi	.CHFLG
	jz	check2
pass:	lda	arg0
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
dmaadr:	dw	0
iocnt:	dw	0

; returns with HL = &chtbl[ch]
setch:	lda	arg0
setch0:	inr	a
	sta	arg
	ani	7	; TODO: needed?
	lxi	h,chtbl
	jmp	@DADA

; .POSIT - check SCALL with channel number
intpos:
 if DEBUG
	lxi	h,dbpos
	shld	dbtag
 endif
	lda	arg
	call	setch0
	mov	a,m	; 0ffh = not networked
	inr	a
	jz	error
	xra	a	; no error
	lxi	d,arg	; DE => channel number
	mvi	b,1
; skip SCALL function code
donet0:
	xthl
	inx	h
	xthl
; HL => server ID (&chtbl[ch])
; DE => payload
; B = payload length (00 = 256)
; A = return code
; TODO: need to translate local dev to remote dev...
donet:
 if DEBUG
	sta	retcod	; normally, retcod comes from response
 endif
	mov	a,m
	sta	mhdr+DID
	mov	a,b
	dcr	a
	sta	mhdr+SIZ
	; FNC already set
	mvi	a,FMT.HDOS
	sta	mhdr+FMT
	;... pass call to server...
 if DEBUG
	lda	netcfg+1
	sta	mhdr+SID	; normally done by snios?
; debug: print the message
	lhld	dbtag
	call	typtx.
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
	call	conout
don0:
	; fixup READ/WRITE
	lda	mhdr+FNC
	cpi	.READ
	jz	don2
	ani	80h	; .WRITE?
	jz	don1
	; .WRITE - pretend everything was written
	lhld	iocnt
	xchg
	lhld	dmaadr
	dad	d
	xchg
	lxi	b,0
	jmp	don1
don2:	; .READ - nothing was returned (EOF)
	lhld	dmaadr
	xchg
	lhld	iocnt
	mov	c,l
	mov	b,h
don1:
 endif
	lda	retcod
	ora	a
	rz
	stc
	ret

 if DEBUG
nothing:
	call	typtx
	db	' ...',ENL
	jmp	don0

hxd0:	mvi	a,' '
	call	conout
hxd:	mov	a,m
	call	hexout
	inx	h
	dcr	b
	jnz	hxd0
	ret

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
conout:	call	hdose
	db	.SCOUT
	ret

; avoid passing through DVD for these calls from us
typtx:	xthl
	call	typtx.
	xthl
	ret
typtx.:	mov	a,m
	ani	7fh
	call	hdose
	db	.SCOUT
	cmp	m
	inx	h
	jz	typtx.
	ret

dbtag:	dw	0
dbopr:	db	NL,'.OPENR',' '+200q
dbopw:	db	NL,'.OPENW',' '+200q
dbopu:	db	NL,'.OPENU',' '+200q
dbcls:	db	NL,'.CLOSE',' '+200q
dbrd:	db	NL,'.READ',' '+200q
dbwr:	db	NL,'.WRITE',' '+200q
dbpos:	db	NL,'.POSIT',' '+200q
dbdel:	db	NL,'.DELET',' '+200q
dblnk:	db	NL,'.LINK',' '+200q
dbren:	db	NL,'.RENAM',' '+200q
dbchf:	db	NL,'.CHFLG',' '+200q
 endif

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
 if DEBUG
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
gotit:	shld	dbtag
 endif
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
	jmp	donet0

; A = error code
error:	pop	h
	pop	d
	pop	b
	stc
	ret

; Check local drive config
; A = unit number
; returns CY if not defined (error).
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

; Copy remote drive spec into FQFN.
setrem:	lhld	netadr	; server ID
	mov	a,m	; server NID
	sta	mhdr+DID
	inx	h	; remote dev name/unit
	lxi	d,fqfn
	xchg
	lxi	b,3
	jmp	$MOVE

 if DEBUG
; normally resides in SNIOS?
netcfg:	db	0	; network status byte
	db	055h	; this node ID
	db	0,'sy0'	; NW0 => SY0[00]
	db	1,'sy1'	; NW1 => SY1[01]
	db	2,'sy2'	; NW2 => SY2[02]
	db	3,'sy3'	; NW3 => SY3[03]
	db	4,'sy4'	; NW4 => SY4[04]
	db	5,'sy5'	; NW5 => SY5[05]
	db	6,'sy6'	; NW6 => SY6[06]
	db	7,'sy7'	; NW7 => SY7[07]
 endif

	end
