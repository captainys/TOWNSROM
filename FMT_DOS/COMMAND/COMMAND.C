#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "DOSLIB.H"
#include "DOSCALL.H"
#include "UTIL.H"
#include "DEF.H"



unsigned char echo=1;
unsigned char isFirstLevel=0;
unsigned int PSP=0,ENVSEG=0;
unsigned int ENVSEGLEN=16;	/* Number of Paragraphs*/
unsigned char far *PSPPtr=NULL;

char lineBuf[LINEBUFLEN];

/*
1st byte is length excluding the last CR.
2nd byte and the rest, parameter terminated by CR.
*/
char exeParamBuf[MAX_EXEPARAM];

struct BatchState
{
	char cmdLine[LINEBUFLEN];
	char fName[MAX_PATH];
	size_t fPos;
	unsigned char eof;
};



void Test(int argc,char *argv[])
{
	int i;
	for(i=0; i<argc; ++i)
	{
		printf("[%d] %s\n",i,argv[i]);
	}
	{
		char *dat=malloc(4096);
		printf("Malloc Test %04x\n",dat);
	}
	printf("sizeof(int)=%d\n",sizeof(int));
	printf("sizeof(long)=%d\n",sizeof(long));
	printf("sizeof(size_t)=%d\n",sizeof(size_t));
}

void PrintPSPInfo(unsigned char far *PSPPtr)
{
	int i;

	ENVSEG=GetUint16(PSPPtr+PSP_ENVSEG);
	printf("ENVSEG=%04x\n",ENVSEG);

	printf("COMMAND LINE LEN:%d\n",(int)(*(PSPPtr+PSP_COMMANDLINE)));
	printf("COMMAND LINE:");
	for(i=1; 0!=*(PSPPtr+PSP_COMMANDLINE+i); ++i)
	{
		putchar(*(PSPPtr+PSP_COMMANDLINE+i));
	}
	putchar('\n');
}

/*! Return value 0:Not the First-Level   Non-Zero:First-Level
*/
unsigned char SetUp(int argc,char *argv[])
{
	int argUsed=0;

	PSP=getpid();
	printf("PSP Segment=%04x\n",PSP);

	PSPPtr=(unsigned char far*)MK_FP(PSP,0);
	PrintPSPInfo(PSPPtr);

	ENVSEG=GetUint16(PSPPtr+PSP_ENVSEG);
	if(0==ENVSEG)
	{
		ENVSEG=DOSMALLOC(ENVSEGLEN);
		InitENVSEG(ENVSEG,ENVSEGLEN,argv[1]);
		argUsed=1;
		printf("ENVSEG Allocated:%04x\n",ENVSEG);
		SetUint16(PSPPtr+PSP_ENVSEG,ENVSEG);
	}

	return argUsed;
}

void ExecEcho(const char afterArgv0[])
{
	if(0==strcmp(afterArgv0,"OFF"))
	{
		/* echo=0; */
	}
	else if(0==strcmp(afterArgv0,"ON"))
	{
		echo=1;
	}
	else
	{
		puts(afterArgv0);
	}
}

void ExecSet(char setParam[])
{
	char *var,*data;
	int equal=0;
	while(0!=setParam[equal] && '='!=setParam[equal])
	{
		++equal;
	}
	if(0==setParam[equal])
	{
		printf("Wrong Parameter");
		/* Should I set errorlevel? */
		return;
	}
	setParam[equal]=0;
	var=setParam;
	data=setParam+equal+1;
	if(data[0]=='\"')
	{
		int i;
		++data;
		for(i=0; 0!=data[i]; ++i)
		{
			if('\"'==data[i] && 0==data[i+1])
			{
				data[i]=0;
				break;
			}
		}
	}
	SetEnv(ENVSEG,var,data);
}

/*! Execute a built-in command.
    Return 1 if it is a build-in command.  afterArgv0 may be altered.
    Return 0 if it is not.  afterArgv0 unchanged.
*/
int ExecBuiltInCommand(const char argv0[],char afterArgv0[])
{
	if(0==strcmp(argv0,"ECHO"))
	{
		ExecEcho(afterArgv0);
		return 1;
	}
	else if(0==strcmp(argv0,"SET"))
	{
		ExecSet(afterArgv0);
		return 1;
	}
	return 0;
}

/*! Identifies the executable pointed by argv0.
    It sets actual full-path executable name in exeCmd.
    argv0 is capitalized first argument in the command line.
*/
int IdentifyCommandType(char exeCmd[],const char argv0[])
{
	if(FOUND==FindExecutableFromPath(exeCmd,argv0))
	{
		int i;
		for(i=0; 0!=exeCmd[i]; ++i)
		{
			if('.'==exeCmd[i])
			{
				if(0==strcmp(exeCmd+i+1,"EXE") ||
				   0==strcmp(exeCmd+i+1,"COM"))
				{
					return COMTYPE_BINARY;
				}
				if(0==strcmp(exeCmd+i+1,"EXP"))
				{
					return COMTYPE_BINARY32;
				}
				if(0==strcmp(exeCmd+i+1,"BAT"))
				{
					return COMTYPE_BATCH;
				}
				break;
			}
		}
	}
	return COMTYPE_UNKNOWN;
}

int RunBatchFile(char cmd[])
{
	int batArgc=0;
	static char *batArgv[MAX_ARG];
	struct BatchState batState;

	strncpy(batState.cmdLine,cmd,LINEBUFLEN-1);
	batState.cmdLine[LINEBUFLEN-1]=0;
	batState.fPos=0;
	batState.eof=0;

	ExpandEnvVar(batState.cmdLine,LINEBUFLEN);
	ParseString(&batArgc,batArgv,batState.cmdLine);
	if(0==batArgc || FOUND!=FindExecutableFromPath(batState.fName,batArgv[0]))
	{
		return DOSERR_FILE_NOT_FOUND;
	}

	printf("BATCHFILE=%s\n",batState.fName);

	while(0==batState.eof)
	{
		FILE *fp;
		int argv0Len=0;
		static char argv0[MAX_PATH];
		char *afterArgv0="";

		fp=fopen(batState.fName,"r");
		if(NULL==fp)
		{
			printf("File Not Found.\n");
			printf("Filename=%s\n",batState.fName);
			break;
		}
		fseek(fp,batState.fPos,SEEK_SET);
		while(0==batState.eof)
		{
			if(NULL==fgets(lineBuf,LINEBUFLEN-1,fp))
			{
				batState.eof=1;
				break;
			}
			ClearTailSpace(lineBuf);
			if(0!=lineBuf[0])
			{
				break;
			}
		}
		batState.fPos=ftell(fp);
		fclose(fp);

		if(0!=batState.eof)
		{
			break;
		}
		if(0==lineBuf[0])
		{
			continue;
		}

		if(0!=echo)
		{
			printf("%s$\n",lineBuf);
		}

		/*
		The command line shouldn't be expanded by environment variables here.  Too early to do so.
		Why?  Imagine SET PATH=%PATH%;C:\EXE
		%PATH% may be much longer than LINEBUFLEN.
		However, the first argument may include a variable.
		*/
		argv0Len=GetFirstArgument(argv0,lineBuf);
		afterArgv0=GetAfterFirstArgument(lineBuf,argv0Len);
		Capitalize(argv0);
		/* ExpandBatchArg(argv0,LINEBUFLEN,batArgc,batArgv); */
		ExpandEnvVar(argv0,LINEBUFLEN);
		if(0==ExecBuiltInCommand(argv0,afterArgv0))
		{
			static char exeCmd[MAX_PATH];
			int comType=IdentifyCommandType(exeCmd,argv0);
			switch(comType)
			{
			case COMTYPE_BATCH:
				/*
				DOS Batch File does not CALL another batch.
				It does JMP to another batch unless it is invoked from COMMAND.COM.
				*/
				{
					struct BatchState nextBatch;
					char argv0[MAX_PATH];

					strncpy(nextBatch.cmdLine,lineBuf,LINEBUFLEN-1);
					nextBatch.cmdLine[LINEBUFLEN-1]=0;
					nextBatch.fPos=0;
					nextBatch.eof=0;

					GetFirstArgument(argv0,nextBatch.cmdLine);
					Capitalize(argv0);
					if(FOUND==FindExecutableFromPath(batState.fName,argv0))
					{
						ParseString(&batArgc,batArgv,batState.cmdLine);
						batState=nextBatch;
					}
					else
					{
						/* ERRORLEVEL=DOSERR_FILE_NOT_FOUND; */
					}
				}
				break;
			case COMTYPE_BINARY:
				{
					strncpy(exeParamBuf+1,afterArgv0,MAX_EXEPARAM-2);
					exeParamBuf[0]=strlen(afterArgv0);
					strcat(exeParamBuf+1,"\n");
					DOSEXEC(PSP,ENVSEG,exeCmd,exeParamBuf);
				}
				break;
			case COMTYPE_BINARY32:
				break;
			default:
				break;
			}
		}
	}

	for(;;);
}

int CommandMain(int argc,char *argv[])
{
	int returnCode=0;
	for(;;)
	{
	}
	return returnCode;
}

int main(int argc,char *argv[])
{
	printf("\n");
	printf("COMMAND.COM for FM TOWNS Emulators.\n");
	printf("By CaptainYS\n");
	printf("\n");

	Test(argc,argv);

	if(sizeof(int)!=2 || sizeof(unsigned int)!=2)
	{
		printf("Need to be compiled by a 16-bit compiler.\n");
		printf("Where are you running it?\n");
		for(;;);
	}

	isFirstLevel=SetUp(argc,argv);
	if(0!=isFirstLevel)
	{
		RunBatchFile("AUTOEXEC.BAT");
		CommandMain(argc-1,argv+1);
	}
	else
	{
		CommandMain(argc,argv);
	}

	return 0;
}
