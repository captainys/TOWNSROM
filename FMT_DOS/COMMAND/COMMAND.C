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
unsigned char far *PSPPtr=NULL;


/*
1st byte is length excluding the last CR.
2nd byte and the rest, parameter terminated by CR.
*/
char execParamBuf[MAX_EXEPARAM];

enum
{
	RUNMODE_FIRST_LEVEL,
	RUNMODE_EXEC_AND_STAY,
	RUNMODE_EXEC_AND_EXIT
};

struct Option
{
	unsigned char runMode;
	unsigned int ENVSEGLen;
	char execFilename[MAX_PATH];
	char execParam[MAX_EXEPARAM];
};

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
void SetUp(struct Option *option,int argc,char *argv[])
{
	int i;

	option->runMode=RUNMODE_EXEC_AND_STAY;
	option->execFilename[0]=0;
	option->ENVSEGLen=10; /* 160 bytes */
	option->execParam[0]=0;

	for(i=1; i<argc; ++i)
	{
		if(argv[i][0]=='/')
		{
			char c=argv[i][1];
			if('a'<=c && c<='z')
			{
				c=c+'A'-'a';
			}
			switch(c)
			{
			case 'C':
			case 'K':
				if('C'==c)
				{
					option->runMode=RUNMODE_EXEC_AND_EXIT;
				}
				else /* if('K'==c) */
				{
					option->runMode=RUNMODE_EXEC_AND_STAY;
				}
				++i;
				if(i<argc)
				{
					int paramPtr=0;
					strcpy(option->execFilename,argv[i]);
					for(++i; paramPtr<MAX_EXEPARAM-2 && i<argc; ++i)
					{
						int j;
						if(0!=paramPtr)
						{
							option->execParam[paramPtr++]=' ';
						}
						for(j=0; paramPtr<MAX_EXEPARAM-2 && 0!=argv[i][j]; ++j)
						{
							option->execParam[paramPtr++]=argv[i][j];
						}
						option->execParam[paramPtr]=0;
					}
				}
				break;
			case 'P':
				option->runMode=RUNMODE_FIRST_LEVEL;
				break;
			}
		}
	}

	PSP=getpid();
	printf("PSP Segment=%04x\n",PSP);

	PSPPtr=(unsigned char far*)MK_FP(PSP,0);
	PrintPSPInfo(PSPPtr);

	ENVSEG=GetUint16(PSPPtr+PSP_ENVSEG);
	if(0==ENVSEG)
	{
		ENVSEG=DOSMALLOC(option->ENVSEGLen);
		InitENVSEG(ENVSEG,option->ENVSEGLen,argv[1]);
		printf("Allocated ENVSEG:%04x\n",ENVSEG);
		SetUint16(PSPPtr+PSP_ENVSEG,ENVSEG);
	}
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

void PrepareExecParam(char execParamBuf[],const char param[],unsigned int execParamBufLen)
{
	int i;
	strncpy(execParamBuf+1,param,execParamBufLen-3); /* -2 should be good enough, but just in case, I'd add an extra 0. */
	execParamBuf[execParamBufLen-1]=0;
	execParamBuf[0]=0;
	for(i=1; 0!=execParamBuf[i]; ++i)
	{
		++execParamBuf[0];
	}
	execParamBuf[i]=ASCII_CR;
	execParamBuf[i+1]=0;
}

int RunBatchFile(char cmd[])
{
	int returnCode=0;
	int batArgc=0;
	static char *batArgv[MAX_ARG];
	static char lineBuf[LINEBUFLEN];
	struct BatchState batState;

	while(' '==*cmd || '\t'==*cmd)
	{
		++cmd;
	}

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
				PrepareExecParam(execParamBuf,afterArgv0,MAX_EXEPARAM);
				DOSEXEC(PSP,ENVSEG,exeCmd,execParamBuf);
				break;
			case COMTYPE_BINARY32:
				break;
			default:
				break;
			}
		}
	}
	return returnCode;
}

int ExecExternalCommand(const char fName[],const char param[])
{
	static char exeCmd[MAX_PATH];
	static char lineBuf[LINEBUFLEN];
	int comType=IdentifyCommandType(exeCmd,fName);
	switch(comType)
	{
	case COMTYPE_BATCH:
		{
			int linePtr=0;
			int i;
			for(i=0; 0!=fName[i] && linePtr<LINEBUFLEN-1; ++i)
			{
				lineBuf[linePtr++]=fName[i];
			}
			for(i=0; 0!=param[i] && linePtr<LINEBUFLEN-1; ++i)
			{
				lineBuf[linePtr++]=param[i];
			}
			lineBuf[linePtr]=0;
			return RunBatchFile(lineBuf);
		}
		break;
	case COMTYPE_BINARY:
		PrepareExecParam(execParamBuf,param,MAX_EXEPARAM);
		DOSEXEC(PSP,ENVSEG,exeCmd,execParamBuf);
		break;
	case COMTYPE_BINARY32:
	default:
		return -1;
	}
}

int CommandMain(struct Option *option)
{
	int returnCode=0;
	printf("Entering Interactive Mode.\n");
	for(;;)
	{
	}
	return returnCode;
}

int main(int argc,char *argv[])
{
	int returnCode=0;
	static struct Option opt;

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

	SetUp(&opt,argc,argv);
	if(RUNMODE_FIRST_LEVEL==opt.runMode)
	{
		RunBatchFile("AUTOEXEC.BAT");
		CommandMain(&opt);
	}
	if(RUNMODE_EXEC_AND_STAY==opt.runMode)
	{
		Capitalize(opt.execFilename);
		ExecExternalCommand(opt.execFilename,opt.execParam);
		returnCode=CommandMain(&opt);
	}
	else if(RUNMODE_EXEC_AND_EXIT==opt.runMode)
	{
		Capitalize(opt.execFilename);
		returnCode=ExecExternalCommand(opt.execFilename,opt.execParam);
	}

	return returnCode;
}
