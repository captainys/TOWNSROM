#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <direct.h>
#include <io.h>
#include <process.h>

#include "DOSLIB.H"
#include "DOSCALL.H"
#include "UTIL.H"
#include "DEF.H"

#define VERSION "20240429"

unsigned char echo=1;
unsigned char isFirstLevel=0;
unsigned int PSP=0,ENVSEG=0;
unsigned int ERRORLEVEL=0; /* Error Level Cache */
unsigned char far *PSPPtr=NULL;
static struct Option opt;


static struct _find_t findStruct;


int ExecBuiltInCommand(struct BatchState *batState,const char argv0[],char afterArgv0[]);


/*
1st byte is length excluding the last CR.
2nd byte and the rest, parameter terminated by CR.
There should be no re-entrance for this buffer.
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

void InitBatchState(struct BatchState *state)
{
	memset(state,0,sizeof(struct BatchState));
}


#if 0
void Test(int argc,char *argv[])
{
	int i;
	for(i=1; i<argc; ++i)
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
#endif

#if 0
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
#endif

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

				/* Can be:
				   /c batch.bat arg arg arg ...
				   /cbatch.bat arg arg arg ...
				*/
				if(0!=argv[i][2] && ' '!=argv[i][2] && '\t'!=argv[i][2])
				{
					/* /cbatch.bat arg arg arg ...
					   Batch file name is 2 bytes after the current argument.
					*/
					argv[i]+=2;
				}
				else
				{
					/* /c batch.bat arg arg arg ...
					   Batch file name is the next argument.
					*/
					++i;
				}
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

	PSP=DOSGETPSP();
	/* printf("PSP=%04x\n",PSP); */

	PSPPtr=(unsigned char far*)MK_FP(PSP,0);
	/* PrintPSPInfo(PSPPtr); */

	ENVSEG=GetUint16(PSPPtr+PSP_ENVSEG);
	if(0==ENVSEG)
	{
		ENVSEG=DOSMALLOC(option->ENVSEGLen);
		InitENVSEG(ENVSEG,option->ENVSEGLen,argv[1]);
		/* printf("Allocated ENVSEG:%04x\n",ENVSEG); */
		SetUint16(PSPPtr+PSP_ENVSEG,ENVSEG);
	}
}

void ExecEcho(const char *afterArgv0)
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
		char expand[LINEBUFLEN];
		while('\t'==*afterArgv0 || ' '==*afterArgv0)
		{
			++afterArgv0;
		}
		strncpy(expand,afterArgv0,LINEBUFLEN);
		ExpandEnvVar(ENVSEG,expand,LINEBUFLEN-1);
		puts(expand);
	}
}

void ExecExit(struct BatchState *batState,const char afterArgv0[])
{
	char expand[LINEBUFLEN];
	GetFirstArgument(expand,afterArgv0);
	ExpandEnvVar(ENVSEG,expand,LINEBUFLEN-1);
	if(0==strcmp(expand,"-f") || 0==strcmp(expand,"-F"))
	{
		puts("Exitting.");
		exit(0);
	}
	else if(RUNMODE_FIRST_LEVEL==opt.runMode)
	{
		DOSWRITES(DOS_STDERR,"COMMAND.COM is running first level."DOS_LINEBREAK);
		DOSWRITES(DOS_STDERR,"Use EXIT -F to force exit."DOS_LINEBREAK);
	}
	else
	{
		puts("Exitting.");
		exit(0);
	}
}

void ExecSet(char setParam[])
{
	char *var;
	char data[LINEBUFLEN];
	int equal=0;
	while(0!=setParam[equal] && '='!=setParam[equal])
	{
		++equal;
	}
	if(0==setParam[equal])
	{
		const char far *ENVPtr=MAKEFARPTR(ENVSEG,0);
		while(0!=*ENVPtr)
		{
			while(0!=*ENVPtr)
			{
				DOSPUTC(*ENVPtr);
				++ENVPtr;
			}
			DOSPUTC(0x0D);
			DOSPUTC(0x0A);
			++ENVPtr;
		}
		return;
	}
	setParam[equal]=0;
	var=setParam;
	Capitalize(var);
	strcpy(data,setParam+equal+1);
	if(OK==ExpandEnvVar(ENVSEG,data,LINEBUFLEN))
	{
		int skipByte=0;
		if(data[0]=='\"')
		{
			int i;
			skipByte=1;
			for(i=1; 0!=data[i]; ++i)
			{
				if('\"'==data[i] && 0==data[i+1])
				{
					data[i]=0;
					break;
				}
			}
		}
		SetEnv(ENVSEG,var,data+skipByte);
	}
	else
	{
		puts("Too long.");
	}
}

void ExecGoto(struct BatchState *batState,char gotoLabel[])
{
	FILE *fp;
	static char labelBuf[MAX_PATH],inputBuf[LINEBUFLEN],lineBuf[LINEBUFLEN];
	GetFirstArgument(labelBuf,gotoLabel);
	Capitalize(labelBuf);
	fp=fopen(batState->fName,"r");
	if(NULL!=fp)
	{
		while(NULL!=fgets(inputBuf,LINEBUFLEN-1,fp))
		{
			GetFirstArgument(lineBuf,inputBuf);
			Capitalize(lineBuf);
			if(':'==lineBuf[0] && 0==strcmp(labelBuf,lineBuf+1))
			{
				batState->fPos=ftell(fp); /* Next line of the label. */
				break;
			}
		}
		fclose(fp);
	}
	else
	{
		DOSWRITES(DOS_STDERR,"Cannot open batch file."DOS_LINEBREAK);
	}
}

void ExecIf(struct BatchState *batState,char *param)
{
	unsigned int len;
	static char wordBuf[MAX_PATH];
	len=GetFirstArgument(wordBuf,param);
	param+=len;
	Capitalize(wordBuf);
	if(0==strcmp(wordBuf,"ERRORLEVEL"))
	{
		int compareLevel;
		len=GetFirstArgument(wordBuf,param);
		Capitalize(wordBuf);
		param+=len;

		compareLevel=atoi(wordBuf);
		if(compareLevel<=ERRORLEVEL)
		{
			/* To be safe for reentrance, don't look at wordBuf after ExecBuiltInCommand */
			len=GetFirstArgument(wordBuf,param);
			Capitalize(wordBuf);
			ExecBuiltInCommand(batState,wordBuf,param+len);
		}
	}
	else
	{
		DOSWRITES(DOS_STDERR,"What condition?"DOS_LINEBREAK);
		return;
	}
}

void ExecCD(char afterArgv0[])
{
	int err;
	char dir[MAX_PATH];
	GetFirstArgument(dir,afterArgv0);
	err=DOSCHDIR(dir);
	if(0!=err)
	{
		DOSWRITES(DOS_STDERR,"Cannot change directory."DOS_LINEBREAK);
	}
}

void ExecDir(char afterArgv0[])
{
	int findCount=0;
	static char path[LINEBUFLEN];
	GetFirstArgument(path,afterArgv0);
	ExpandEnvVar(ENVSEG,path,MAX_PATH);

	if(0==path[0])
	{
		strcpy(path,"*.*");
	}

	for(;;)
	{
		int err=1;
		if(0==findCount)
		{
			err=_dos_findfirst(path,0x16,&findStruct);
		}
		else
		{
			err=_dos_findnext(&findStruct);
		}
		if(0!=err)
		{
			break;
		}

		++findCount;

		DOSWRITES(DOS_STDOUT,findStruct.name);
		DOSWRITES(DOS_STDOUT,DOS_LINEBREAK);
	}
	DOSWRITES(DOS_STDOUT,DOS_LINEBREAK);

	if(0==findCount)
	{
		DOSWRITES(DOS_STDOUT,"No such file or directory."DOS_LINEBREAK);
	}
}

void ExecPATH(char afterArgv0[])
{
	static char setpath[LINEBUFLEN];
	GetFirstArgument(setpath,afterArgv0);
	ExpandEnvVar(ENVSEG,setpath,LINEBUFLEN);
	SetEnv(ENVSEG,"PATH",setpath);
}

void ExecDriveLetter(char driveLetter)
{
	unsigned int driveAvail;
	_dos_setdrive(driveLetter-'A'+1,&driveAvail);
}

/*! Execute a built-in command.
    Return 1 if it is a build-in command.  afterArgv0 may be altered.
    Return 0 if it is not.  afterArgv0 unchanged.
*/
int ExecBuiltInCommand(struct BatchState *batState,const char argv0[],char afterArgv0[])
{
	if(0==strcmp(argv0,"ECHO"))
	{
		ExecEcho(afterArgv0);
		return 1;
	}
	else if(0==strcmp(argv0,"EXIT"))
	{
		ExecExit(batState,afterArgv0);
		return 1;
	}
	else if(0==strcmp(argv0,"SET"))
	{
		ExecSet(afterArgv0);
		return 1;
	}
	else if(0==strcmp(argv0,"GOTO"))
	{
		ExecGoto(batState,afterArgv0);
		return 1;
	}
	else if(0==strcmp(argv0,"IF"))
	{
		ExecIf(batState,afterArgv0);
		return 1;
	}
	else if(0==strcmp(argv0,"CD"))
	{
		ExecCD(afterArgv0);
		return 1;
	}
	else if(0==strcmp(argv0+1,":"))
	{
		ExecDriveLetter(argv0[0]);
		return 1;
	}
	else if(0==strcmp(argv0,"PAUSE"))
	{
		char lineBuf[LINEBUFLEN];
		DOSWRITES(DOS_STDOUT,"<<Press Enter to Continue>>"DOS_LINEBREAK);
		DOSGETS(lineBuf);
		return 1;
	}
	else if(0==strcmp(argv0,"PATH"))
	{
		ExecPATH(afterArgv0);
		return 1;
	}
	else if(0==strcmp(argv0,"REM"))
	{
		return 1;
	}
	else if(0==strcmp(argv0,"DIR") || 0==strcmp(argv0,"LS"))
	{
		ExecDir(afterArgv0);
		return 1;
	}
	else if(0==strcmp(argv0,"COPY") || 0==strcmp(argv0,"CD"))
	{
		DOSWRITES(DOS_STDOUT,"COPY to be implemented"DOS_LINEBREAK);
		return 1;
	}
	else if(0==strcmp(argv0,"DEL") || 0==strcmp(argv0,"RM"))
	{
		DOSWRITES(DOS_STDOUT,"DEL to be implemented"DOS_LINEBREAK);
		return 1;
	}
	else if(0==strcmp(argv0,"REN") || 0==strcmp(argv0,"MV"))
	{
		DOSWRITES(DOS_STDOUT,"REN to be implemented"DOS_LINEBREAK);
		return 1;
	}
	else if(0==strcmp(argv0,"MD") || 0==strcmp(argv0,"MKDIR"))
	{
		DOSWRITES(DOS_STDOUT,"MKDIR to be implemented"DOS_LINEBREAK);
		return 1;
	}
	else if(0==strcmp(argv0,"RD") || 0==strcmp(argv0,"RMDIR"))
	{
		DOSWRITES(DOS_STDOUT,"MKDIR to be implemented"DOS_LINEBREAK);
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
	if(FOUND==FindExecutableFromPath(ENVSEG,exeCmd,argv0))
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
	execParamBuf[1]=' ';  /* Turned out, ' ' looks to be required. */
	strncpy(execParamBuf+2,param,execParamBufLen-4); /* -3 should be good enough, but just in case, I'd add an extra 0. */
	execParamBuf[execParamBufLen-1]=0;
	execParamBuf[0]=0;
	for(i=1; 0!=execParamBuf[i]; ++i)
	{
		++execParamBuf[0];
	}
	execParamBuf[i]=ASCII_CR;
	execParamBuf[i+1]=0;

	/*
	So, looks like, if the command line is:
	    abc.exe arg arg arg\n
               ^^^^^^^^^^^^^^
	execParam must be underlined part.  Immediately after exe to line break.
	So, if there is no command parameter, then no space should be placed.

	However, the preceding ' ' is already dropped before this function.
	So, I take care of no-parameter case below.
	*/
	if(1==execParamBuf[0] && ' '==execParamBuf[1])
	{
		execParamBuf[0]=0;
		execParamBuf[1]=execParamBuf[2]; /* Must be CR */
	}
}

/*
Redirection example:

#include <stdio.h>
#include <string.h>
#include <io.h>
#include <process.h>

int main(void)
{
	FILE *ifp=NULL;
	int prevStdin;
	char str[256];

	outp(0x2386,2);

	ifp=fopen("redir.c","r");
	prevStdin=dup(fileno(stdin));
	dup2(fileno(ifp),fileno(stdin));

	fgets(str,255,stdin);
	printf("%s\n",str);

	fclose(ifp);
	dup2(prevStdin,fileno(stdin));

	return 0;
}
*/

struct Redirection
{
	FILE *fpStdin,*fpStdout;
	int prevStdin,prevStdout;
};

enum
{
	REDIR_NOERROR,
	REDIR_ERROR
};

int SetUpRedirection(struct Redirection *info,char cmdLine[])
{
	char redirChar=0;
	char *redirStr="",*redirIn=NULL,*redirOut=NULL,*redirPipe=NULL;

	info->fpStdin=NULL;
	info->fpStdout=NULL;
	info->prevStdin=-1;
	info->prevStdout=-1;

	redirStr=cmdLine;
	while(NULL!=redirStr && 0!=*redirStr)
	{
		redirStr=FindRedirection(&redirChar,redirStr+1);
		if(NULL!=redirStr)
		{
			switch(redirChar)
			{
			case '<':
				redirIn=redirStr;
				break;
			case '>':
				redirOut=redirStr;
				break;
			case '|':
				redirPipe=redirStr;
				break;
			}
		}
	}

	if(NULL!=redirIn)
	{
		redirIn=SkipHeadSpace(redirIn);
		ClearTailSpace(redirIn);
		info->fpStdin=fopen(redirIn,"r");

		if(NULL==info->fpStdin)
		{
			DOSWRITES(DOS_STDERR,"Cannot open ");
			DOSWRITES(DOS_STDERR,redirIn);
			DOSWRITES(DOS_STDERR,DOS_LINEBREAK);
			return REDIR_ERROR;
		}
		info->prevStdin=dup(fileno(stdin));
		dup2(fileno(info->fpStdin),fileno(stdin));
	}
	if(NULL!=redirOut)
	{
		redirOut=SkipHeadSpace(redirOut);
		ClearTailSpace(redirOut);

		info->fpStdout=fopen(redirOut,"w");
		if(NULL==info->fpStdout)
		{
			DOSWRITES(DOS_STDERR,"Cannot open ");
			DOSWRITES(DOS_STDERR,redirOut);
			DOSWRITES(DOS_STDERR,DOS_LINEBREAK);
			return REDIR_ERROR;
		}
		info->prevStdout=dup(fileno(stdout));
		dup2(fileno(info->fpStdout),fileno(stdout));
	}
	if(NULL!=redirPipe)
	{
		DOSWRITES(DOS_STDOUT,"Sorry, pipe is not supported yet."DOS_LINEBREAK);
		DOSWRITES(DOS_STDOUT,"Just executing without pipe."DOS_LINEBREAK);
	}
	return REDIR_NOERROR;
}

void CleanUpRedirection(struct Redirection *info)
{
	if(NULL!=info->fpStdin)
	{
		dup2(info->prevStdin,fileno(stdin));
		_dos_close(info->prevStdin);
		fclose(info->fpStdin);
		info->fpStdin=NULL; // Just in case
	}
	if(NULL!=info->fpStdout)
	{
		dup2(info->prevStdout,fileno(stdout));
		_dos_close(info->prevStdout);
		fclose(info->fpStdout);
		info->fpStdout=NULL; // Just in case
	}
}

int RunBatchFile(char cmd[],char param[])
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

	InitBatchState(&batState);
	strncpy(batState.cmdLine,cmd,LINEBUFLEN-1);
	batState.cmdLine[LINEBUFLEN-1]=0;

	ExpandEnvVar(ENVSEG,batState.cmdLine,LINEBUFLEN);
	ParseString(&batArgc,batArgv,cmd,param);
	if(0==batArgc || FOUND!=FindExecutableFromPath(ENVSEG,batState.fName,batArgv[0]))
	{
		return DOSERR_FILE_NOT_FOUND;
	}

	/* printf("BATCHFILE=%s\n",batState.fName); */

	while(0==batState.eof)
	{
		FILE *fp;
		int argv0Len=0;
		static char argv0[MAX_PATH];
		char *afterArgv0="",*endOfCmd="";
		struct Redirection redirInfo;

		fp=fopen(batState.fName,"r");
		if(NULL==fp)
		{
			DOSWRITES(DOS_STDOUT,"File Not Found."DOS_LINEBREAK);
			DOSWRITES(DOS_STDOUT,"Filename=");
			DOSWRITES(DOS_STDOUT,batState.fName);
			DOSWRITES(DOS_STDOUT,DOS_LINEBREAK);
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
			DOSWRITES(DOS_STDOUT,lineBuf);
			DOSWRITES(DOS_STDOUT,DOS_LINEBREAK);
		}

		/* Batch arguments are restricted by line buffer length already.
		   Hopefully it won't explode the lineBuf.
		*/
		if(OK!=ExpandBatchArg(lineBuf,batArgc,batArgv,LINEBUFLEN))
		{
			DOSWRITES(DOS_STDOUT,"Failed to expand batch parameters."DOS_LINEBREAK);
			continue;
		}

		/*
		The command line shouldn't be expanded by environment variables here.  Too early to do so.
		Why?  Imagine SET PATH=%PATH%;C:\EXE
		%PATH% may be much longer than LINEBUFLEN.
		However, the first argument may include a variable.
		*/
		argv0Len=GetFirstArgument(argv0,lineBuf);
		afterArgv0=GetAfterFirstArgument(lineBuf,argv0Len);
		if(REDIR_NOERROR!=SetUpRedirection(&redirInfo,lineBuf))
		{
			CleanUpRedirection(&redirInfo);
			break;
		}

		Capitalize(argv0);
		ExpandEnvVar(ENVSEG,argv0,LINEBUFLEN);
		if(':'==argv0[0]) /* It's a jump label. */
		{
			continue;
		}
		else if(0==ExecBuiltInCommand(&batState,argv0,afterArgv0))
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
					static struct BatchState nextBatch;
					static char argv0[MAX_PATH];
					static unsigned int argv0Len;

					strncpy(nextBatch.cmdLine,lineBuf,LINEBUFLEN-1);
					nextBatch.cmdLine[LINEBUFLEN-1]=0;
					nextBatch.fPos=0;
					nextBatch.eof=0;

					argv0Len=GetFirstArgument(argv0,nextBatch.cmdLine);
					Capitalize(argv0);
					if(FOUND==FindExecutableFromPath(ENVSEG,nextBatch.fName,argv0))
					{
						ParseString(&batArgc,batArgv,nextBatch.fName,GetAfterFirstArgument(nextBatch.cmdLine,argv0Len));
						batState=nextBatch;
					}
					else
					{
						PrintDOSError(DOSERR_FILE_NOT_FOUND);
						ERRORLEVEL=1;
					}
				}
				break;
			case COMTYPE_BINARY:
				{
					int DOSERR;
					PrepareExecParam(execParamBuf,afterArgv0,MAX_EXEPARAM);
					DOSERR=DOSEXEC(PSP,ENVSEG,exeCmd,execParamBuf);
					ERRORLEVEL=DOSGETERRORLEVEL();
					PrintDOSError(DOSERR);
				}
				break;
			case COMTYPE_BINARY32:
				puts("Direct execution of .EXP not supported.");
				ERRORLEVEL=1;
				break;
			default:
				puts("Wrong Command or File Name.");
				ERRORLEVEL=1;
				break;
			}
		}

		CleanUpRedirection(&redirInfo);
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
		return RunBatchFile(exeCmd,param);
	case COMTYPE_BINARY:
		PrepareExecParam(execParamBuf,param,MAX_EXEPARAM);
		DOSEXEC(PSP,ENVSEG,exeCmd,execParamBuf);
		break;
	case COMTYPE_BINARY32:
	default:
		return -1;
	}
	return 0;
}

int CommandMain(struct Option *option)
{
	static struct BatchState batState;
	int returnCode=0;

	InitBatchState(&batState);

	/* printf("Entering Interactive Mode.\n"); */
	for(;;)
	{
		static char cwd[MAX_PATH];
		static char lineBuf[LINEBUFLEN];
		static char argv0[MAX_PATH],exeCmd[MAX_PATH];
		int argv0Len;
		char *afterArgv0;
		struct Redirection redirInfo;

		getcwd(cwd,MAX_PATH);
		DOSPUTS(cwd);
		DOSPUTC('>');
		DOSGETS(lineBuf);
		DOSPUTC(ASCII_CR);
		DOSPUTC(ASCII_LF);

		argv0Len=GetFirstArgument(argv0,lineBuf);
		Capitalize(argv0);
		afterArgv0=GetAfterFirstArgument(lineBuf,argv0Len);
		if(REDIR_NOERROR!=SetUpRedirection(&redirInfo,lineBuf))
		{
			CleanUpRedirection(&redirInfo);
			continue;
		}
		if(0==ExecBuiltInCommand(&batState,argv0,afterArgv0))
		{
			/* Then exec external command */
			int comType=IdentifyCommandType(exeCmd,argv0);
			switch(comType)
			{
			case COMTYPE_BATCH:
				RunBatchFile(exeCmd,afterArgv0);
				break;
			case COMTYPE_BINARY:
				PrepareExecParam(execParamBuf,afterArgv0,MAX_EXEPARAM);
				DOSEXEC(PSP,ENVSEG,exeCmd,execParamBuf);
				break;
			case COMTYPE_BINARY32:
				puts("Direct execution of .EXP not supported.");
				break;
			default:
				puts("Wrong Command or File Name.");
				break;
			}
		}
		CleanUpRedirection(&redirInfo);
	}
	return returnCode;
}

int main(int argc,char *argv[])
{
	int returnCode=0;

	DOSWRITES(DOS_STDOUT,DOS_LINEBREAK);
	DOSWRITES(DOS_STDOUT,"YAMAND.COM for FM TOWNS Emulators. Ver. "VERSION DOS_LINEBREAK);
	DOSWRITES(DOS_STDOUT,"By CaptainYS"DOS_LINEBREAK);
	DOSWRITES(DOS_STDOUT,DOS_LINEBREAK);

	/* Test(argc,argv); */

	SetUp(&opt,argc,argv);
	if(RUNMODE_FIRST_LEVEL==opt.runMode)
	{
		RunBatchFile("AUTOEXEC.BAT","");
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
