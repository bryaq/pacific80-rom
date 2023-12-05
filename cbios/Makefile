NAME=cbios

.PHONY: all clean

all: $(NAME).lst $(NAME).hex

%.lst: %.asm
	zmac -8 -o $@ $<

%.hex: %.asm
	zmac -8 -o $@ $<

ram.hex: $(NAME).hex
	srec_cat -o $@ -intel -address-length=2 -output_block_packing $< -intel -offset 0xf000

clean:
	rm -f $(NAME).lst $(NAME).hex
