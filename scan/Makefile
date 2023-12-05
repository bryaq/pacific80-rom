NAME=scan

.PHONY: all clean

all: $(NAME).cim

scan.cim: scan_koi8-r.asm
	zmac --zmac -8 -o $@ $<

scan_koi8-r.asm: scan.asm
	iconv -t koi8-r -o $@ $<

clean:
	rm -f scan_koi8-r.asm *.cim
