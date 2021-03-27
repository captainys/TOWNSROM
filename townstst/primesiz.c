#include <stdio.h>


#define DATA_BUF_LEN (7919)
unsigned char dataBuf[DATA_BUF_LEN];

void Fill(void)
{
	char *str="TSUGARUFMTOWNS";
	for(int i=0; i<DATA_BUF_LEN; ++i)
	{
		dataBuf[i]=str[i%14];
	}
}

int main(void)
{
	Fill();
	FILE *fp=fopen("primsiz.bin","wb");
	fwrite(dataBuf,1,DATA_BUF_LEN,fp);
	fclose(fp);
	return 0;
}
