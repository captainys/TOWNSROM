import os
import sys
import subprocess

THISFILE=os.path.realpath(__file__)
THISDIR=os.path.dirname(THISFILE)


SRCS=[
	"COMMAND",
	"UTIL",
	"DOSLIB",
	"DOSCALL",
]


def main(argv):
	WATCOM=os.environ["WATCOM"]

	if not os.path.isdir(WATCOM):
		print("Set environment variable WATCOM and try again.")
		quit()

	os.environ["PATH"]=os.path.join(WATCOM,"BINNT")+";"+os.environ["PATH"]
	os.environ["INCLUDE"]=os.path.join(WATCOM,"H")
	os.environ["LIB"]=os.path.join(WATCOM,"LIB286","DOS")+";"+os.path.join(WATCOM,"LIB286")
	os.environ["EDPATH"]=os.path.join(WATCOM,"EDDAT")
	os.environ["WIPFC"]=os.path.join(WATCOM,"WIPFC")

	for src in SRCS:
		cmd=["wcc","-ms","-bt=DOS",src+".C"]
		subprocess.Popen(cmd).wait()

	#cmd=["wlink","@wlink.txt"]
	cmd=["wlink",
		"system",
		"com",
		"option",
		"SMALL",
		"name",
		"COMMAND.COM",
		"file",
		"COMMAND.OBJ,DOSCALL.OBJ,DOSLIB.OBJ,UTIL.OBJ",]
	subprocess.Popen(cmd).wait()



if __name__=="__main__":
	os.chdir(THISDIR)
	main(sys.argv)
