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

; We might be identifiable by (DT.RN && !DT.DD)
NDCAP	equ	DT.CR+DT.CW+DT.RN	;read/write/random
NDMAX	equ	8

	db	DVDFLV		;DEVICE DRIVER FLAG VALUE
	db	NDCAP		;DEVICE CAPABILITIES
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
	db	nwdsf-$ 	; DEVICE SPECIFIC - DC.DSF - 14

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
	jmp	nwinit

nwul:	; driver kill - 3.0 only (not called anyway?)
	; TODO: shutdown network
	xra	a
	ret

nwcls:
 if DEBUG
	lxi	h,dbcls
	shld	dbtag
	xra	a	; no error
	sta	retcod
 endif
	lda	S.CACC	; channel num
	sta	arg0
	mvi	a,.CLOSE
	sta	mhdr+FNC
	call	setch
	mov	a,m
	sta	mhdr+DID
	inr	a
	rz	; already closed
 if DEBUG
	mvi	m,0ffh
 endif
	lxi	h,arg
	shld	datptr
	mvi	a,1
	sta	datlen
	jmp	donet

; DE = dma addr, BC = xfer count (C==0)
nwrd:
 if DEBUG
	lxi	h,dbrd
	shld	dbtag
	mvi	a,EC.EOF
	sta	retcod
 endif
	lda	S.CACC	; channel num
	sta	arg0
	mvi	a,.READ
	sta	mhdr+FNC
	call	savio	; save I/O params
	call	setch
	mov	a,m
	sta	mhdr+DID
	inr	a
	mvi	a,EC.FNO
	stc
	rz	; nothing open
	lxi	h,arg	; channel number
	shld	datptr
	mvi	a,1
	sta	datlen
	jmp	doio

; DE = dma addr, BC = xfer count (C==0)
nwwr:
 if DEBUG
	lxi	h,dbwr
	shld	dbtag
	xra	a	; no error
	sta	retcod
 endif
	lda	S.CACC	; channel num
	sta	arg0
	inr	a
	ori	80h
	sta	mhdr+FNC
	call	savio	; save I/O params
	call	setch
	mov	a,m	; 0ffh = not open
	sta	mhdr+DID
	inr	a
	mvi	a,EC.FNO
	stc
	rz	; nothing open
 if DEBUG
	lxi	h,arg	; dummy, nothing sent in DEBUG
 else
	; DE = dma addr (data to write)
	lhld	dmaadr
 endif
	shld	datptr
	; TODO: need to loop until count == 0
	mvi	a,0	; 256 (0 if DEBUG)
	sta	datlen
	jmp	doio

; .OPENR

nwopr:
 if DEBUG
	lxi	h,dbopr
	shld	dbtag
	lxi	h,AIO.DIR
	call	oprchk
	sta	retcod
	mvi	a,.OPENR
	sta	mhdr+FNC
	jmp	nwoc0
 else
	mvi	a,.OPENR
	jmp	nwoc
 endif

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
	jmp	nwoc

; A = DC.DSF
; C = function (syscall code)
; B = channel (if used)
; DE = parameter (depends on function)
; HL = parameter (depends on function)
; .POSIT:  B = channel, DE = sector
; .DELET:  HL = decoded file desc (ambiguous)
; .RENAM:  DE = new file desc, HL = old file desc
; .CHFLG:  DE = bits/mask, HL = decoded file desc
; .SERF: * DE = buffer, HL = decoded file desc (ambiguous)
; .SERN: * DE = buffer
nwdsf:	mov	a,b	; might be channel
	sta	arg0
	mov	a,c
	sta	mhdr+FNC
	cpi	.NTCFG
	jz	getcfg
	cpi	.POSIT	; channel, sector-address
	jz	intpos
	cpi	.SERF	; arg, fqfnl+1
	jz	intfrs
	cpi	.SERN	; (none)
	jz	intnxt
	cpi	.RENAM	; fqfn, fqfn2l
	jz	intren
	cpi	.CHFLG
	jz	intchf
	push	h
	lxi	h,fqfn	; most are fqfn, fqfnl
	shld	datptr
	mvi	a,fqfnl
	sta	datlen
	pop	h
	jmp	intdef	; HL file descriptor
; ----- end of relative jump targets -----

getcfg:	lxi	h,netcfg
	ora	a
	ret

nwinit:
	; must preserve op code in A, but also S.CACC
	push	psw	; DC.* code
	lda	S.CACC
	push	psw
	SCALL	.VERS
	sta	hver
	pop	psw
	sta	S.CACC
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
	ori	DR.PR+DR.IM	; keep ourself in memory
	mov	m,a
	pop	psw
	cpi	DC.LOD
	jnz	nwdvd	; now execute true function
	xra	a
	ret

nwoc:
	sta	mhdr+FNC
 if DEBUG
	xra	a	; no error
	sta	retcod
nwoc0:
 endif
	lda	S.CACC	; channel number
	sta	arg0
	lxi	d,AIO.DEV
	lxi	h,fqfn
	lxi	b,fqfnl
	call	$MOVE
	; check if device is remote
	lda	fqfn+2	; unit num
	call	chkloc
	rc	; device has no remote mapping
	; TODO: server ID is in (HL) (netadr)
	mov	a,m	; NID of server
	sta	mhdr+DID
 if DEBUG
	; TODO: not until after response
	push	psw
	call	setch
	pop	psw
	mov	m,a	; server ID hosting open file
 endif
	call	setrem	; change "NWx" to mapped remote device/unit
	lxi	h,arg
	shld	datptr
	mvi	a,fqfnl+1
	sta	datlen
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

mhdr:	db	0,0,0,0,0
arg2:	db	0
arg:	db	0	; channel number (typ)
fqfn:	db	'DDUFILENAMETYP'
fqfnl	equ	$-fqfn
fqfn2:	db	'DDUFILENAMETYP'
fqfn2l	equ	$-fqfn
	db	0,0,0,0,0
retcod:	db	0
netadr:	dw	0
arg0:	db	0

chtbl:	db	0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; how many channels max?
	db	0ffh,0ffh

hver:	db	0
dvdnm:	dw	'NW'	; replaced at init with actual name
dmaadr:	dw	0
iocnt:	dw	0
currch:	dw	0
datptr:	dw	0
datlen:	db	0

doio:	; TODO: might need to reset FMT, DID, SID on each cycle.
	lda	iocnt+1
	ora	a
	jnz	doio0
	sta	retcod
	jmp	retout
doio0:	call	donet
	lda	retcod
	ora	a
	jnz	retout
	lhld	dmaadr
	inr	h	; +256 bytes
	shld	dmaadr
	shld	datptr
	lhld	iocnt
	dcr	h	; -256 bytes
	shld	iocnt
	jnz	doio0
	jmp	retout

; returns with HL = &chtbl[ch]
setch:	lda	arg0
	inr	a
	sta	arg
	ani	7	; TODO: needed?
	lxi	h,chtbl
	call	@DADA
	shld	currch
	ret

; .SERN - DE = buffer
intnxt:	xchg
	shld	dmaadr
 if DEBUG
	lxi	h,dbsrn
	shld	dbtag
	call	filser	; sets retcod
 endif
	lxi	h,arg
	shld	datptr
	mvi	a,1
	sta	datlen
	jmp	donet

; .POSIT - check SCALL with channel number
intpos:
 if DEBUG
	lxi	h,dbpos
	shld	dbtag
	xra	a	; no error
	sta	retcod
 endif
	; B = channel, DE has sector address
	mov	a,b
	sta	arg0
	xchg
	shld	arg+1	; put sec adr in message buffer
	call	setch
	mov	a,m	; 0ffh = not networked
	sta	mhdr+DID
	inr	a
	jz	notnet
	lxi	h,arg	; channel number, sec adr
	shld	datptr
	mvi	a,3
	sta	datlen
; datptr => payload
; datlen = payload length (00 = 256)
; DID, FNC already set
donet:
	lda	datlen
	dcr	a
	sta	mhdr+SIZ
	mvi	a,FMT.HDOS
	sta	mhdr+FMT
	;... pass call to server...
 if DEBUG
; debug: print the message
	lda	netcfg+1
	sta	mhdr+SID	; normally done by snios?
	lhld	dbtag
	call	$TYPTX.
	lxi	h,mhdr
	mvi	b,DAT
	call	hxd
	lda	datlen
	ora	a
	jz	nothing
	mov	b,a
	lhld	datptr
	call	hxd0
	mvi	a,NL
	call	conout
 endif
retout:	lda	retcod
	ora	a
	rz
	stc
	ret

 if DEBUG
nothing:
	call	$TYPTX
	db	' ...',' '+200Q
	lhld	dmaadr
	call	hexwrd
	mvi	a,' '
	SCALL	.SCOUT
	lhld	iocnt
	call	hexwrd
	mvi	a,NL
	SCALL	.SCOUT
	jmp	retout

hxd0:	mvi	a,' '
	call	conout
hxd:	mov	a,m
	call	hexout
	inx	h
	dcr	b
	jnz	hxd0
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
conout:	SCALL	.SCOUT
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
dbren:	db	NL,'.RENAM',' '+200q
dbchf:	db	NL,'.CHFLG',' '+200q
dbsrf:	db	NL,'.SERF',' '+200q
dbsrn:	db	NL,'.SERN',' '+200q
 endif

; .CHFLG... arg2, fqfnl+2 (*)
; E = mask, D = set, HL = file desc
intchf:
	xchg
	shld	arg2	; bits/mask
	lxi	h,arg2
	shld	datptr
	mvi	a,fqfnl+2
	sta	datlen
	xchg		; file desc to HL
	jmp	intdef

; .SERF - DE = buffer, HL = decoded ambiguous file desc
intfrs:	xchg
	shld	dmaadr
	lda	hver
	lxi	h,arg
	mov	m,a
	shld	datptr
	mvi	a,fqfnl+1
	sta	datlen
 if DEBUG
	call	filser
	xchg		; file desc to HL
	jmp	intdf0
 else
	xchg		; file desc to HL
	jmp	intdef
 endif

; .RENAM - two file descs at (DE),(HL)
intren:
	push	h	; old file
	mvi	a,fqfn2l
	sta	datlen
	lxi	h,fqfn
	shld	datptr
	lxi	h,fqfn2
	lxi	b,fqfnl
	call	$MOVE	; copy new file desc
	pop	h	; old file
; check SCALL with file desc and default block
; datptr/datlen must already be set
; also entering here: .SERF, .RENAM, .CHFLG
intdef:	; HL = file desc, datptr,datlen already set
 if DEBUG
	xra	a
	sta	retcod
intdf0:
 endif
	xchg	; DE is source of $MOVE
	lxi	h,fqfn
	lxi	b,fqfnl
	call	$MOVE
	; now check for network dev
	lhld	dvdnm
	xchg
	lhld	fqfn
	call	$CDEHL
	jnz	notnet
	lda	mhdr+FNC
	cpi	.RENAM
	jnz	chkd1
	lhld	fqfn2	; TODO: might be 0000?
	call	$CDEHL
	jnz	notnet
chkd1:
	lda	fqfn+2	; unit number
	call	chkloc
	jc	retout
 if DEBUG
	lda	mhdr+FNC
	cpi	.RENAM
	lxi	h,dbren
	jz	gotit
	cpi	.DELET
	lxi	h,dbdel
	jz	gotit
	cpi	.CHFLG
	lxi	h,dbchf
	jz	gotit
	cpi	.SERN
	lxi	h,dbsrn
	jz	gotit
	lxi	h,dbsrf
gotit:	shld	dbtag
 endif
	call	setrem	; set remote dev name
	jmp	donet

; device not networked error
notnet:	mvi	a,EC.UND
error:	sta	retcod
	jmp	retout

; Check local drive config
; A = unit number
; returns CY if not defined (error).
chkloc:	cpi	'0'
	jc	chkl0
	sui	'0'
chkl0:	add	a
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
	db	0,'SY0'	; NW0 => SY0[00]
	db	1,'SY1'	; NW1 => SY1[01]
	db	2,'SY2'	; NW2 => SY2[02]
	db	3,'SY3'	; NW3 => SY3[03]
	db	4,'SY4'	; NW4 => SY4[04]
	db	5,'SY5'	; NW5 => SY5[05]
	db	6,'SY6'	; NW6 => SY6[06]
	db	7,'SY7'	; NW7 => SY7[07]
; TODO	db	0,'LP5'	; LP0 => LP5[00]

serbuf:	db	'FILE0',0,0,0,'FOO'
	db	0,0
	db	0
	db	0	; flags
	db	0
	dw	55	; FGN/LGN = size
	db	0	; LSI - not used
	dw	3b90H	; create date
	dw	3b9fH	; modify/acces? date

; Check whether to return EC.FNF or 0 for .OPENR
; HL = file spec (e.g. AIO.DIR)
oprchk:	lxi	d,serbuf
	mvi	b,11
oc0:	ldax	d
	cpi	'0'
	jc	oc1
	cpi	'9'+2	; might be ':'
	jc	oc2
oc1:	cmp	m
	mvi	a,EC.FNF
	rnz
oc2:	inx	h
	inx	d
	dcr	b
	jnz	oc0
	xra	a
	ret

; must preserve DE
filser:
	lxi	h,serbuf+4
	mov	a,m
	cpi	'9'+1
	jc	fs0
	mvi	a,EC.EOF
	sta	retcod
	mvi	m,'0'
	ret
fs0:	push	d
	push	h
	lhld	dmaadr
	lxi	d,serbuf
	lxi	b,23
	call	$MOVE
	xra	a
	sta	retcod
	pop	h
	inr	m
	pop	d
	ret

 endif

	end
