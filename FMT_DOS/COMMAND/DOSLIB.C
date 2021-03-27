#include <stdio.h>
#include <string.h>
#include "DOSLIB.H"
#include "DOSCALL.H"
#include "UTIL.H"
#include "DEF.H"



const char *DEFPATH="PATH=";
const char *COMSPEC="COMSPEC=";
const char *COMMANDCOM="COMMAND.COM";
const char *YAMANDCOM="YAMAND.COM";

static char doslibFNBuf[MAX_PATH];



void PrintDOSError(int errCode)
{
	puts("");
	switch(errCode)
	{
	case DOSERR_NO_ERROR:
		break;
	case DOSERR_INVALID_FUNC:
		puts("DOSERR_INVALID_FUNC");
		break;
	case DOSERR_FILE_NOT_FOUND:
		puts("DOSERR_FILE_NOT_FOUND");
		break;
	case DOSERR_DIR_NOT_FOUND:
		puts("DOSERR_DIR_NOT_FOUND");
		break;
	case DOSERR_TOO_MANY_OPEN_FILES:
		puts("DOSERR_TOO_MANY_OPEN_FILES");
		break;
	case DOSERR_ACCESS_DENIED:
		puts("DOSERR_ACCESS_DENIED");
		break;
	case DOSERR_INVALID_HANDLE:
		puts("DOSERR_INVALID_HANDLE");
		break;
	case DOSERR_MCB_BROKEN:
		puts("DOSERR_MCB_BROKEN");
		break;
	case DOSERR_OUT_OF_MEMORY:
		puts("DOSERR_OUT_OF_MEMORY");
		break;
	case DOSERR_INVALID_MCB:
		puts("DOSERR_INVALID_MCB");
		break;
	case DOSERR_BAD_ENV:
		puts("DOSERR_BAD_ENV");
		break;
	case DOSERR_BAD_FORMAT:
		puts("DOSERR_BAD_FORMAT");
		break;
	case DOSERR_INVALID_ACCESS:
		puts("DOSERR_INVALID_ACCESS");
		break;
	case DOSERR_INVALID_DATA:
		puts("DOSERR_INVALID_DATA");
		break;
	case DOSERR_UNUSED:
		puts("DOSERR_UNUSED");
		break;
	case DOSERR_INVALID_DRIVE:
		puts("DOSERR_INVALID_DRIVE");
		break;
	case DOSERR_CANNOT_DEL_CUR_DIR:
		puts("DOSERR_CANNOT_DEL_CUR_DIR");
		break;
	case DOSERR_NOT_SAME_DRIVE:
		puts("DOSERR_NOT_SAME_DRIVE");
		break;
	case DOSERR_NO_MORE_FILES:
		puts("DOSERR_NO_MORE_FILES");
		break;
	case DOSERR_WRITE_PROTEDTED:
		puts("DOSERR_WRITE_PROTEDTED");
		break;
	case DOSERR_UNKNOWN_UNIT:
		puts("DOSERR_UNKNOWN_UNIT");
		break;
	case DOSERR_DRIVE_NOT_READY:
		puts("DOSERR_DRIVE_NOT_READY");
		break;
	case DOSERR_UNKNOWN_COMMAND:
		puts("DOSERR_UNKNOWN_COMMAND");
		break;
	case DOSERR_CRC_ERROR:
		puts("DOSERR_CRC_ERROR");
		break;
	case DOSERR_BAD_REQ_LEN:
		puts("DOSERR_BAD_REQ_LEN");
		break;
	case DOSERR_SEEK_ERROR:
		puts("DOSERR_SEEK_ERROR");
		break;
	case DOSERR_UNKNOWN_MEDIUM:
		puts("DOSERR_UNKNOWN_MEDIUM");
		break;
	case DOSERR_SECTOR_NOT_FOUND:
		puts("DOSERR_SECTOR_NOT_FOUND");
		break;
	case DOSERR_OUT_OT_PAPER:
		puts("DOSERR_OUT_OT_PAPER");
		break;
	case DOSERR_WRITE_FAULT:
		puts("DOSERR_WRITE_FAULT");
		break;
	case DOSERR_READ_FAULT:
		puts("DOSERR_READ_FAULT");
		break;
	case DOSERR_GENERAL_FAULT:
		puts("DOSERR_GENERAL_FAULT");
		break;
	case DOSERR_INVALID_DISK_CHANGE:
		puts("DOSERR_INVALID_DISK_CHANGE");
		break;
	default:
		puts("Undefined Error.");
		break;
	}
}



void InitENVSEG(unsigned int ENVSEG,unsigned int len,const char path[])
{
	int i,j;
	unsigned char far *ptr=MAKEFARPTR(ENVSEG,0);

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
	const char *srcExt;
	const char *const ext[]=
	{
		".BAT",".EXE",".COM",NULL
	};

	/* First try as is. */
	DOSTRUENAME(fName,srcFName);
	if(NULL!=(fp=fopen(fName,"rb")))
	{
		fclose(fp);
		return FOUND;
	}

	strncpy(doslibFNBuf,srcFName,MAX_PATH-1);
	doslibFNBuf[MAX_PATH-1]=0;
	srcExt=GetExtension(srcFName);

	if(0==srcExt[0])
	{
		int i;
		for(i=0; NULL!=ext[i]; ++i)
		{
			ReplaceExtension(doslibFNBuf,ext[i]);
			DOSTRUENAME(fName,doslibFNBuf);
			if(NULL!=(fp=fopen(fName,"rb")))
			{
				printf("Found %s\n",fName);
				fclose(fp);
				return FOUND;
			}
		}
	}

/*
	if srcFName has an extension,
		Try different paths.
	else
		Try current dir for .BAT, .COM, .EXE
		Then try different paths for .BAT, .COM, .EXE
*/
	return NOTFOUND;
}



void SetEnv(unsigned int ENVSEG,const char var[],const char data[])
{
	char far *ENVPtr=MAKEFARPTR(ENVSEG,0);
	long int ENVLen=GetArenaBytes(ENVSEG);
	unsigned int i;
	unsigned int state=1; /* 0:Searching for 0  1:Top of variable */
	unsigned int insPoint=~0,nextPoint=~0,final=~0,movePoint=~0,VARDATALen;

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
				if(0!=CaseInsensitiveCompare(var[j],ENVPtr[i+j]))
				{
					break;
				}
			}
			if(0==var[j] && ENVPtr[i+j]=='=') /* Found it */
			{
				insPoint=i;
				break;
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

	if(~0==insPoint)
	{
		/* ENVSEG broken. */
		return;
	}

	for(nextPoint=insPoint; ENVPtr[nextPoint]!=0; ++nextPoint)
	{
		++nextPoint;
		if(ENVLen<=nextPoint+4)
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

const char far *GetEnv(unsigned int ENVSEG,const char var[])
{
	char VAR[MAX_PATH];
	const char far *envPtr;
	unsigned int varLen;

	envPtr=MAKEFARPTR(ENVSEG,0);

	varLen=strncpy_close_nf(VAR,var,MAX_PATH);
	for(;;)
	{
		if(envPtr[varLen]=='=')
		{
			int i;
			for(i=0; i<varLen; ++i)
			{
				if(envPtr[i]!=VAR[i])
				{
					break;
				}
			}
			if(i==varLen) /* Means found. */
			{
				return envPtr+varLen+1;
			}
		}
		while(0!=(*envPtr))
		{
			++envPtr;
		}
		if(0==envPtr[1])
		{
			break;
		}
		else
		{
			++envPtr;
		}
	}

	return "";
}

long int GetArenaBytes(unsigned int SEG)
{
	const unsigned char far *MCBPtr=MAKEFARPTR(SEG-1,0);
	long int bytes=GetUint16(MCBPtr+MCB_BLOCK_SIZE);
	return bytes*16;
}
