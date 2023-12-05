MON=gwmon-80/smpac80.hex
SCAN=scan/scan.cim
CBIOS=cbios/cbios.hex
FONT=font/BmPlus_IBM_BIOS.f08

.PHONY: all clean prog

all: 27c512.hex 27c256.hex 27c128.hex 27c64.hex

$(MON):
	make -C gwmon-80 smpac80

$(SCAN):
	make -C scan

$(CBIOS):
	make -C cbios

$(FONT):
	make -C font

27c512.hex: $(MON) $(SCAN) $(CBIOS) $(FONT)
	srec_cat -o $@ -intel -address-length=2 -output_block_packing $(MON) -intel -offset 0xc000 $(SCAN) -binary -offset 0xc280 $(CBIOS) -intel -offset 0xc000 $(FONT) -binary -offset 0xd800

27c256.hex: $(MON) $(SCAN) $(CBIOS) $(FONT)
	srec_cat -o $@ -intel -address-length=2 -output_block_packing $(MON) -intel -offset 0x4000 $(SCAN) -binary -offset 0x4280 $(CBIOS) -intel -offset 0x4000 $(FONT) -binary -offset 0x5800

27c128.hex: $(MON) $(SCAN) $(CBIOS) $(FONT)
	srec_cat -o $@ -intel -address-length=2 -output_block_packing $(MON) -intel $(SCAN) -binary -offset 0x0280 $(CBIOS) -intel $(FONT) -binary -offset 0x1800

27c64.hex: $(MON) $(SCAN) $(CBIOS) $(FONT)
	srec_cat -o $@ -intel -address-length=2 -output_block_packing $(MON) -intel $(SCAN) -binary -offset 0x0280 $(CBIOS) -intel $(FONT) -binary -offset 0x1800

prog: 27c512.hex
	minipro -p W27C512@DIP28 -w $<

clean:
	rm -f *.hex
	make -C gwmon-80 clean
	make -C scan clean
	make -C cbios clean
	make -C font clean
