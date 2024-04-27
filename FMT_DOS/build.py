import os
import sys
import subprocess
import shutil

THISFILE=os.path.realpath(__file__)
THISDIR=os.path.dirname(THISFILE)

def main(argv):
	os.chdir("YSDOS")
	proc=subprocess.Popen(["python","nasm.py"])
	proc.communicate()
	if 0!=proc.returncode:
		print("Error building YSDOS.SYS")
		quit(1)

	os.chdir(THISDIR)
	os.chdir("COMMAND")
	proc=subprocess.Popen(["python","build.py"])
	proc.communicate()
	if 0!=proc.returncode:
		print("Error building YAMAND.COM")
		quit(1)

	os.chdir(THISDIR)

	shutil.copyfile(
		os.path.join("YSDOS","YSDOS.SYS"),
		os.path.join("makerom","files","YSDOS.SYS"))

	shutil.copyfile(
		os.path.join("COMMAND","COMMAND.COM"),
		os.path.join("makerom","files","COMMAND.COM"))

	os.chdir("makerom")

	proc=subprocess.Popen(["cl","makerom.cpp"])
	proc.communicate()
	if 0!=proc.returncode:
		print("Failed to build makerom.exe")
		quit(1)

	proc=subprocess.Popen(["makerom.exe"])
	proc.communicate()
	if 0!=proc.returncode:
		print("Failed to assemble FMT_DOS.ROM")
		quit(1)

	os.chdir(THISDIR)

	testInstallDir=os.path.join("..","..","TOWNSEMU_TEST","ROM_DEV")
	if os.path.isdir(testInstallDir):
		shutil.copyfile("FMT_DOS.ROM",os.path.join(testInstallDir,"FMT_DOS.ROM"))
		print("FMT_DOS.ROM Copied to the test environment.")



if __name__=="__main__":
	os.chdir(THISDIR)
	main(sys.argv)
