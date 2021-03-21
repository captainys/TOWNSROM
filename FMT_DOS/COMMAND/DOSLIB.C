#include <stdio.h>
#include <string.h>
#include "DOSLIB.H"
#include "DOSCALL.H"
#include "UTIL.H"



const char *DEFPATH="PATH=";
const char *COMSPEC="COMSPEC=";
const char *COMMANDCOM="COMMAND.COM";
const char *YAMANDCOM="YAMAND.COM";



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
	ptr[i++]=1;
	ptr[i++]=0;
	for(j=0; 0!=YAMANDCOM[j]; ++j)
	{
		ptr[i+j]=YAMANDCOM[j];
	}
}

int FindExecutableFromPath(char fName[],const char srcFName[])
{
	FILE *fp;

	/* First try as is. */
	DOSTRUENAME(fName,srcFName);
	if(NULL!=(fp=fopen(fName,"rb")))
	{
		fclose(fp);
		return FOUND;
	}


/*
	if srcFName has an extension,
		Try different paths.
	else
		Try different path for .BAT, .COM, .EXE, and .EXP
*/
	return NOTFOUND;
}



void SetEnv(unsigned int ENVSEG,const char var[],const char data[])
{
	char far *ENVPtr=MAKEFARPTR(ENVSEG,0);
	long int ENVLen=GetArenaBytes(ENVSEG);
	unsigned int i;
	unsigned int state=1; /* 0:Searching for 0  1:Top of variable */
	unsigned int insPoint=-1,nextPoint=-1,final=-1,movePoint=-1,VARDATALen;

	if(32762<ENVLen)
	{
		/* I think DOS considered ENVSEG broken if it is greater than 32K.
		   It requires 0 0 1 0 0 minimum to close the ENVSEG.  So, 32767-5.
		*/
		ENVLen=32762;
	}
	for(i=0; i+4<ENVLen; ++i)
	{
		if(1==state)
		{
			unsigned int j;
			for(j=0; 0!=var[j] && i+j+1<ENVLen; j++)
			{
				if(var[j]!=ENVPtr[i+j])
				{
					break;
				}
			}
			if(0==var[j] && ENVPtr[i+j]=='=') /* Found it */
			{
				insPoint=i;
			}
			else
			{
				state=0; /* Skip until the next 0. */
			}
		}
		else /* if(0==state) */
		{
			if(0==ENVPtr[i])
			{
				if(0==ENVPtr[i+1]) /* Not found.  A new variable. */
				{
					insPoint=i+1;
					break;
				}
				else
				{
					state=1; /* Try next variable. */
				}
			}
		}
	}

	if(insPoint<0)
	{
		/* ENVSEG broken. */
		return;
	}

	for(nextPoint=insPoint; ENVPtr[nextPoint]!=0; ++nextPoint)
	{
		++nextPoint;
		if(nextPoint+4<ENVLen)
		{
			/* ENVSEG broken. */
			return;
		}
	}

	/*
	ENVPtr[insPoint] is where new variable (Either VAR=DATA or DATA)
	ENVPtr[nextPoint]=0, and the end of the set variable.
	*/

	state=0;
	for(final=nextPoint; final+4<ENVLen; ++final)
	{
		if(0==state &&
		   0==ENVPtr[final] &&
		   1==ENVPtr[final+1] &&
		   0==ENVPtr[final+2]) /* Beginning of EXE File Name */
		{
			final+=2;
			state=1;
		}
		else if(1==state && 0==ENVPtr[final])
		{
			state=2;
			break;
		}
	}
	if(2!=state)
	{
		/* ENVSEG Broken */
		return;
	}

	/*
	ENVPtr[insPoint] is where new variable (Either VAR=DATA or DATA)
	ENVPtr[nextPoint]=0, and the end of the set variable.
	ENVPtr[final]=0, the last byte of the EXE file name.
	*/

	VARDATALen=strlen(var)+1+strlen(data);
	if(0==ENVPtr[insPoint])
	{
		++VARDATALen;
		/*
		Why is it?
		If it is not a new variable, replace
		  VAR=ABC
		with
		  VAR=NEWDATA

		However, if it is a new variable, insert point is:

		  00 00 01 00 (exe name)
		    ^

		If I insert just "VAR=NEWDATA", it will look like:

		  00 VAR=NEWDATA 00 01 00

		It loses the termination with double zeros.  I need to insert "VAR=NEWDATA" plus one extra zero.
		*/
	}

	movePoint=insPoint+VARDATALen;
	if(movePoint<=nextPoint)
	{
		/* Variable gets shorter.  Easy. */
		int ptr=insPoint;
		for(i=0; 0!=var[i]; ++i)
		{
			ENVPtr[ptr++]=var[i];
		}
		ENVPtr[ptr++]='=';
		for(i=0; 0!=data[i]; ++i)
		{
			ENVPtr[ptr++]=data[i];
		}
		for(i=nextPoint; i<=final; ++i)
		{
			ENVPtr[ptr++]=ENVPtr[i];
		}
	}
	else
	{
		unsigned int curLen=nextPoint-insPoint;
		unsigned int growth=VARDATALen-curLen;
		unsigned int ptr;

		if(ENVLen<=growth)
		{
			/* Out of Memory */
			return;
		}
		for(i=final; nextPoint<=i; --i)
		{
			ENVPtr[i+growth]=ENVPtr[i];
		}
		ptr=insPoint;
		for(i=0; 0!=var[i]; ++i)
		{
			ENVPtr[ptr++]=var[i];
		}
		ENVPtr[ptr++]='=';
		for(i=0; 0!=data[i]; ++i)
		{
			ENVPtr[ptr++]=data[i];
		}
		ENVPtr[ptr++]=0; /* If new variable, this makes sure 00 00. */
	}
}

const char *GetEnv(unsigned int ENVSEG,const char var[])
{
}

long int GetArenaBytes(unsigned int SEG)
{
	const unsigned char far *MCBPtr=MAKEFARPTR(SEG-1,0);
	long int bytes=GetUint16(MCBPtr+MCB_BLOCK_SIZE);
	return bytes*16;
}
