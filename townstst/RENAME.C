#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <direct.h>



extern int DOSCALL_RENAME(const char fromFn[],const char toFn[]);

void MakeTestFile(const char fName[])
{
	FILE *fp=fopen(fName,"w");
	if(NULL!=fp)
	{
		fprintf(fp,"Test\n");
		fclose(fp);
	}
	else
	{
		fprintf(stderr,"Cannot create a test file. (%s)\n",fName);
		exit(1);
	}
}


#define MATCH 0
#define DIFFERENT 1
int CheckTestFile(const char fName[])
{
	FILE *fp=fopen(fName,"r");
	if(NULL==fp)
	{
		return DIFFERENT;
	}
	char str[256];
	fgets(str,255,fp);
	fclose(fp);
	if(0!=strcmp(str,"Test\n"))
	{
		return DIFFERENT;
	}
	return MATCH;
}

int main(void)
{
	int errCode;
	mkdir("xyz");
	mkdir("xyz/abc");
	mkdir("xyz/abc/boo");

	mkdir("000");
	mkdir("000/111");

	fprintf(stderr,"Test rename within the root directory\n");
	MakeTestFile("test.txt");
	errCode=DOSCALL_RENAME("test.txt","renamed.aaa");
	if(0!=errCode)
	{
		fprintf(stderr,"DOS RENAME (AH=56h) Returned Error %d\n",errCode);
		return 1;
	}
	if(MATCH==CheckTestFile("test.txt"))
	{
		fprintf(stderr,"test.txt is supposed to be gone.\n");
		return 1;
	}
	if(MATCH!=CheckTestFile("renamed.aaa"))
	{
		fprintf(stderr,"renamed.aaa doesn't exist.\n");
		return 1;
	}
	remove("renamed.aaa");


	fprintf(stderr,"Test witihn a sub-directory\n");
	MakeTestFile("xyz/abc/boo/test.txt");
	errCode=DOSCALL_RENAME("xyz/abc/boo/test.txt","xyz/abc/boo/renamed.aaa");
	if(0!=errCode)
	{
		fprintf(stderr,"DOS RENAME (AH=56h) Returned Error %d\n",errCode);
		return 1;
	}
	if(MATCH==CheckTestFile("xyz/abc/boo/test.txt"))
	{
		fprintf(stderr,"test.txt is supposed to be gone.\n");
		return 1;
	}
	if(MATCH!=CheckTestFile("xyz/abc/boo/renamed.aaa"))
	{
		fprintf(stderr,"renamed.aaa doesn't exist.\n");
		return 1;
	}
	remove("xyz/abc/boo/renamed.aaa");


	fprintf(stderr,"Test moving across sub-directories\n");
	MakeTestFile("xyz/abc/boo/test.txt");
	errCode=DOSCALL_RENAME("xyz/abc/boo/test.txt","000/111/renamed.aaa");
	if(0!=errCode)
	{
		fprintf(stderr,"DOS RENAME (AH=56h) Returned Error %d\n",errCode);
		return 1;
	}
	if(MATCH==CheckTestFile("xyz/abc/boo/test.txt"))
	{
		fprintf(stderr,"test.txt is supposed to be gone.\n");
		return 1;
	}
	if(MATCH!=CheckTestFile("000/111/renamed.aaa"))
	{
		fprintf(stderr,"renamed.aaa doesn't exist.\n");
		return 1;
	}
	remove("000/111/renamed.aaa");


	fprintf(stderr,"Test moving from the root to a sub-directory\n");
	MakeTestFile("/test.txt");
	errCode=DOSCALL_RENAME("/test.txt","xyz/abc/renamed.aaa");
	if(0!=errCode)
	{
		fprintf(stderr,"DOS RENAME (AH=56h) Returned Error %d\n",errCode);
		return 1;
	}
	if(MATCH==CheckTestFile("/test.txt"))
	{
		fprintf(stderr,"test.txt is supposed to be gone.\n");
		return 1;
	}
	if(MATCH!=CheckTestFile("xyz/abc/renamed.aaa"))
	{
		fprintf(stderr,"renamed.aaa doesn't exist.\n");
		return 1;
	}
	remove("xyz/abc/renamed.aaa");


	fprintf(stderr,"Test moving from a sub- to the root directory\n");
	MakeTestFile("xyz/abc/test.txt");
	errCode=DOSCALL_RENAME("xyz/abc/test.txt","/renamed.aaa");
	if(0!=errCode)
	{
		fprintf(stderr,"DOS RENAME (AH=56h) Returned Error %d\n",errCode);
		return 1;
	}
	if(MATCH==CheckTestFile("xyz/abc/test.txt"))
	{
		fprintf(stderr,"test.txt is supposed to be gone.\n");
		return 1;
	}
	if(MATCH!=CheckTestFile("/renamed.aaa"))
	{
		fprintf(stderr,"renamed.aaa doesn't exist.\n");
		return 1;
	}
	remove("/renamed.aaa");


	fprintf(stderr,"Test Passed\n");

	return 0;
}
