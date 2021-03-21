#include <stdio.h>
#include <stdlib.h>

#include "DOSLIB.H"
#include "UTIL.h"



unsigned char echo=1;
unsigned char isFirstLevel=0;
unsigned int PSP=0,ENVSEG=0;
unsigned int ENVSEGLEN=16;	/* Number of Paragraphs*/
unsigned char far *PSPPtr=NULL;

#define LINEBUFLEN 256
char lineBuf[LINEBUFLEN];

#define MAX_PATH 128
char trueNameBuf[MAX_PATH];



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

int RunBatchFile(char cmd[])
{
	char *argv[1];
	const char *fName;
	size_t fPos=0;
	int eof=0;

	argv[0]=cmd; /* Should parse and break into args. */

	DOSTRUENAME(trueNameBuf,argv[0]);
	fName=trueNameBuf;

	printf("BATCHFILE=%s\n",fName);

	while(0==eof)
	{
		FILE *fp=fopen(fName,"r");
		if(NULL==fp)
		{
			break;
		}
		fseek(fp,fPos,SEEK_SET);
		while(0==eof)
		{
			if(NULL==fgets(lineBuf,LINEBUFLEN-1,fp))
			{
				eof=1;
				break;
			}
			ClearTailSpace(lineBuf);
			if(0!=lineBuf[0])
			{
				break;
			}
		}
		fPos=ftell(fp);
		fclose(fp);

		if(0!=echo)
		{
			printf("%s$\n",lineBuf);
		}
		/* ExecCommand(lineBuf); */
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
