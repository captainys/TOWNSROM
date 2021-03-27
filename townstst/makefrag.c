#include <stdio.h>


#define DATA_BUF_LEN (1024*20)
unsigned char dataBuf[DATA_BUF_LEN];



void MakeFile(unsigned char num)
{
	for(int i=0; i<DATA_BUF_LEN; ++i)
	{
		dataBuf[i]=num;
	}

	char fName[256];
	sprintf(fName,"%d",num);
	FILE *fp=fopen(fName,"wb");
	fwrite(dataBuf,1,DATA_BUF_LEN,fp);
	fclose(fp);
}

void RemoveFile(unsigned char num)
{
	char fName[256];
	sprintf(fName,"%d",num);
	remove(fName);
}

int main(void)
{
	int i;
	for(i=0; i<60; ++i)
	{
		MakeFile(i);
	}
	for(i=0; i<60; i+=2)
	{
		RemoveFile(i);
	}
	return 0;
}
