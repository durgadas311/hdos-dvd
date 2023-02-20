# Test project to create nddvd.pic which should be equivalent to nd.dvd
.PRECIOUS: %.rel

all: nddvd.pic

%.rel: %.asm
	zmac -i -c -8 -s -n -I../inc --od . --oo rel,lst $*.asm

%.pic: %.rel
	ld80 -o $*.pic -O pic $*.rel

