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

	proc=subprocess.Popen(["python",os.path.join("FMT_DOS","build.py")])
	proc.communicate()
	if 0!=proc.returncode:
		print("Error building and assembling FMT_DOS")
		quit(1)

	os.chdir(THISDIR)

	shutil.copyfile(
		os.path.join(THISDIR,"FMT_DOS","FMT_DOS.ROM"),
		os.path.join(THISDIR,"..","TOWNSEMU_TEST","rom_dev","FMT_DOS.ROM"))

	shutil.copyfile(
		os.path.join(THISDIR,"FMT_SYS","forTsugaru","FMT_SYS.ROM"),
		os.path.join(THISDIR,"..","TOWNSEMU_TEST","rom_dev","FMT_SYS.ROM"))

	shutil.copyfile(
		os.path.join(THISDIR,"townstst","TESTHD.H0"),
		os.path.join(THISDIR,"scratch","TESTHD.H0")
	)

	os.chdir(cwd)



