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
