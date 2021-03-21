#include <stdio.h>
#include "UTIL.H"
#include "DEF.H"



void ClearTailSpace(char *str)
{
	int i;
	int lastNonSpace=0;
	for(i=0; 0!=str[i]; ++i)
	{
		if(IsKanji(str[i]) && 0!=str[i+1])
		{
			++i;
			continue;
		}
		if(ASCII_CR==str[i] || ASCII_LF==str[i])
		{
			str[i]=0;
			break;
		}
		if(str[i]<0 || ' '<str[i])
		{
			lastNonSpace=i;
		}
	}
	str[lastNonSpace+1]=0;
}

int IsKanji(char c)
{
	unsigned int C=c;
	C&=0xFF;
	return 0x81<=C;
}

int ExpandEnvVar(char lineBuf[],unsigned int lineBufLen)
{
	return 0;
}

int ParseString(int *argc,char *argv[],char cmdLine[])
{
	int i;
	int state=0;  /* 0:Not word  1:Word  2:Double-quote */
	*argc=0;
	for(i=0; 0!=cmdLine[i] && *argc<MAX_ARG; ++i)
	{
		switch(state)
		{
		case 0:
			if('\"'==cmdLine[i])
			{
				argv[(*argc)++]=cmdLine+i;
				state=2;
			}
			else if(' '!=cmdLine[i] && '\t'!=cmdLine[i])
			{
				argv[(*argc)++]=cmdLine+i;
				state=1;
			}
			else
			{
				cmdLine[i]=0;
			}
			break;
		case 1:
			if(' '==cmdLine[i] || '\t'==cmdLine[i])
			{
				cmdLine[i]=0;
				state=0;
			}
			break;
		case 2:
			if('\"'==cmdLine[i])
			{
				state=0;
			}
			break;
		}
	}
	return *argc;
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
