.PHONY: all clean

NAME=intro
RES=res/music.c64 res/arleka_font_caren_remix0A_invert-charset.bin

all: $(NAME).prg

run: $(NAME).prg
	x64sc $(NAME).prg

$(NAME).prg: $(NAME).s $(RES)
	cl65 -o $(NAME).prg -u __EXEHDR__ -t c64 -C c64-asm.cfg $(NAME).s

$(NAME)-alz.prg: $(NAME).prg
	wine alz64.exe -s $(NAME).prg $(NAME)-alz.prg

# Processed resources
res/arleka_font_caren_remix0A_invert-charset.bin: res/arleka_font_caren_remix0A-charset.bin
	python scripts/invert.py $< $@

res/music.c64: res/mass_media.sid
	sidreloc -p 80 $< tmp.sid
	dd if=tmp.sid of=$@ bs=1 skip=124
	rm -f tmp.sid

clean:
	rm -f $(NAME)*.prg *.o $(RES)
