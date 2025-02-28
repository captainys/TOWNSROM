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


	# FMT_DOS
	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DOS","FMT_DOS.ROM"),
		os.path.join(THISDIR,"..","FreeTOWNSOS","CompROM","FMT_DOS.ROM"))

	# FMT_SYS
	shutil.copyfile(
		os.path.join(THISDIR,"FMT_SYS","forTsugaru","FMT_SYS.ROM"),
		os.path.join(THISDIR,"..","FreeTOWNSOS","CompROM","FMT_SYS.ROM"))

	# COMMAND.COM
	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DOS","COMMAND","COMMAND.COM"),
		os.path.join(THISDIR,"..","FreeTOWNSOS","resources","YAMAND.COM"))

	os.chdir(cwd)

