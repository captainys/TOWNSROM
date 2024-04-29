import os
import sys
import subprocess

THISFILE=os.path.realpath(__file__)
THISDIR=os.path.dirname(THISFILE)



def SetENV():
	WATCOM=os.environ["WATCOM"]

	if not os.path.isdir(WATCOM):
		print("Set environment variable WATCOM and try again.")
		quit()

	os.environ["PATH"]=os.path.join(WATCOM,"BINNT")+";"+os.environ["PATH"]
	os.environ["INCLUDE"]=os.path.join(WATCOM,"H")
	os.environ["LIB"]=os.path.join(WATCOM,"LIB386","DOS")+";"+os.path.join(WATCOM,"LIB386")
	os.environ["EDPATH"]=os.path.join(WATCOM,"EDDAT")
	os.environ["WIPFC"]=os.path.join(WATCOM,"WIPFC")


def WatcomBuild(SRCS):
	for src in SRCS:
		cmd=["wcc","-ms","-3","-os","-bt=DOS",src+".C"]
		proc=subprocess.Popen(cmd)
		proc.communicate()
		if 0!=proc.returncode:
			quit(1)

	OBJS=""
	for src in SRCS:
		if 0!=len(OBJS):
			OBJS+=","
		OBJS+=src+".OBJ"

	cmd=["wlink",
		"system",  "com",
		"option",  "SMALL",
		"option",  "map",
		"name",    SRCS[0]+".COM",
		"file",    OBJS,
		# "option",  "nodefaultlibs",
	]
	proc=subprocess.Popen(cmd)
	proc.communicate()
	if 0!=proc.returncode:
		quit(1)


def main(argv):
	SetENV()
	WatcomBuild(["COMMAND","UTIL","DOSLIB","DOSCALL",])
	WatcomBuild(["TEST"])



if __name__=="__main__":
	os.chdir(THISDIR)
	main(sys.argv)
