# Test project to create exploritory driver
.PRECIOUS: %.rel

all: zzdvd.pic

%.rel: %.asm
	zmac -i -c -8 -s -n -I../inc --od . --oo rel,lst $*.asm

%.pic: %.rel
	ld80 -o $*.pic -O pic $*.rel

