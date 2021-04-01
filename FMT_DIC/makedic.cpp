#include <stdio.h>


unsigned char buf[512*1024];

int main(void)
{
	for(auto &b : buf)
	{
		b=0xff;
	}
	FILE *fp=fopen("FMT_DIC.ROM","wb");
	fwrite(buf,1,sizeof(buf),fp);
	fclose(fp);
	return 0;
}
