#include <stdio.h>
#include <string.h>
#include "UTIL.H"
#include "DEF.H"



static char utilFNBuf[MAX_PATH];

void Capitalize(char str[])
{
	int i;
	for(i=0; 0!=str[i]; ++i)
	{
		if(IsKanji(str[i]) && 0!=str[i+1])
		{
			++i;
		}
		else if('a'<=str[i] && str[i]<='z')
		{
			str[i]+=('A'-'a');
		}
	}
}

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

int GetFirstArgument(char argv0[],const char cmdLine[])
{
	int i,writePtr=0;
	for(i=0; ' '==cmdLine[i] || '\t'==cmdLine[i]; ++i)
	{
	}
	for(i=i; writePtr+1<MAX_PATH && 0!=cmdLine[i] && ' '!=cmdLine[i] && '\t'!=cmdLine[i]; ++i)
	{
		argv0[writePtr++]=cmdLine[i];
	}
	argv0[writePtr]=0;
	return i;
}

char *GetAfterFirstArgument(char cmdLine[],int argv0Len)
{
	if(0==cmdLine[argv0Len])
	{
		return cmdLine+argv0Len;
	}
	else
	{
		return cmdLine+argv0Len+1;
	}
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

const char *GetExtension(const char *fName)
{
	while(0!=(*fName))
	{
		if('.'==(*fName))
		{
			return fName;
		}
		++fName;
	}
	return fName;
}

void ReplaceExtension(char fName[],const char ext[])
{
	size_t l=strlen(ext);
	int i;
	if('.'!=ext[0])
	{
		++l;
	}
	for(i=0; 0!=fName[i] && '.'!=fName[i]; ++i)
	{
	}
	if(i+l+1<MAX_PATH)
	{
		if('.'!=ext[0])
		{
			fName[i++]='.';
		}
		strcpy(fName+i,ext);
	}
}
