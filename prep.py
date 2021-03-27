import os
import shutil
import subprocess

THISFILE=os.path.realpath(__file__)
THISDIR=os.path.dirname(THISFILE)



def PrepRun(cmd):
	proc=subprocess.Popen(cmd)
	proc.communicate()
	if 0!=proc.returncode:
		ErrorExit()



def Prep():
	cwd=os.getcwd();
	os.chdir(THISDIR)

	if not os.path.isfile(os.path.join(THISDIR,"FMT_DOS","YSDOS","YSDOS.SYS")):
		print("Assemble YSDOS.")
		quit()

	if not os.path.isfile(os.path.join(THISDIR,"FMT_DOS","COMMAND","COMMAND.EXE")):
		print("Compile COMMAND.EXE.")
		quit()

	if not os.path.isfile(os.path.join(THISDIR,"FMT_SYS","forTsugaru","FMT_SYS.ROM")):
		print("Assemble FMT_SYS.")
		quit()


	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DOS","YSDOS","YSDOS.SYS"),
		os.path.join(THISDIR,"FMT_DOS","makerom","files","YSDOS.SYS"))

	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DOS","COMMAND","COMMAND.EXE"),
		os.path.join(THISDIR,"FMT_DOS","makerom","files","COMMAND.COM"))

	os.chdir("FMT_DOS/makerom")
	PrepRun([
			"cl",
			"make.cpp",
			"/EHsc"
		])
	PrepRun(["make"])
	os.chdir(THISDIR)

	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DOS","makerom","FMT_DOS.ROM"),
		os.path.join(THISDIR,"..","TOWNSEMU_TEST","rom_dev","FMT_DOS.ROM"))

	shutil.copyfile(
		os.path.join(THISDIR,"FMT_SYS","forTsugaru","FMT_SYS.ROM"),
		os.path.join(THISDIR,"..","TOWNSEMU_TEST","rom_dev","FMT_SYS.ROM"))

	shutil.copyfile(
		os.path.join(THISDIR,"townstst","TESTHD.H0"),
		os.path.join(THISDIR,"scratch","TESTHD.H0")
	)

	os.chdir(cwd)



