NAME=BmPlus_IBM_BIOS

.PHONY: all clean

all: $(NAME).f08

$(NAME).f08: $(NAME).yaff
	monobit-convert $< to $@

clean:
	rm -f $(NAME).f08
