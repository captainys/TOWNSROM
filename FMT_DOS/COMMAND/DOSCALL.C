#include <stdio.h>
#include <dos.h>
#include "DOSCALL.H"
#include "UTIL.H"



#define CF(reg) ((reg).x.cflag)



unsigned int DOSGETPSP(void)
{
	union REGS regIn,regOut;
	regIn.x.ax=0x5100;
	intdos(&regIn,&regOut);
	return regOut.x.bx;
}



/*! Returns the segment.
*/
unsigned int DOSMALLOC(unsigned int pages)
{
	union REGS regIn,regOut;
	regIn.x.ax=0x4800;	/* INT 21H 48H */
	regIn.x.bx=pages;
	intdos(&regIn,&regOut);

	if(CF(regOut)) /* CF */
	{
		DOSWRITES(DOS_STDERR,"Malloc Failure.\n");
		for(;;);
	}

	return regOut.x.ax;

#if 0
/* I just leave inline-assembly for LSI-C for future reference. */
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
		pages,			/* BX */
		_asm_malloc,	/* CX (Skip) */
		SEGERR			/* DX */
	);

	if(0!=SEGERR[1])
	{
		DOSWRITES(DOS_STDERR,"Malloc Failure.\n");
		/* printf("%04x %04x\n",SEGERR[0],SEGERR[1]); */
		for(;;);
	}

	return SEGERR[0];
#endif
}

void DOSFREE(unsigned int SEG)
{
	if(0!=SEG)
	{
		union REGS regIn,regOut;
		struct SREGS sregs;
		regIn.x.ax=0x4900;	/* INT 21H 49H */
		sregs.es=SEG;
		intdosx(&regIn,&regOut,&sregs);
	}

#if 0
/* I just leave LSI-C inline assembly for future reference. */
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
*/
#endif
}

int DOSTRUENAME(char fullpath[],const char src[])
{
	union REGS regIn,regOut;
	struct SREGS sregs;
	segread(&sregs);
	sregs.es=sregs.ds;
	regIn.x.ax=0x6000; /* INT 21H 60h */
	regIn.x.di=(unsigned int)fullpath;
	regIn.x.si=(unsigned int)src;
	intdosx(&regIn,&regOut,&sregs);

	return CF(regOut); /* CF */

#if 0
/* I just leave LSI-C inline assembly for future reference. */
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
#endif
}

int DOSEXEC(unsigned int PSP,unsigned int ENVSEG,const char exeFullPath[],const char commandArg[])
{
	int i;
	unsigned char paramBlock[0x16];
	union REGS regIn,regOut;
	struct SREGS sregs;

	segread(&sregs);

	SetUint16(paramBlock,ENVSEG);
	SetUint16(paramBlock+2,((unsigned int)commandArg));
	SetUint16(paramBlock+4,sregs.ds);
	SetUint16(paramBlock+6,0x5C);
	SetUint16(paramBlock+8,PSP);
	SetUint16(paramBlock+0x0A,0x6C);
	SetUint16(paramBlock+0x0C,PSP);
	for(i=0x0E; i<0x16; ++i)
	{
		paramBlock[i]=0;
	}

	regIn.x.ax=0x4B00; /* INT 21H AH=60h */
	sregs.es=sregs.ds;
	regIn.x.bx=(unsigned int)paramBlock; /* ES:BX Param Block */
	regIn.x.dx=(unsigned int)exeFullPath;
	intdosx(&regIn,&regOut,&sregs);

	return CF(regOut); /* CF */

#if 0
	int _asm_exec();
	int i,err=0;

	/* 
	EXEC_NORMAL_SRC_ENVSEG	DW		? ; +00h
	EXEC_NORMAL_COMMANDARG	DD		? ; +02h
	EXEC_NORMAL_FIRSTFCB	DD		? ; +06h
	EXEC_NORMAL_SECONDFCB	DD		? ; +0Ah
	EXEC_NORMAL_INIT_SSSP	DD		? ; +0Eh
	EXEC_NORMAL_INIT_CSIP	DD		? ; +12h
	*/

	unsigned char paramBlock[0x16];
	SetUint16(paramBlock,ENVSEG);
	/* paramBlock+2 will be filled in the inline-assembly. */
	/* paramBlock+4 will be filled in the inline-assembly. */
	SetUint16(paramBlock+6,0x5C);
	SetUint16(paramBlock+8,PSP);
	SetUint16(paramBlock+0x0A,0x6C);
	SetUint16(paramBlock+0x0C,PSP);

	for(i=0x0E; i<0x16; ++i)
	{
		paramBlock[i]=0;
	}

	err=_asm_exec(
		"PUSH	ES\n"
		"PUSH	DS\n"
		"POP	ES\n"
		"MOV	DS:[BX+2],CX\n"
		"MOV	DS:[BX+4],DS\n"
		"MOV	AX,4B00h\n"
		"INT	21h\n"
		"RCL	AX,1\n"
		"AND	AX,1\n"
		"POP	ES\n",

		_asm_exec,		/* AX (SKip) */
		paramBlock,		/* ES:BX Param Block */
		commandArg,		/* CX */
		exeFullPath		/* DS:DX Exe Filename */
	);

	printf("Returned %d\n",err);

	return err;
#endif
}



int DOSGETERRORLEVEL(void)
{
	union REGS regIn,regOut;
	regIn.x.ax=0x4D00;
	intdos(&regIn,&regOut);
	return (regOut.x.ax&0x0F);
}


int DOSCHDIR(const char dir[])
{
	union REGS regIn,regOut;
	regIn.x.ax=0x3B00;
	regIn.x.dx=(unsigned int)dir; /* DS:DX is dir. */
	intdos(&regIn,&regOut);
	if(CF(regOut))
	{
		return regOut.x.ax;
	}
	return 0;
}


void DOSPUTS(const char str[])
{
	int i;
	for(i=0; 0!=str[i]; ++i)
	{
		DOSPUTC(str[i]);
	}
}


void DOSPUTC(char c)
{
	union REGS regIn,regOut;
	regIn.x.ax=0x0200;
	regIn.x.dx=c;
	intdos(&regIn,&regOut);
}


int DOSGETS(char buf[LINEBUFLEN])
{
	int i;
	union REGS regIn,regOut;
	unsigned char inputBuf[LINEBUFLEN+2];
	inputBuf[0]=240; /* 240<LINEBUFLEN */
	inputBuf[1]=0;
	regIn.x.ax=0x0A00;
	regIn.x.dx=(unsigned int)inputBuf;
	intdos(&regIn,&regOut);
	for(i=0; i<inputBuf[1]; ++i)
	{
		buf[i]=inputBuf[2+i];
	}
	buf[i]=0;
	return i;
}

void DOSWRITES(int fd,const char str[])
{
	unsigned written;
	_dos_write(fd,(const char far *)str,strlen(str),&written);
}
