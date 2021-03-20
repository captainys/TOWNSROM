import sys
import os
import subprocess



def Run(argv):
	proc=subprocess.Popen([
			"cl",
			"toNASM.cpp",
			"/EHsc"
		])
	proc.communicate();
	if 0!=proc.returncode:
		print("Error compiling.")
		quit(1)
	os.remove("toNASM.obj");

	for asm in os.listdir():
		ASM=asm.upper()
		if ASM.endswith(".ASM"):
			NSM=os.path.splitext(ASM)[0]+".NSM"
			proc=subprocess.Popen([
					"./toNASM.exe",
					ASM,
					NSM
				])
			proc.communicate();
			if 0!=proc.returncode:
				print("Error converting.")
				quit(1)

	os.remove("toNASM.exe");

	proc=subprocess.Popen([
			"NASM",
			"YSDOS.NSM",
			"-f",
			"bin",
			"-o",
			"YSDOS.SYS",
			"-Lp",
			"-l",
			"YSDOS.LST",
		])
	proc.communicate();
	if 0!=proc.returncode:
		print("Error assembling.")
		quit(1)
	print("Assembly completed.")



if __name__=="__main__":
	Run(sys.argv[1:])
