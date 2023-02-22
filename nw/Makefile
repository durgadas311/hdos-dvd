# Network device driver for H8-SPI WizNET

.PRECIOUS: %.rel

all: nwdvd.pic

%.rel: %.asm
	zmac -i -c -8 -s -n -I../inc --od . --oo rel,lst $*.asm

%.pic: %.rel
	ld80 -o $*.pic -O pic $*.rel

#nwdvd.pic: nwdvd.rel snioswiz.rel
#	ld80 -o nwdvd.pic -O pic nwdvd.rel snioswiz.rel
