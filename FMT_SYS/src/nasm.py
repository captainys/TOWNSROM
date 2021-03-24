import subprocess
import sys
import shutil
import os



TOWNSTYPE="DEV"

THISFILE=os.path.realpath(__file__)
THISDIR=os.path.dirname(THISFILE)
TSUGARUDIR=os.path.join(THISDIR,"..","..","TOWNSEMU")

BUILDDIR=os.path.join(TSUGARUDIR,"build")
SRCDIR=os.path.join(TSUGARUDIR,"src")
ROMDIR=os.path.join(TSUGARUDIR,"..","TOWNSEMU_TEST","ROM_"+TOWNSTYPE)
DISKDIR=os.path.join(TSUGARUDIR,"..","TOWNSEMU_TEST","DISKIMG")
MEMCARDDIR=os.path.join(TSUGARUDIR,"..","TOWNSEMU_TEST","MEMCARD")
DISCDIR=os.path.join("/","d","TownsISO")



def Assemble():
	proc=subprocess.Popen(
		[
			"nasm",
			"-O3",
			"-f",
			"bin",
			"sys.asm",
			"-o",
			"../parts/fmt_sys6.prg",
			"-l",
			"SYS.LST",
		])
	proc.communicate()
	if 0!=proc.returncode:
		print("Error assembling.")
		quit(1)
	print("Assembly completed.")



def MergeFile(source,destin):
	ofp=open(destin,"wb")
	for fName in source:
		ifp=open(fName,"rb");
		bytes=ifp.read()
		ofp.write(bytes)
		ifp.close()
	ofp.close()



def Run(argv):
	Assemble()
	os.chdir(os.path.join(THISDIR,"..","parts"))
	MergeFile(
		[
			"fmt_sys0.f12","fmt_sys1.exb","fmt_sys2.icn","fmt_sys3.dmy","fmt_sys4.lgo","fmt_sys5.ic2","fmt_sys6.prg"
		],
		os.path.join("..","forUNZ","fmt_sys.rom"))

	MergeFile(
		[
			"fmt_sys0.f12","fmt_sys1.exb","fmt_sys2.icn","fmt_sys3.dmy","fmt_sys4_Tsugaru.lgo","fmt_sys5.ic2","fmt_sys6.prg"
		],
		os.path.join("..","forTsugaru","fmt_sys.rom"))

	shutil.copyfile(
		os.path.join("..","forTsugaru","fmt_sys.rom"),
		os.path.join("..","..","..","townsemu_test","rom_dev","FMT_SYS.ROM")
	)



if __name__=="__main__":
	Run(sys.argv[1:])
