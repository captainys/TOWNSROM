#include <stdio.h>
#include <string.h>


extern unsigned int DOSCALL_OPEN_RD(const char fName[]);
extern unsigned int DOSCALL_OPEN_WR(const char fName[]);
extern unsigned int DOSCALL_CLOSE(int fileHandle);
extern unsigned int DOSCALL_WRITE(int fileHandle,unsigned int len,const char buf[]);



#define FNAME "DATAFILE"
#define OVERWRITE "CARNEGIE MELLON UNIVERSITY"

void MakeFile(void)
{
	FILE *fp=fopen(FNAME,"w");
	fprintf(fp,"Test\n");
	fclose(fp);
}

int main(void)
{
	int fp,fp2;

	MakeFile();

	fp=DOSCALL_OPEN_RD(FNAME);
	printf("First Open (RD) %08x\n",fp);
	fp2=DOSCALL_OPEN_RD(FNAME);
	printf("Second Open (RD) %08x\n",fp2);
	DOSCALL_CLOSE(fp);
	DOSCALL_CLOSE(fp2);

	printf(">");
	getchar();

	fp=DOSCALL_OPEN_RD(FNAME);
	printf("First Open (RD) %08x\n",fp);
	fp2=DOSCALL_OPEN_WR(FNAME);
	printf("Second Open (WR) %08x\n",fp2);
	DOSCALL_CLOSE(fp);
	DOSCALL_CLOSE(fp2);

	printf(">");
	getchar();

	fp=DOSCALL_OPEN_WR(FNAME);
	printf("First Open (WR) %08x\n",fp);
	fp2=DOSCALL_OPEN_WR(FNAME);
	printf("Second Open (WR) %08x\n",fp2);
	DOSCALL_WRITE(fp2,strlen(OVERWRITE),OVERWRITE);
	DOSCALL_CLOSE(fp);
	DOSCALL_CLOSE(fp2);

	printf(">");
	getchar();

	fp=DOSCALL_OPEN_WR(FNAME);
	printf("First Open (WR) %08x\n",fp);
	fp2=DOSCALL_OPEN_RD(FNAME);
	printf("Second Open (RD) %08x\n",fp2);
	DOSCALL_CLOSE(fp);
	DOSCALL_CLOSE(fp2);

	return 0;
}
