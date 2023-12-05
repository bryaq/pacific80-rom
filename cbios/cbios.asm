;	Skeletal CBIOS for first level of CP/M 2.0 alteration
;
	maclib	diskdef
;
ccp	equ	0E000h		;base of ccp
bdos	equ	ccp+806h	;base of bdos
bios	equ	ccp+1600h	;base of bios
cdisk	equ	0004h		;current disk number 0=A,...,15=P
iobyte	equ	0003h		;intel i/o byte
;
font	equ	5800h
vram	equ	9800h
scan	equ	4280h
p0p0	equ	0f4h
p0p1	equ	0f5h
p1p0	equ	0f6h
p1p1	equ	0f7h
;	I/O ports
porta	equ	1ah
portc	equ	1ch
ppic	equ	1dh
uartd	equ	28h
uartc	equ	29h
cfdata	equ	30h
cferr	equ	31h
cffeat	equ	31h
cfcount	equ	32h
cflba0	equ	33h
cflba1	equ	34h
cflba2	equ	35h
cflba3	equ	36h
cfstat	equ	37h
cfcmd	equ	37h
bank0	equ	08h
bank1	equ	48h
bank2	equ	88h
bank3	equ	0C8h
;	CF features
cf8bit	equ	01h
cfnocac	equ	82h
;	CF commands
cfrd	equ	20h
cfwr	equ	30h
cfsetft	equ	0EFh
;	MBR
mbrsig1	equ	55h
mbrsig2	equ	0AAh
ptaboff	equ	1BEh
ptablen	equ	16
typcpm	equ	52h
typebr1	equ	05h
typebr2	equ	0Fh
typebr3	equ	85h
;
;*****************************************************
;*                                                   *
;*         CP/M to host disk constants               *
;*                                                   *
;*****************************************************
blksiz	equ	8192		;CP/M allocation size
hstsiz	equ	512		;host disk sector size
hstspt	equ	16		;host disk sectors/trk
hstblk	equ	hstsiz/128	;CP/M sects/host buff
cpmspt	equ	hstblk*hstspt	;CP/M sectors/track
secmsk	equ	hstblk-1	;sector mask
secshf	equ	2		;log2(hstblk)
;
;*****************************************************
;*                                                   *
;*        BDOS constants on entry to write           *
;*                                                   *
;*****************************************************
wrall	equ	0		;write to allocated
wrdir	equ	1		;write to directory
wrual	equ	2		;write to unallocated
;
	org	bios&0FFFh	;origin of this program
	phase	bios
nsects	equ	($-ccp)/hstsiz	;warm start sector count
;
;	jump vector for individual subroutines
	jmp	boot		;cold start
wboote:	jmp	wboot		;warm start
	jmp	const		;console status
	jmp	conin		;console character in
	jmp	conout		;console character out
	jmp	list		;list character out
	jmp	punch		;punch character out
	jmp	reader		;reader character out
	jmp	home		;move head to home position
	jmp	seldsk		;select disk
	jmp	settrk		;set track number
	jmp	setsec		;set sector number
	jmp	setdma		;set dma address
	jmp	read		;read disk
	jmp	write		;write disk
	jmp	listst		;return list status
	jmp	sectran		;sector translate
;
msg:	db	'Pacific-80 CP/M 2.2 CBIOS v.2023-11-27',13,10,0
;
	disks	4
	diskdef	0,0,cpmspt-1,,blksiz,1023,512,0,1
dsk	set	0
	rept	ndisks-1
dsk	set	dsk+1
	diskdef	%dsk,0
	endm
;
;	end of fixed tables
;
reboot:	mvi	a,0ffh		;ROM page
	out	bank0
	rst	0
;
;	individual subroutines to perform each function
boot:	;simplest case is to just perform parameter initialization
	mvi	a,0f0h		;RAM page 0
	out	bank0
	mvi	a,0ffh		;ROM page
	out	bank1
	mvi	a,0bah		;PORTA mode 1 in, PORTB mode 0 in, PC6-PC7 in, PC0-PC2 out
	out	ppic
	xra	a		;zero in the accum
	out	ppic		;PC0=0
	sta	iobyte		;clear the iobyte
	sta	cdisk		;select disk zero
	lxi	sp,80h		;use space below buffer for stack
	call	cls
	lxi	h,msg
prmsg:	mov	c,m
	xra	a		;zero in the accum
	cmp	c
	jz	cfinit
	push	h
	call	conout
	pop	h
	inx	h
	jmp	prmsg
;
cfinit:
	call	cfwait
	mvi	a,cf8bit	;8-bit access
	out	cffeat
	mvi	a,cfsetft
	out	cfcmd
	call	cfwait
	mvi	a,cfnocac	;disable write cache
	out	cffeat
	mvi	a,cfsetft
	out	cfcmd
	call	cfwait
	mvi	a,0E0h		;LBA mode
	out	cflba3
;
	lxi	b,0100h		;one sector
	lxi	h,0
	call	cflba		;MBR
	lxi	h,hstbuf
	call	cfread
	dcx	h
	mov	a,m
	cpi	mbrsig2		;0AAh
	jnz	reboot		;no valid MBR signature
	dcx	h
	mov	a,m
	cpi	mbrsig1		;55h
	jnz	reboot		;no valid MBR signature
;
	xra	a
	mvi	b,ndisks*3+1
	lxi	h,nparts
ptab0:	mov	m,a		;zero nparts and ptab
	dcr	b
	jnz	ptab0

	mvi	a,4
	push	psw
	lxi	d,ptab
	lxi	b,0
	lxi	h,hstbuf+ptaboff
mbrloop:
	mov	a,m		;status 00h or 80h
	ora	a		;carry = 0
	ral
	mvi	c,ptablen
	jnz	nxtmbr
	mvi	c,4
	dad	b
	mov	a,m		;partition type
	cpi	typcpm
	mvi	c,ptablen-4
	jnz	nxtmbr
	mvi	c,4
	dad	b
	mov	a,m
	stax	d
	inx	d
	inx	h
	mov	a,m
	stax	d
	inx	d
	inx	h
	mov	a,m
	stax	d
	inx	d
	mvi	c,ptablen-8-2
	lda	nparts
	inr	a
	sta	nparts
	cpi	ndisks
	jz	endmbr
nxtmbr:	pop	psw
	dcr	a
	push	psw
	jz	endmbr
	dad	b
	jmp	mbrloop
endmbr:	pop	psw
	lda	nparts
	ora	a
	jz	reboot
;
wboot:	;simplest case is to read the disk until all sectors loaded
	di
	mvi	a,0f1h		;RAM page 1
	out	bank1
	inr	a		;RAM page 2
	out	bank2
	lxi	sp,80h		;use space below buffer for stack
	xra	a
	out	ppic		;PC0=0
	sta	hstdsk
	sta	hsttrk
	sta	hsttrk+1
	sta	hstsec
	call	calclba
	mvi	b,nsects
	call	cflba
	lxi	h,ccp
	call	cfread
;
;	end of load operation, set parameters and go to cp/m
gocpm:
	xra	a		;0 to accumulator
	sta	hstact		;host buffer inactive
	sta	unacnt		;clear unalloc count
;
	mvi	a,0C3h		;C3 is a jmp instruction
	sta	0		;for jmp to wboot
	lxi	h,wboote	;wboot entry point
	shld	1		;set address field for jmp at 0
;
	sta	5		;for jmp to bdos
	lxi	h,bdos		;bdos entry point
	shld	6		;address field of jump at 5 to bdos
;
	lxi	b,0080h		;default dma address is 0080h
	call	setdma
;
	lda	cdisk		;get current disk number
	mov	c,a		;send to the ccp
	jmp	ccp		;go to cp/m for further processing
;
;	simple i/o handlers (must be filled in by user)
;	in each case, the entry point is provided, with space reserved
;	to insert your own code
;
const:	;console status, return 0FFh if character ready, 00h if not
	lda	kst
	ora	a
	rnz
	lda	next
	ora	a
	mvi	a,0FFh
	rnz
	in	bank1
	sta	b1sav
	mvi	a,0FFh
	out	bank1
	call	kin
	mov	c,a
	sta	kbuf
	lda	b1sav
	out	bank1
	mov	a,c
	rz
	mvi	a,0FFh
	sta	kst
	ret
;
conin:	;console character into register a
	lda	kst
	inr	a
	jnz	conin1
	sta	kst
	lda	kbuf
;	ani	7Fh		;strip parity bit
	ret
conin1:	lda	next
	ora	a
	jz	conin2
	mov	c,a
	xra	a
	sta	next
	mov	a,c
;	ani	7Fh		;strip parity bit
	ret
conin2:	in	bank1
	sta	b1sav
	mvi	a,0FFh
	out	bank1
conin3:	call	kin
	jz	conin3
	mov	c,a
	lda	b1sav
	out	bank1
	mov	a,c
;	ani	7Fh		;strip parity bit
	ret
;
conout: ;console character output from register c
	in	bank1
	sta	b1sav
	in	bank2
	sta	b2sav
	mvi	a,0FFh
	out	bank1
	call	putc
	lda	b1sav
	out	bank1
	lda	b2sav
	out	bank2
	ret
;
list:	;list character from register c
	mov	a,c		;character to register a
	ret			;null subroutine
;
listst:	;return list status (0 if not ready, 1 if ready)
	xra	a		;0 is always ok to return
	ret
;
reader: ;read character into register a from reader device
	in	uartc
	ani	02h
	rz			;return with Z set for XMODEM timeout feature
	in	uartd
	ret			;do not strip parity bit for XMODEM
;
punch:	;punch character from register c
	in	uartc
	rrc
	jnc	punch
	mov	a,c		;get to accumulator
	out	uartd
	ret
;
;
;	i/o drivers for the disk follow
;	for now, we will simply store the parameters away for use
;	in the read and write subroutines
;
seldsk:	;select disk given by register C
	lxi	h,nparts
	mov	a,c		;selected disk number
	cmp	m
	lxi	h,0000h		;error return code
	jc	dskok
	lda	cdisk
	cmp	c
	rnz
	xra	a		;revert to A:
	sta	cdisk
	sta	sekdsk
	ret
dskok:
;	disk number is in the proper range
	sta	sekdsk		;seek disk number
;	compute proper disk parameter header address
	rept	4		;multiply by 16
	add	a
	endm
	mov	l,a		;(disk number)*16 to HL
	lxi	d,dpbase	;base of parm block
	dad	d		;hl=.dpb(curdsk)
	ret
;
home:	;move to the track 00 position of current drive
;	translate this call into a settrk call with parameter 00
	lda	hstwrt	;check for pending write
	ora	a
	jnz	homed
	sta	hstact		;clear host active flag
homed:
	lxi	b,0		;select track 0
;
settrk:	;set track given by registers BC
	mov	h,b
	mov	l,c
	shld	sektrk		;track to seek
	ret
;
setsec:	;set sector given by register c
	mov	a,c
	sta	seksec		;sector to seek
	ret
;
sectran:
	;translate the sector given by BC using the
	;translate table given by DE
	mov	h,b
	mov	l,c
	ret			;with value in HL
;
setdma:	;set dma address given by registers b and c
	mov	h,b		;high order address
	mov	l,c		;low order address
	shld	dmaadr		;save the address
	ret
;
;*****************************************************
;*                                                   *
;*	The READ entry point takes the place of      *
;*	the previous BIOS defintion for READ.        *
;*                                                   *
;*****************************************************
read:
	;read the selected CP/M sector
	xra	a
	sta	unacnt
	mvi	a,1
	sta	readop		;read operation
	sta	rsflag		;must read data
	mvi	a,wrual
	sta	wrtype		;treat as unalloc
	jmp	rwoper		;to perform the read
;
;*****************************************************
;*                                                   *
;*	The WRITE entry point takes the place of     *
;*	the previous BIOS defintion for WRITE.       *
;*                                                   *
;*****************************************************
write:
	;write the selected CP/M sector
	xra	a		;0 to accumulator
	sta	readop		;not a read operation
	mov	a,c		;write type in c
	sta	wrtype
	cpi	wrual		;write unallocated?
	jnz	chkuna		;check for unalloc
;
;	write to unallocated, set parameters
	mvi	a,blksiz/128	;next unalloc recs
	sta	unacnt
	lda	sekdsk		;disk to seek
	sta	unadsk		;unadsk = sekdsk
	lhld	sektrk
	shld	unatrk		;unatrk = sectrk
	lda	seksec
	sta	unasec		;unasec = seksec
;
chkuna:
	;check for write to unallocated sector
	lda	unacnt		;any unalloc remain?
	ora	a
	jz	alloc		;skip if not
;
;	more unallocated records remain
	dcr	a		;unacnt = unacnt-1
	sta	unacnt
	lda	sekdsk		;same disk?
	lxi	h,unadsk
	cmp	m		;sekdsk = unadsk?
	jnz	alloc		;skip if not
;
;	disks are the same
	lxi	h,unatrk
	call	sektrkcmp	;sektrk = unatrk?
	jnz	alloc		;skip if not
;
;	tracks are the same
	lda	seksec		;same sector?
	lxi	h,unasec
	cmp	m		;seksec = unasec?
	jnz	alloc		;skip if not
;
;	match, move to next sector for future ref
	inr	m		;unasec = unasec+1
	mov	a,m		;end of track?
	cpi	cpmspt		;count CP/M sectors
	jc	noovf		;skip if no overflow
;
;	overflow to next track
	mvi	m,0		;unasec = 0
	lhld	unatrk
	inx	h
	shld	unatrk		;unatrk = unatrk+1
;
noovf:
	;match found, mark as unnecessary read
	xra	a		;0 to accumulator
	sta	rsflag		;rsflag = 0
	jmp	rwoper		;to perform the write
;
alloc:
	;not an unallocated record, requires pre-read
	xra	a		;0 to accum
	sta	unacnt		;unacnt = 0
	inr	a		;1 to accum
	sta	rsflag		;rsflag = 1
;
;*****************************************************
;*                                                   *
;*	Common code for READ and WRITE follows       *
;*                                                   *
;*****************************************************
rwoper:
	;enter here to perform the read/write
	xra	a		;zero to accum
	sta	erflag		;no errors (yet)
	lda	seksec		;compute host sector
	rept	secshf
	ora	a		;carry = 0
	rar			;shift right
	endm
	sta	sekhst		;host sector to seek
;
;	active host sector?
	lxi	h,hstact	;host active flag
	mov	a,m
	mvi	m,1		;always becomes 1
	ora	a		;was it already?
	jz	filhst		;fill host if not
;
;	host buffer active, same as seek buffer?
	lda	sekdsk
	lxi	h,hstdsk	;same disk?
	cmp	m		;sekdsk = hstdsk?
	jnz	nomatch
;
;	same disk, same track?
	lxi	h,hsttrk
	call	sektrkcmp	;sektrk = hsttrk?
	jnz	nomatch
;
;	same disk, same track, same buffer?
	lda	sekhst
	lxi	h,hstsec	;sekhst = hstsec?
	cmp	m
	jz	match		;skip if match
;
nomatch:
	;proper disk, but not correct sector
	lda	hstwrt		;host written?
	ora	a
	cnz	writehst	;clear host buff
;
filhst:
	;may have to fill the host buffer
	lda	sekdsk
	sta	hstdsk
	lhld	sektrk
	shld	hsttrk
	lda	sekhst
	sta	hstsec
	lda	rsflag		;need to read?
	ora	a
	cnz	readhst		;yes, if 1
	xra	a		;0 to accum
	sta	hstwrt		;no pending write
;
match:
	;copy data to or from buffer
	lda	seksec		;mask buffer number
	ani	secmsk		;least signif bits
	mov	l,a		;ready to shift
	mvi	h,0		;double count
	rept	7		;shift left 7
	dad	h
	endm
;	hl has relative host buffer address
	lxi	d,hstbuf
	dad	d		;hl = host address
	xchg			;now in DE
	lhld	dmaadr		;get/put CP/M data
	mvi	c,128		;length of move
	lda	readop		;which way?
	ora	a
	jnz	rwmove		;skip if read
;
;	write operation, mark and switch direction
	mvi	a,1
	sta	hstwrt		;hstwrt = 1
	xchg			;source/dest swap
;
rwmove:
	;C initially 128, DE is source, HL is dest
	ldax	d		;source character
	inx	d
	mov	m,a		;to dest
	inx	h
	dcr	c		;loop 128 times
	jnz	rwmove
;
;	data has been moved to/from host buffer
	lda	wrtype		;write type
	cpi	wrdir		;to directory?
	lda	erflag		;in case of errors
	rnz			;no further processing
;
;	clear host buffer for directory write
	ora	a		;errors?
	rnz			;skip if so
	xra	a		;0 to accum
	sta	hstwrt		;buffer written
	call	writehst
	lda	erflag
	ret
;
;*****************************************************
;*                                                   *
;*	Utility subroutine for 16-bit compare        *
;*                                                   *
;*****************************************************
sektrkcmp:
	;HL = .unatrk or .hsttrk, compare with sektrk
	xchg
	lxi	h,sektrk
	ldax	d		;low byte compare
	cmp	m		;same?
	rnz			;return if not
;	low bytes equal, test high 1s
	inx	d
	inx	h
	ldax	d
	cmp	m		;sets flags
	ret
;
;*****************************************************
;*                                                   *
;*	WRITEHST performs the physical write to      *
;*	the host disk, READHST reads the physical    *
;*	disk.					     *
;*                                                   *
;*****************************************************
writehst:
	;hstdsk = host disk #, hsttrk = host track #,
	;hstsec = host sect #. write "hstsiz" bytes
	;from hstbuf and return error flag in erflag.
	;return erflag non-zero if error
	call	calclba
	mvi	b,1
	call	cflba
	lxi	h,hstbuf
	call	cfwrit
	in	cfstat
	ani	01h		;ERR
	sta	erflag
	ret
;
readhst:
	;hstdsk = host disk #, hsttrk = host track #,
	;hstsec = host sect #. read "hstsiz" bytes
	;into hstbuf and return error flag in erflag.
	call	calclba
	mvi	b,1
	call	cflba
	lxi	h,hstbuf
	call	cfread
	in	cfstat
	ani	01h		;ERR
	sta	erflag
	ret
;
calclba:
	lhld	hsttrk
	rept	4
	dad	h		;multiply by 16
	endm
	lda	hstsec
	mvi	b,0
	mov	c,a
	dad	b
	lda	hstdsk
	mov	c,a
	add	c
	add	c
	mov	c,a		;hstdsk*3
	xchg
	lxi	h,ptab
	dad	b
	mov	c,m		;lba0 of partition start
	inx	h
	mov	b,m		;lba1 of partition start
	inx	h
	mov	a,m		;lba2 of partition start
	xchg
	dad	b
	aci	0
	mov	c,a
	ret
;
cfwait:
	in	cfstat
	rlc
	jc	cfwait
	ret
;
cflba:	;24-bit LBA in C:H:L, count in B
	call	cfwait
	mov	a,b
	out	cfcount
	mov	a,l
	out	cflba0
	mov	a,h
	out	cflba1
	mov	a,c
	out	cflba2
	ret
;
cfread:	;read to (HL)
	mvi	a,cfrd
	out	cfcmd
rdloop:	call	cfwait
	in	cfstat
	ani	08h		;DRQ
	rz
	in	cfdata
	mov	m,a
	inx	h
	jmp	rdloop
;
cfwrit:	;write from (HL)
	mvi	a,cfwr
	out	cfcmd
wrloop:	call	cfwait
	in	cfstat
	ani	08h		;DRQ
	rz
	mov	a,m
	out	cfdata
	inx	h
	jmp	wrloop
;
	dephase
	org	00AF2h
	phase	0FAF2h
curpos:	dw	vram+10h
cury	equ	curpos
curx	equ	curpos+1
cursav:	dw	vram+10h
cursor:	db	0ffh
prevc:	db	0,0
plen:	db	0
rev:	db	0
wrap:	db	1
next:	db	0
modif:	db	0
kbuf:	db	0
kst:	db	0
;
endb	equ	$
	dephase
	org	endb
;
;	the remainder of the CBIOS is reserved uninitialized
;	data area, and does not need to be a part of the
;	system memory image (the space must be available,
;	however, between "begdat" and "enddat").
;
b1sav:	ds	1		;bank1 save
b2sav:	ds	1		;bank2 save
;
nparts:	ds	1		;number of CP/M partitions in MBR
ptab:	ds	ndisks*3	;partition table
;
sekdsk:	ds	1		;seek disk number
sektrk:	ds	2		;seek track number
seksec:	ds	1		;seek sector number
;
hstdsk:	ds	1		;host disk number
hsttrk:	ds	2		;host track number
hstsec:	ds	1		;host sector number
;
sekhst:	ds	1		;seek shr secshf
hstact:	ds	1		;host active flag
hstwrt:	ds	1		;host written flag
;
unacnt:	ds	1		;unalloc rec cnt
unadsk:	ds	1		;last unalloc disk
unatrk:	ds	2		;last unalloc track
unasec:	ds	1		;last unalloc sector
;
erflag:	ds	1		;error reporting
rsflag:	ds	1		;read sector flag
readop:	ds	1		;1 if read operation
wrtype:	ds	1		;write operation type
dmaadr:	ds	2		;last dma address
hstbuf:	ds	hstsiz		;host buffer
;
;	scratch ram area for BDOS use
	endef

	org	endb&0FFFh
	phase	endb&0FFFh|4000h

clp:	lxi	h,vram
clp1:	xra	a
	mvi	c,32
clp2:	call	setcol
	dcr	c
	jnz	clp2
	inr	h
	mov	a,h
	cpi	high(vram)+40
	jnz	clp1
	ret

cls:	mvi	a,p0p1
	out	bank2
	call	clp
	mvi	a,p0p0
	out	bank2
	call	clp
	lhld	curpos
	lda	cursor

setcol:	mov	m,a
	inr	l
	mov	m,a
	inr	l
	mov	m,a
	inr	l
	mov	m,a
	inr	l
	mov	m,a
	inr	l
	mov	m,a
	inr	l
	mov	m,a
	inr	l
	mov	m,a
	inr	l
	ret

cpycol:	mov	a,m
	xra	b
	stax	d
	inx	h
	inr	e
	mov	a,m
	xra	b
	stax	d
	inx	h
	inr	e
	mov	a,m
	xra	b
	stax	d
	inx	h
	inr	e
	mov	a,m
	xra	b
	stax	d
	inx	h
	inr	e
	mov	a,m
	xra	b
	stax	d
	inx	h
	inr	e
	mov	a,m
	xra	b
	stax	d
	inx	h
	inr	e
	mov	a,m
	xra	b
	stax	d
	inx	h
	inr	e
	mov	a,m
	xra	b
	stax	d
	inx	h
	inr	e
	dcr	c
	jnz	cpycol
	ret

bpycol:	dcx	h
	dcr	e
	mov	a,m
	xra	b
	stax	d
	dcx	h
	dcr	e
	mov	a,m
	xra	b
	stax	d
	dcx	h
	dcr	e
	mov	a,m
	xra	b
	stax	d
	dcx	h
	dcr	e
	mov	a,m
	xra	b
	stax	d
	dcx	h
	dcr	e
	mov	a,m
	xra	b
	stax	d
	dcx	h
	dcr	e
	mov	a,m
	xra	b
	stax	d
	dcx	h
	dcr	e
	mov	a,m
	xra	b
	stax	d
	dcx	h
	dcr	e
	mov	a,m
	xra	b
	stax	d
	dcr	c
	jnz	bpycol
	ret

lfeed:	lda	cury
	cpi	0f8h
	jnz	mcurd
	mvi	a,10h
	sta	cury
	call	scrlu
	mvi	a,0f8h
	sta	cury
	ret

dline:	call	mcurs

scrlu:	mvi	a,p0p1
	out	bank2
	mvi	h,high(vram)
	mov	d,h
	mvi	b,0
scrlu1:	lda	cury
	mov	e,a
	adi	8
	mov	l,a
	sui	18h
	rrc
	rrc
	rrc
	cma
	inr	a
	adi	29
	jz	scrlu2
	mov	c,a
	call	cpycol
scrlu2:	xra	a
	xchg
	call	setcol
	xchg
	inr	d
	mov	h,d
	mov	a,d
	cpi	high(vram)+40
	jnz	scrlu1
	ret

rlfeed:	lda	cury
	cpi	10h
	jnz	mcuru

scrld:	mvi	a,p0p1
	out	bank2
	mvi	h,high(vram)
	mov	d,h
	mvi	b,0
scrld1:	mvi	l,0f8h
	mvi	e,0
	lda	cury
	sui	10h
	rrc
	rrc
	rrc
	cma
	inr	a
	adi	29
	jz	scrld2
	mov	c,a
	call	bpycol
scrld2:	xra	a
	call	setcol
	inr	d
	mov	h,d
	mov	a,d
	cpi	high(vram)+40
	jnz	scrld1
	ret

iline:	call	scrld
	jmp	mcurs

eesc:	dcr	a
	sta	plen
	cpi	1
	jz	eesc1
	lda	prevc
	cpi	'Y'
	jz	mcura
	ret

eesc1:	mov	a,c
	sta	prevc+1
	ret

escy:	mvi	a,2
	sta	plen
	ret

esc:	mov	a,c
	sta	prevc
	cpi	'B'
	jz	mcurd
	cpi	'I'
	jz	rlfeed
	cpi	'A'
	jz	mcuru
	cpi	'C'
	jz	mcurr
	cpi	'D'
	jz	mcurl
	cpi	'H'
	jz	mcurh
	cpi	'Y'
	jz	escy
	cpi	'K'
	jz	eteol
	cpi	'J'
	jz	eteos
	cpi	'p'
	jz	rvid
	cpi	'q'
	jz	nvid
	cpi	'L'
	jz	iline
	cpi	'M'
	jz	dline
	cpi	'e'
	jz	ecur
	cpi	'f'
	jz	dcur
	cpi	'j'
	jz	scur
	cpi	'k'
	jz	rcur
	cpi	'v'
	jz	ewrap
	cpi	'w'
	jz	dwrap
	cpi	'E'
	jz	ecls
	ret

putc:	lda	plen
	ora	a
	jnz	eesc
	lda	prevc
	cpi	1bh
	jz	esc
	mov	a,c
	sta	prevc
	cpi	20h
	jnc	putc1
	cpi	0ah
	jz	lfeed
	cpi	08h
	jz	mcurl
	cpi	0dh
	jz	mcurs
	cpi	09h
	jz	mcurt
	ret
putc1:	cpi	7fh
	rz

putcc:	lhld	curpos
	xchg
	mov	l,a
	mvi	h,0
	dad	h
	dad	h
	dad	h
	lxi	b,font
	dad	b
	mvi	a,p0p1
	out	bank2
	lda	rev
	mov	b,a
	mvi	c,1
	call	cpycol

mcurw:	lhld	curpos
	mov	a,h
	cpi	high(vram)+39
	jnz	mcurr1
	lda	wrap
	ora	a
	rz
	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	cmp	l
	jnz	mcurw1
	mvi	a,10h
	sta	cury
	call	scrlu
	mvi	a,p0p0
	out	bank2
	mvi	l,0f8h
mcurw1:	mvi	h,high(vram)
	shld	curpos
	lda	cursor
	jmp	setcol

mcurr:	lhld	curpos
	mov	a,h
	cpi	high(vram)+39
	rz
mcurr1:	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	lhld	curpos
	inr	h
	shld	curpos
	lda	cursor
	jmp	setcol

mcurl:	lhld	curpos
	mov	a,h
	cpi	high(vram)
	rz
	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	lhld	curpos
	dcr	h
	shld	curpos
	lda	cursor
	jmp	setcol

mcurs:	lhld	curpos
	mov	a,h
	cpi	high(vram)
	rz
	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	lhld	curpos
	mvi	h,high(vram)
	shld	curpos
	lda	cursor
	jmp	setcol

mcurt:	lhld	curpos
	mov	a,h
	cpi	high(vram)+32
	jnc	mcurr
	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	lhld	curpos
	mov	a,h
	ani	0f8h
	adi	08h
	mov	h,a
	shld	curpos
	lda	cursor
	jmp	setcol

mcurd:	lhld	curpos
	mov	a,l
	cpi	0f8h
	rz
	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	shld	curpos
	lda	cursor
	jmp	setcol

mcuru:	lhld	curpos
	mov	a,l
	cpi	10h
	rz
	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	mov	a,l
	sui	16
	mov	l,a
	sta	cury
	lda	cursor
	jmp	setcol

mcurh:	lhld	curpos
	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	lxi	h,vram+10h
	shld	curpos
	lda	cursor
	jmp	setcol

mcura:	lhld	curpos
	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	lda	prevc+1
	sui	32
	cpi	30
	jnc	mcura1
	rlc
	rlc
	rlc
	adi	10h
	sta	cury
mcura1:	mov	a,c
	sui	32
	cpi	40
	jc	mcura2
	mvi	a,39
mcura2:	adi	high(vram)
	sta	curx
	lhld	curpos
	lda	cursor
	jmp	setcol

ecur:	mvi	a,0ffh
	sta	cursor
	lhld	curpos
	jmp	setcol

dcur:	xra	a
	sta	cursor
	lhld	curpos
	jmp	setcol

scur:	lhld	curpos
	shld	cursav
	ret

rcur:	lhld	curpos
	mvi	a,p0p0
	out	bank2
	xra	a
	call	setcol
	lhld	cursav
	shld	curpos
	lda	cursor
	jmp	setcol

eteol:	lhld	curpos
	mvi	a,high(vram)+40
	sub	h
	mov	c,a
	mov	b,l
	mvi	a,p0p1
	out	bank2
	xra	a
eteol1:	call	setcol
	inr	h
	mov	l,b
	dcr	c
	jnz	eteol1
	ret

ecls:	call	mcurh
eteos:	lhld	curpos
	mvi	a,high(vram)+40
	sub	h
	mov	c,a
	mvi	a,p0p1
	out	bank2
eteos1:	xra	a
	mov	b,l
eteos2:	call	setcol
	inr	h
	mov	l,b
	dcr	c
	jnz	eteos2
	mov	a,l
	cpi	0f8h
	rz
	adi	8
	mov	l,a
	mvi	h,high(vram)
	mvi	c,40
	jmp	eteos1

rvid:	mvi	a,0ffh
	sta	rev
	ret

nvid:	xra	a
	sta	rev
	ret

dwrap:	xra	a
ewrap:	sta	wrap
	ret

kin:	in	portc
	ani	20h
	rz
	in	porta
	rlc
	jc	krel
	rrc
	cpi	1dh
	jz	kcon
	cpi	2ah
	jz	kson
	cpi	36h
	jz	kson
	cpi	38h
	jz	kaon
	mvi	b,0
	mov	c,a
	lxi	h,scan+300h
	dad	b
	mov	a,m
	ora	a
	jz	kin1
	sta	next
	mvi	a,1bh
	ret
kin1:	lxi	h,scan
	dad	b
	lxi	b,80h
	lda	modif
	rrc
	jc	kctrl
	rrc
	jnc	kin2
	inr	b
	dad	b
	dcr	b
kin2:	mov	e,b
	rrc
	jnc	kin3
	mov	e,m
kin3:	rrc
	jnc	kin4
	dad	b
kin4:	dad	b
	mov	a,m
	xra	e
	rnz
	jmp	kin

krel:	rrc
	cpi	9dh
	jz	kcoff
	cpi	0aah
	jz	ksoff
	cpi	0b6h
	jz	ksoff
	cpi	0b8h
	jz	kaoff
	cpi	0bah
	jz	kcaps
	cpi	0c6h
	jz	klt
	cpi	0d3h
	jz	krst
	jmp	kin

kcoff:	lda	modif
	ani	~01h
	sta	modif
	jmp	kin

ksoff:	lda	modif
	ani	~08h
	sta	modif
	jmp	kin

kaoff:	lda	modif
	ani	~10h
	sta	modif
	jmp	kin

kcon:	lda	modif
	ori	01h
	sta	modif
	jmp	kin

kson:	lda	modif
	ori	08h
	sta	modif
	jmp	kin

kaon:	lda	modif
	ori	10h
	sta	modif
	jmp	kin

kcaps:	lda	modif
	xri	04h
	sta	modif
	jmp	kin

klt:	lda	modif
	xri	02h
	sta	modif
	jmp	kin

krst:	lda	modif
	ani	11h
	cpi	11h
	jnz	kin
	rst	0

kctrl:	ani	04h
	jnz	kctrl1
	dad	b
kctrl1:	dad	b
	mov	a,m
	ora	a
	jz	kin
	ani	1fh
	mov	c,a
	inr	c		;clear Z flag
	ret

	dephase
	end
