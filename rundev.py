import os
import subprocess
import shutil
import sys
import sys

import prep



TOWNSTYPE="DEV"

THISFILE=os.path.realpath(__file__)
THISDIR=os.path.dirname(THISFILE)
TSUGARUDIR=os.path.join(THISDIR,"..","TOWNSEMU")

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

		"-MEMSIZE",
		"16",
	]+argv).wait()



def ErrorExit():
	print("Error.")
	quit()



if __name__=="__main__":
	prep.Prep()
	Run(sys.argv[1:])
