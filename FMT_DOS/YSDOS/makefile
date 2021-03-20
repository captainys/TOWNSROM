ysdos.obj : ysdos.asm dosdef.asm memory.asm file.asm disk.asm process.asm sftable.asm buffer.asm fat.asm dir.asm int21h.asm int2fh.asm stdio.asm devcall.asm wildcard.asm townsdat.asm townsini.asm townsmac.asm townsprc.asm doslabel.asm compati.asm util.asm utilmac.asm sysdev.asm
	masm ysdos.asm ysdos.obj ysdos.lst nul

ysdos.sys : ysdos.obj
	link ysdos.obj;
	exe2bin ysdos.exe ysdos.sys



loader.obj : loader.asm
	masm loader.asm loader.obj loader.lst nul

loader.sys : loader.obj
	link loader.obj;
	exe2bin loader.exe loader.sys
