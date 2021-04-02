build\doscall.obj : doscall.asm
	386asm doscall.asm -OBJECT build\doscall.obj


build\fibonaci.exp : fibonaci.c
	hcd386 fibonaci.c -obj build\fibonaci.OBJ
	386link build\fibonaci.obj @LIBS.LN -exe build\fibonaci.exp


build\failcase.exp : failcase.c
	hcd386 failcase.c -obj build\failcase.OBJ
	386link build\failcase.obj @LIBS.LN -exe build\failcase.exp


build\primesiz.exp : primesiz.c
	hcd386 primesiz.c -obj build\primesiz.OBJ
	386link build\primesiz.obj @LIBS.LN -exe build\primesiz.exp


build\makefrag.exp : makefrag.c
	hcd386 makefrag.c -obj build\makefrag.OBJ
	386link build\makefrag.obj @LIBS.LN -exe build\makefrag.exp


build\fwrite.exp : fwrite.c
	hcd386 fwrite.c -obj build\fwrite.OBJ
	386link build\fwrite.obj @LIBS.LN -exe build\fwrite.exp


build\rename.exp : rename.c
	hcd386 rename.c -obj build\rename.OBJ
	386link build\rename.obj build\doscall.obj @LIBS.LN -exe build\rename.exp


build\openclos.exp : openclos.c
	hcd386 openclos.c -obj build\openclos.OBJ
	386link build\openclos.obj build\doscall.obj @LIBS.LN -exe build\openclos.exp


build\return0.exp : return0.c
	hcd386 return0.c -obj build\return0.OBJ
	386link build\return0.obj @LIBS.LN -exe build\return0.exp


build\return1.exp : return1.c
	hcd386 return1.c -obj build\return1.OBJ
	386link build\return1.obj @LIBS.LN -exe build\return1.exp


build\return2.exp : return2.c
	hcd386 return2.c -obj build\return2.OBJ
	386link build\return2.obj @LIBS.LN -exe build\return2.exp
