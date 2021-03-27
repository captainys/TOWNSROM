import os
import subprocess
import shutil
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



def ErrorExit():
	print("Error.")
	quit()



def PrepRun(cmd):
	proc=subprocess.Popen(cmd)
	proc.communicate()
	if 0!=proc.returncode:
		ErrorExit()



def Run(argv):
	os.chdir(os.path.join(THISDIR,"scratch"))
	PrepRun(["cmake","../tests"])
	PrepRun(["ctest","-C","Release"]+argv)



if __name__=="__main__":
	prep.Prep()
	Run(sys.argv[1:])
