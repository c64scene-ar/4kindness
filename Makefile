.PHONY: all clean

NAME=intro
RES=res/music.c64 res/arleka_font_caren_remix0C_invert-charset.bin
D64_IMAGE = "bin/4kindness.d64"
C1541 = c1541

all: $(NAME).prg

run: $(NAME).prg
	x64sc -verbose -moncommands intro.sym $(NAME).prg

d64:
	echo "Generating d64 file..."
	$(C1541) -format "pvm 4kindness,96" d64 $(D64_IMAGE)
	$(C1541) $(D64_IMAGE) -write intro.prg 4kindness
	$(C1541) $(D64_IMAGE) -list

$(NAME).prg: $(NAME).s $(RES)
	cl65 -d -g -Ln intro.sym -o $(NAME).prg -u __EXEHDR__ -t c64 -C c64-asm.cfg $(NAME).s

$(NAME)-alz.prg: $(NAME).prg
	alz64 -s $(NAME).prg $(NAME)-alz.prg

# Processed resources
res/arleka_font_caren_remix0C_invert-charset.bin: res/arleka_font_caren_remix0C-charset.bin
	python scripts/invert.py $< $@

res/music.c64: res/mass_media.sid
	sidreloc -p 80 $< tmp.sid
	dd if=tmp.sid of=$@ bs=1 skip=124
	rm -f tmp.sid

clean:
	rm -f $(NAME)*.prg *.o $(RES) bin/*
