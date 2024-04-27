#include <stdio.h>
#include <string.h>
#include "UTIL.H"
#include "DEF.H"
#include "DOSLIB.H"



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

char *SkipHeadSpace(char *str)
{
	while(' '==*str || '\t'==*str)
	{
		++str;
	}
	return str;
}

int IsKanji(char c)
{
	unsigned int C=c;
	C&=0xFF;
	return 0x81<=C;
}

int ExpandEnvVar(unsigned int ENVSEG,char lineBuf[],unsigned int lineBufLen)
{
	int i;
	for(i=0; lineBuf[i]!=0; ++i)
	{
		if('%'==lineBuf[i])
		{
			if('0'<=lineBuf[i+1] && lineBuf[i+1]<='9') /* Command Argument.  Not Env Var. */
			{
			}
			else
			{
				int j,k;
				char var[MAX_PATH];
				const char far *toRepl;
				var[0]='%';
				for(k=1,j=i+1; lineBuf[j]!=0 && lineBuf[j]!='%'; ++j)
				{
					if(k<MAX_PATH-2)
					{
						var[k++]=lineBuf[j];
					}
				}
				var[k]=0;
				if(0==lineBuf[j]) /* Variable not closed. */
				{
					lineBuf[i]=0;
					return ERR;
				}

				Capitalize(var);
				toRepl=GetEnv(ENVSEG,var+1); /* Don't forget to skip first '%' */

				var[k]='%';
				var[k+1]=0;

				if(0==ReplaceStringNF(lineBuf,lineBufLen-1,var,toRepl))
				{
					return ERR;
				}
			}
		}
	}
	return OK;
}

int GetFirstArgument(char argv0[],const char cmdLine[])
{
	int i,writePtr=0;
	for(i=0; ' '==cmdLine[i] || '\t'==cmdLine[i]; ++i)
	{
	}
	for(i=i; 
	    writePtr+1<MAX_PATH &&
	    0!=cmdLine[i] &&
	    ASCII_CR!=cmdLine[i] &&
	    ASCII_LF!=cmdLine[i] &&
	    ' '!=cmdLine[i] &&
	    '\t'!=cmdLine[i]
	    ; ++i)
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

int ParseString(int *argc,char *argv[],char exe[],char cmdLine[])
{
	int i;
	int state=0;  /* 0:Not word  1:Word  2:Double-quote */
	*argc=0;

	if(NULL!=exe)
	{
		argv[0]=exe;
		++(*argc);
	}

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

unsigned int strncpy_close_nf(char *dst,char far *src,unsigned int dstLen)
{
	unsigned int i;
	for(i=0; i<dstLen-1 && 0!=src[i]; ++i)
	{
		dst[i]=src[i];
	}
	dst[i]=0;
	return i;
}

int CaseInsensitiveCompare(char a,char b)
{
	if('a'<=a && a<='z')
	{
		a=a+'A'-'a';
	}
	if('a'<=b && b<='z')
	{
		b=b+'A'-'a';
	}
	return a-b;
}

int ReplaceStringNF(char str[],unsigned int maxStrlen,const char from[],const char far to[])
{
	unsigned int orgStrlen,fromLen,toLen;
	orgStrlen=strlen(str);
	fromLen=strlen(from);
	toLen=_fstrlen(to);

	if(toLen<=fromLen) /* Shorten or no length change. */
	{
		int i;
		for(i=0; 0!=str[i]; ++i)
		{
			int j;
			for(j=0; j<fromLen; ++j)
			{
				if(0!=CaseInsensitiveCompare(str[i+j],from[j]))
				{
					break;
				}
			}
			if(j==fromLen) /* Found a Match! */
			{
				for(j=0; j<toLen; ++j)
				{
					str[i+j]=to[j];
				}
				for(j=i+toLen; j+fromLen-toLen<orgStrlen; ++j)
				{
					str[j]=str[j+fromLen-toLen];
				}
				str[j]=0;
			}
		}
		return i;
	}
	else
	{
		int i;
		unsigned int growth=toLen-fromLen;
		for(i=0; 0!=str[i]; ++i)
		{
			int j;
			for(j=0; j<fromLen; ++j)
			{
				if(0!=CaseInsensitiveCompare(str[i+j],from[j]))
				{
					break;
				}
			}
			if(j==fromLen) /* Found a Match! */
			{
				unsigned int newStrlen=orgStrlen+growth;
				if(maxStrlen<newStrlen)
				{
					/* Cannot expand.  Give up. */
					return 0;
				}

				str[orgStrlen+growth]=0;
				for(j=orgStrlen+growth-1; i+growth<=j; --j)
				{
					str[j]=str[j-growth];
				}
				for(j=0; j<toLen; ++j)
				{
					str[i+j]=to[j];
				}
				orgStrlen+=growth;
			}
		}
		return i;
	}
}

/*! Exactly same as ReplaceStringNF except that the last parameter is a far pointer. (Therefore _fstrlen -> strlen as well)
    That's why 8086 was a disgusting processor.
*/
int ReplaceStringNN(char str[],unsigned int maxStrlen,const char from[],const char to[])
{
	unsigned int orgStrlen,fromLen,toLen;
	orgStrlen=strlen(str);
	fromLen=strlen(from);
	toLen=strlen(to);

	if(toLen<=fromLen) /* Shorten or no length change. */
	{
		int i;
		for(i=0; 0!=str[i]; ++i)
		{
			int j;
			for(j=0; j<fromLen; ++j)
			{
				if(0!=CaseInsensitiveCompare(str[i+j],from[j]))
				{
					break;
				}
			}
			if(j==fromLen) /* Found a Match! */
			{
				for(j=0; j<toLen; ++j)
				{
					str[i+j]=to[j];
				}
				for(j=i+toLen; j+fromLen-toLen<orgStrlen; ++j)
				{
					str[j]=str[j+fromLen-toLen];
				}
				str[j]=0;
			}
		}
		return i;
	}
	else
	{
		int i;
		unsigned int growth=toLen-fromLen;
		for(i=0; 0!=str[i]; ++i)
		{
			int j;
			for(j=0; j<fromLen; ++j)
			{
				if(0!=CaseInsensitiveCompare(str[i+j],from[j]))
				{
					break;
				}
			}
			if(j==fromLen) /* Found a Match! */
			{
				unsigned int newStrlen=orgStrlen+growth;
				if(maxStrlen<newStrlen)
				{
					/* Cannot expand.  Give up. */
					return 0;
				}

				str[orgStrlen+growth]=0;
				for(j=orgStrlen+growth-1; i+growth<=j; --j)
				{
					str[j]=str[j-growth];
				}
				for(j=0; j<toLen; ++j)
				{
					str[i+j]=to[j];
				}
				orgStrlen+=growth;
			}
		}
		return i;
	}
}

int ExpandBatchArg(char lineBuf[],int batArgc,char *batArgv[],unsigned int lineBufLen)
{
	int i;
	int state=0; /* 0:Outside Env Var   1:Inside Env Var */
	int kanji=0;

	for(i=0; 0!=lineBuf[i]; ++i)
	{
		if(IsKanji(lineBuf[i]))
		{
			kanji=1;
			continue;
		}
		if(0!=kanji)
		{
			kanji=0;
			continue;
		}

		if(0==state)
		{
			if('%'==lineBuf[i])
			{
				if('0'<=lineBuf[i+1] && lineBuf[i+1]<='9')
				{
					int j,num=0;
					static char fromWord[8]={'%',0,0,0,0,0,0,0};
					for(j=0; '0'<=lineBuf[i+1+j] && lineBuf[i+1+j]<='9' && j<6; ++j)
					{
						fromWord[1+j]=lineBuf[i+1+j];
						num*=10;
						num+=(lineBuf[i+1+j]-'0');
					}
					if(num<batArgc)
					{
						if(0==ReplaceStringNN(lineBuf,lineBufLen-1,fromWord,batArgv[num]))
						{
							return ERR;
						}
					}
					else
					{
						ReplaceStringNN(lineBuf,lineBufLen-1,fromWord,"");
					}
				}
				else
				{
					state=1;
				}
			}
		}
		else
		{
			if('%'==lineBuf[i])
			{
				state=0;
			}
		}
	}
	return OK;
}

char *FindRedirection(char *foundChar,char arg[])
{
	int i,foundPos=-1;
	*foundChar=0;
	for(i=0; 0!=arg[i]; ++i)
	{
		if('<'==arg[i] || '>'==arg[i] || '|'==arg[i])
		{
			*foundChar=arg[i];
			foundPos=i;
			break;
		}
	}

	if(0!=*foundChar)
	{
		for(i=foundPos; 0<=i; --i)
		{
			if('>'==arg[i] || '<'==arg[i] || '|'==arg[i] || (0<=arg[i] && arg[i]<' '))
			{
				arg[i]=0;
			}
			else
			{
				break;
			}
		}
		return arg+foundPos+1;
	}

	return NULL;
}
