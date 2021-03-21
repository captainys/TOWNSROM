#include <stdio.h>
#include "DOSLIB.H"



const char *DEFPATH="PATH=";
const char *COMSPEC="COMSPEC=";
const char *COMMANDCOM="COMMAND.COM";
const char *YAMANDCOM="YAMAND.COM";



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
	if(0!=SEG)
	{
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
}

int DOSTRUENAME(char fullpath[],const char src[])
{
	int _asm_truename();
	int err=0;

	err=_asm_truename(
		"PUSH	ES\n"
		"PUSH	SI\n"
		"PUSH	DI\n"

		"PUSH	DS\n"
		"POP	ES\n"
		"MOV	DI,CX\n"
		"MOV	SI,DX\n"

		"MOV	AH,60h\n"
		"INT	21H\n"

		"RCL	AX,1\n"
		"AND	AX,1\n"

		"POP	DI\n"
		"POP	SI\n"
		"POP	ES\n",
		_asm_truename,	/* AX (SKip) */
		_asm_truename,	/* BX */
		fullpath,	/* CX */
		src			/* DX */
	);

	return err;
}

void InitENVSEG(unsigned int ENVSEG,unsigned int len,const char path[])
{
	int i,j;
	unsigned char far *ptr=MAKEFARPTR(ENVSEG,0);
	unsigned int MCB=ENVSEG-1;
	unsigned char far *mcb=MAKEFARPTR(ENVSEG,0);

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

