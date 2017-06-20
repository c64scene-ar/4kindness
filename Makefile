all:
	cl65 -o intro.prg -u __EXEHDR__ -t c64 -C c64-asm.cfg intro.s

run:
	x64sc intro.prg
