#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <direct.h>
#include <dos.h>


#define SUBDIR "SUBDIR"


/*
0x800 bytes times 2=0x1000 bytes per cluster.
32 bytes per dirent
0x1000 bytes for 128 dirents
*/
#define NUM_FILES 260

int main(void)
{
	int i;
	struct _find_t findStruct;
	FILE *fp;
	char fName[256];
	unsigned char foundCount[NUM_FILES];
	int first=1;
	int curDir=0,parDir=0,count=0,nCreated=0;

	printf("Generating\n");

	for(i=0; i<NUM_FILES; ++i)
	{
		foundCount[i]=0;
	}

	mkdir(SUBDIR);
	for(i=0; i<NUM_FILES; ++i)
	{
		sprintf(fName,"%s\\%08d.dat",SUBDIR,i);
		fp=fopen(fName,"w");
		fprintf(fp,"%d\n",i);
		fclose(fp);
		++nCreated;
	}

	printf("Verifying\n");

	if(NUM_FILES!=nCreated)
	{
		printf("Error in number of files created.\n");
		printf("  Should be: %d\n",NUM_FILES);
		printf("  Created:   %d\n",nCreated);
		return 1;
	}

	sprintf(fName,"%s\\*.*",SUBDIR);
	for(;;)
	{
		int err=1;
		if(0!=first)
		{
			err=_dos_findfirst(fName,0x16,&findStruct);
			first=0;
		}
		else
		{
			err=_dos_findnext(&findStruct);
		}
		if(0!=err)
		{
			break;
		}

		if(0==strcmp(findStruct.name,"."))
		{
			curDir=1;
		}
		else if(0==strcmp(findStruct.name,".."))
		{
			parDir=1;
		}
		else
		{
			int num;
			++count;
			for(i=0; i<8; ++i)
			{
				if('0'<=findStruct.name[i] || findStruct.name[i]<='9')
				{
				}
				else
				{
					printf("Wrong file name!\n");
					printf("%s\n",findStruct.name);
					exit(1);
				}
			}
			num=atoi(findStruct.name);
			if(0<=num && num<NUM_FILES)
			{
				++foundCount[num];
			}
			else
			{
				printf("Wrong number!\n");
				printf("%s\n",findStruct.name);
				exit(1);
			}
			if(0!=strcmp(findStruct.name+8,".DAT"))
			{
				printf("Wrong extension!\n");
				printf("%s\n",findStruct.name);
				exit(1);
			}
		}
	}
	printf("\n");

	for(i=0; i<NUM_FILES; ++i)
	{
		if(0==foundCount[i])
		{
			printf("File %08d.DAT not found.\n",i);
			return 1;
		}
		if(1<foundCount[i])
		{
			printf("File %08d.DAT found multiple times.\n",i);
			return 1;
		}
	}

	if(count!=nCreated)
	{
		printf("Wrong file count!\n");
		printf("  Should be:%d\n",nCreated);
		printf("  Found:    %d\n",count);
		exit(1);
	}
	if(0==curDir)
	{
		printf("Current dir not included!\n");
		exit(1);
	}
	if(0==parDir)
	{
		printf("Parent dir not included!\n");
		exit(1);
	}

	printf("Test Passes!\n");
	return 0;
}
