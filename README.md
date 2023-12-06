# BUILD

You'll need

- [A85 assembler](https://github.com/glitchwrks/a85)
- [ZMAC assembler](http://48k.ca/zmac.html)
- [monobit font converter](https://github.com/robhagemans/monobit)
- `make`, `srecored`, `iconv` from your distribution's package repository

# INSTALL

Burn either 27c512.hex, 27c256.hex, 27c128.hex or 27c64.hex to your EPROM chip.

# USE

## CP/M disk format

CBIOS expects CF card to be formatted with MBR using LBR addressing and up to 4 primary partions of type `52h` and size up to 8MB each. First 'track' of a partiotion is sytem track, put CCP+BDOS there, so CP/M can boot. You can access filesystem on these partitions or partition images from PC using either

- [cpmtools](http://www.moria.de/~michael/cpmtools/)
- [cpmfuse](http://www.nyangau.org/cpmfuse/cpmfuse.htm)
- [cpmcbfs](http://www.nyangau.org/cpmcbfs/cpmcbfs.htm)

`cpmtools`-compatible disk definition:
```
diskdef pac80
  seclen 512
  tracks 1024
  sectrk 16
  blocksize 8192
  maxdir 512
  skew 0
  boottrk 1
  os 2.2
end
```

## MEMORY MAP

256K memory space is divided to 16 16KB-pages. 64KB CPU address space is divided to 4 16KB-banks. Each bank can be mapped to any page. After reset all banks are mapped to page 0. Video memory starts at 1810h offset in each video page/plane. Column 0 at 1810h-18ffh, column 1 at 1910h-19ffh, and so on, total 40 columns. Plane 0 color is navy blue, plane 1 color is sand, both planes together give white.

|Page|Type|Notes                            |
|----|----|---------------------------------|
|0   |RAM |                                 |
|1   |RAM |                                 |
|2   |RAM |                                 |
|3   |RAM |                                 |
|4   |RAM |video page 0 plane 0 at 1810-3fff|
|5   |RAM |video page 0 plane 1 at 1810-3fff|
|6   |RAM |video page 1 plane 0 at 1810-3fff|
|7   |RAM |video page 1 plane 1 at 1810-3fff|
|8   |RAM |optional                         |
|9   |RAM |optional                         |
|a   |RAM |optional                         |
|b   |RAM |optional                         |
|c   |RAM |optional                         |
|d   |RAM |optional                         |
|e   |RAM |optional                         |
|f   |ROM |                                 |

## I/O PORTS

|Port |Assigned to        |
|-----|-------------------|
|00-07|EXT0               |
|10-17|EXT1               |
|20-27|EXT2               |
|30-37|CF                 |
|08   |BANK0              |
|48   |BANK1              |
|88   |BANK2              |
|c8   |BANK3              |
|1a   |PPI PORT A         |
|1b   |PPI PORT B (SEL=1) |
|19   |PPI PORT B (SEL=0) |
|1c   |PPI PORT C         |
|1d   |PPI CONTROL        |
|28   |UART DATA          |
|29   |UART CONTROL/STATUS|
|38   |PSG                |

## 8255 ports

|   |Function|SEL=0|SEL=1|2nd 0|2nd 1|3rd 0|3rd 1|4th 0|4th 1|
|---|--------|-----|-----|-----|-----|-----|-----|-----|-----|
|PB0|gamepad |UP   |UP   |UP   |UP   |0    |Z    |1    |UP   |
|PB1|gamepad |DOWN |DOWN |DOWN |DOWN |0    |Y    |1    |DOWN |
|PB2|gamepad |0    |LEFT |0    |LEFT |0    |X    |1    |LEFT |
|PB3|gamepad |0    |RIGHT|0    |RIGHT|0    |MODE |1    |RIGHT|
|PB4|gamepad |A    |B    |A    |B    |A    |B    |A    |B    |
|PB5|gamepad |START|C    |START|C    |START|C    |START|C    |
|PB6|gamepad |0    |1    |0    |1    |0    |1    |0    |1    |
|PB7|always=1|1    |1    |1    |1    |1    |1    |1    |1    |

|   |WRITE                    |READ                      |
|---|-------------------------|--------------------------|
|PC0|video page               |video page                |
|PC1|VBLANK interrupt enable  |VBLANK interrupt enable   |
|PC2|UART interrupt enable    |UART interrupt enable     |
|PC3|                         |keyboard interrupt request|
|PC4|keyboard interrupt enable|keyboard strobe           |
|PC5|                         |keyboard input buffer full|
|PC6|                         |VBLANK interrupt request  |
|PC7|                         |UART interrupt request    |
