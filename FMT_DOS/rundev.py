import os
import subprocess
import shutil
import sys
import sys



TOWNSTYPE="DEV"

THISFILE=os.path.realpath(__file__)
THISDIR=os.path.dirname(THISFILE)
TSUGARUDIR=os.path.join(THISDIR,"..","..","..","TOWNSEMU")

BUILDDIR=os.path.join(TSUGARUDIR,"build")
SRCDIR=os.path.join(TSUGARUDIR,"src")
ROMDIR=os.path.join(TSUGARUDIR,"..","TOWNSEMU_TEST","ROM_"+TOWNSTYPE)
DISKDIR=os.path.join(TSUGARUDIR,"..","TOWNSEMU_TEST","DISKIMG")
MEMCARDDIR=os.path.join(TSUGARUDIR,"..","TOWNSEMU_TEST","MEMCARD")
DISCDIR=os.path.join("/","d","TownsISO")



def ExeExtension():
	if sys.platform.startswith('win'):
		return ".exe"
	else:
		return ""



def TsugaruExe():
	fName=os.path.join(BUILDDIR,"main_cui","Tsugaru_CUI"+ExeExtension())
	if os.path.isfile(fName):
		return fName
	fName=os.path.join(BUILDDIR,"main_cui","Release","Tsugaru_CUI"+ExeExtension())
	if os.path.isfile(fName):
		return fName
	print("Tsugaru executable not found")
	ErrorExit()



def Run(argv):
	subprocess.Popen([
		TsugaruExe(),
		ROMDIR,
		"-SYM",
		os.path.join(TSUGARUDIR,"symtables","RUN"+TOWNSTYPE+".txt"),
		"-HD0",
		os.path.join(DISKDIR,"hddimage.bin"),
		"-HD1",
		os.path.join(DISKDIR,"40MB.h1"),
		"-JEIDA4",
		os.path.join(MEMCARDDIR,"4MB.bin"),
		"-CMOS",
		os.path.join(THISDIR,"townstst","CMOS.DAT"),
		"-DONTAUTOSAVECMOS",
		#"-HIGHRES",
		"-DEBUG",
		"-PAUSE",
		"-CD",
		"C:/d/townsiso/TownsOSV2.1L20.cue",
		"-HD0",
		os.path.join(THISDIR,"scratch","TESTHD.H0"),
		"-FD0",
		os.path.join(THISDIR,"townstst","TESTFREAD.BIN"),
		"-FD0WP",

		"-GENFD",
		os.path.join(THISDIR,"scratch","blank1232KB.bin"),
		"1232",
		"-FD1",
		os.path.join(THISDIR,"scratch","blank1232KB.bin"),
	]+argv).wait()



def ErrorExit():
	print("Error.")
	quit()



def PrepRun(cmd):
	proc=subprocess.Popen(cmd)
	proc.communicate()
	if 0!=proc.returncode:
		ErrorExit()



def Prep():
	cwd=os.getcwd();
	os.chdir(THISDIR)

	#copy YSDOS\LOADER.SYS make\files\.
	shutil.copyfile(
		os.path.join(THISDIR,"YSDOS","LOADER.SYS"),
		os.path.join(THISDIR,"make","files","LOADER.SYS"))

	shutil.copyfile(
		os.path.join(THISDIR,"YSDOS","YSDOS.SYS"),
		os.path.join(THISDIR,"make","files","YSDOS.SYS"))

	# Version 3.08 of SHSUCDX.COM converted to EXE using COMTOEXE.
	shutil.copyfile(
		os.path.join(THISDIR,"..","SHSUCDX","V3.08","BIN","SHSUCDX.COM"),
		os.path.join(THISDIR,"make","files","SHSUCDX.COM"))

	# COMMAND.COM
	shutil.copyfile(
		os.path.join(THISDIR,"MX","COMMAND.COM"),
		os.path.join(THISDIR,"make","files","COMMAND.COM"))

	os.chdir("make")
	PrepRun([
			"cl",
			"make.cpp",
			"/EHsc"
		])
	PrepRun(["make"])
	os.chdir(THISDIR)

	shutil.copyfile(
		os.path.join(THISDIR,"make","FMT_DOS.ROM"),
		os.path.join(THISDIR,"..","..","..","TOWNSEMU_TEST","rom_dev","FMT_DOS.ROM"))

	shutil.copyfile(
		os.path.join(THISDIR,"townstst","TESTHD.H0"),
		os.path.join(THISDIR,"scratch","TESTHD.H0")
	)

	os.chdir(cwd)



if __name__=="__main__":
	Prep()
	Run(sys.argv[1:])
