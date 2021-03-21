#include <stdio.h>
#include <stdlib.h>
#include <dos.h>
#include <process.h>

#define PSP_ENVSEG 0x2C
#define PSP_COMMANDLINE 0x80

#define DOSPARA 16

const char *DEFPATH="PATH=";
const char *COMSPEC="COMSPEC=";
const char *COMMANDCOM="COMMAND.COM";
const char *YAMANDCOM="YAMAND.COM";

unsigned int PSP=0,ENVSEG=0;
unsigned int ENVSEGLEN=16;	/* Number of Paragraphs*/
unsigned char far *PSPPtr=NULL;

unsigned int GetUint16(unsigned char far *ptr)
{
	return ptr[0]|(ptr[1]<<8);
}
void SetUint16(unsigned char far *ptr,unsigned int data)
{
	ptr[0]=data&255;
	ptr[1]=(data>>8)&255;
}



/*! Returns the segment.
*/
unsigned int DOSMALLOC(unsigned int pages)
{
	void _asm_malloc();

	unsigned int SEGERR[2]={0xcccc,0xcccc};

	_asm_malloc(
		"PUSH	ES\n"
		"PUSH	BX\n"

		"MOV	AH,48h\n"
		"INT	21H\n"

		"MOV	BX,DX\n"
		"MOV	DS:[BX],AX\n"

		"RCL	DX,1\n"
		"AND	DX,1\n"
		"MOV	DS:[BX+2],DX\n"	/* SEGERR[1] will be CF */

		"POP	BX\n"
		"POP	ES\n",
		_asm_malloc,	/* AX (SKip) */
		pages,			/* AX */
		_asm_malloc,	/* CX (Skip) */
		SEGERR			/* DX */
	);

	if(0!=SEGERR[1])
	{
		printf("Malloc Failure.\n");
		printf("%04x %04x\n",SEGERR[0],SEGERR[1]);
		for(;;);
	}

	return SEGERR[0];
}

void DOSFREE(unsigned int SEG)
{
	void _asm_free();

	_asm_free(
		"PUSH	ES\n"
		"MOV		AH,49h\n"
		"MOV		ES,DX\n"
		"INT		21h\n"
		"POP		ES\n",
		_asm_free,	/* AX (SKip) */
		_asm_free,	/* BX (SKip) */
		_asm_free,	/* CX (Skip) */
		SEG			/* DX */
	);
}

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

void InitENVSEG(unsigned int ENVSEG,unsigned int len,char path[])
{
	int i,j;
	unsigned char far *ptr=MK_FP(ENVSEG,0);
	unsigned int MCB=ENVSEG-1;
	unsigned char far *mcb=MK_FP(MCB,0);

	i=0;
	for(i=0; i<len*DOSPARA; ++i)
	{
		ptr[i]=0;
	}

	i=0;
	for(j=0; 0!=DEFPATH[j]; ++j)
	{
		ptr[i++]=DEFPATH[j];
	}
	ptr[i++]=0;
	for(j=0; 0!=COMSPEC[j]; ++j)
	{
		ptr[i++]=COMSPEC[j];
	}
	for(j=0; 0!=path[j]; ++j)
	{
		ptr[i++]=path[j];
	}
	for(j=0; 0!=COMMANDCOM[j]; ++j)
	{
		ptr[i++]=COMMANDCOM[j];
	}
	ptr[i++]=0;

	ptr[i++]=0;
	ptr[i++]=0;
	ptr[i++]=1;
	ptr[i++]=0;
	for(j=0; 0!=YAMANDCOM[j]; ++j)
	{
		ptr[i+j]=YAMANDCOM[j];
	}
}

int SetUp(int argc,char *argv[])
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

	SetUp(argc,argv);

	{
		size_t fSize;
		FILE *fp=fopen("AUTOEXEC.BAT","rb");
		fseek(fp,0,SEEK_END);
		fSize=ftell(fp);
		fclose(fp);
		printf("AUTOEXEC.BAT %d bytes\n",fSize);
	}
	

	{
		int a=0;
		while(a==0);
	}

	for(;;);
	return 0;
}
