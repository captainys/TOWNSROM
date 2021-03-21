#include <stdio.h>
#include "DOSLIB.H"



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
	ptr[i++]=0;
	ptr[i++]=1;
	ptr[i++]=0;
	for(j=0; 0!=YAMANDCOM[j]; ++j)
	{
		ptr[i+j]=YAMANDCOM[j];
	}
}

