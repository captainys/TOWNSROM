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



def ErrorExit():
	print("Error.")
	quit()



if __name__=="__main__":
	prep.Prep()

	cwd=os.getcwd()
	os.chdir(THISDIR)

	if not os.path.isdir(os.path.join(THISDIR,"release","forTsugaru")):
		os.makedirs(os.path.join(THISDIR,"release","forTsugaru"))

	if not os.path.isdir(os.path.join(THISDIR,"release","forUNZ")):
		os.makedirs(os.path.join(THISDIR,"release","forUNZ"))

	# FMT_DOS
	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DOS","FMT_DOS.ROM"),
		os.path.join(THISDIR,"release","forTsugaru","FMT_DOS.ROM"))

	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DOS","FMT_DOS.ROM"),
		os.path.join(THISDIR,"release","forUNZ","FMT_DOS.ROM"))

	# FMT_SYS
	shutil.copyfile(
		os.path.join(THISDIR,"FMT_SYS","forTsugaru","FMT_SYS.ROM"),
		os.path.join(THISDIR,"release","forTsugaru","FMT_SYS.ROM"))

	shutil.copyfile(
		os.path.join(THISDIR,"FMT_SYS","forUNZ","FMT_SYS.ROM"),
		os.path.join(THISDIR,"release","forUNZ","FMT_SYS.ROM"))


	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DIC","FMT_DIC.ROM"),
		os.path.join(THISDIR,"release","forTsugaru","FMT_DIC.ROM"))
	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DIC","FMT_DIC.ROM"),
		os.path.join(THISDIR,"release","forUNZ","FMT_DIC.ROM"))


	subprocess.Popen(["git","add","-u",os.path.join(THISDIR,"release")]).wait()


	os.chdir(cwd)

