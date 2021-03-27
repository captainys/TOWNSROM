#include <stdio.h>
#include <conio.h>
#include <stdlib.h>

#define DATA_BUF_LEN (256*1024)

unsigned int dataBufPtr=0;
unsigned char *dataBuf;

unsigned char *verifyBuf;


#define EMPTY_BUF_LEN 1024
unsigned char empty[EMPTY_BUF_LEN];


void Push(unsigned char d)
{
	if(dataBufPtr<DATA_BUF_LEN)
	{
		dataBuf[dataBufPtr++]=d;
	}
}

unsigned int Fibonacci(unsigned int fi,unsigned int fj)
{
	return fi+fj;
}

int Write(const char fName[],size_t position,size_t length,size_t stepWrite,int closeEveryPiece)
{
	FILE *fp=fopen(fName,"wb");
	int err=0;
	if(NULL==fp)
	{
		printf("Cannot open!\n");
		return 1;
	}
	size_t i;
	for(i=0; i<length; i+=stepWrite)
	{
		size_t stepSize=stepWrite;
		size_t bytesWritten=0;
		if(length<i+stepWrite)
		{
			stepSize=length-i;
		}
		bytesWritten=fwrite(dataBuf+position+i,1,stepSize,fp);
		if(bytesWritten!=stepSize)
		{
			printf("Write Size Error:\n");
			printf("  Should be: %u\n",stepSize);
			printf("  Returned:  %u\n",bytesWritten);
			err=1;
			goto RETURN;
		}
		if(0!=closeEveryPiece)
		{
			fclose(fp);
			fp=fopen(fName,"ab");
			if(NULL==fp)
			{
				printf("Cannot open for Append!\n");
				return 1;
			}
		}
	}

RETURN:
	fclose(fp);
	return err;
}
int Verify(const char fName[],size_t position,size_t length)
{
	FILE *fp=fopen(fName,"rb");
	size_t i,readSize;
	if(NULL==fp)
	{
		printf("Cannot open for Read!\n");
		return 1;
	}
	readSize=fread(verifyBuf,1,length,fp);
	fclose(fp);
	if(readSize!=length)
	{
		printf("Read Size Error:\n");
		printf("  Should be: %u\n",length);
		printf("  Returned:  %u\n",readSize);
		return 1;
	}

	for(i=0; i<length; ++i)
	{
		if(verifyBuf[i]!=dataBuf[position+i])
		{
			printf("Data Mismatch!\n");
			printf("  Position in File:       %u\n",i);
			printf("  Position in Data Buffer:%u\n",position+i);
			printf("  Read Back:              %02xh\n",verifyBuf[i]);
			printf("  Should Be:              %02xh\n",dataBuf[position+i]);
			return 1;
		}
	}
	return 0;
}
int TestRandomWrite(const char fName[],size_t position,size_t length,size_t stepWrite,int closeEveryPiece)
{
	int err=0;
	size_t i,nSeg;
	FILE *fp=fopen(fName,"wb");
	for(i=0; i<length; i+=EMPTY_BUF_LEN)
	{
		size_t stepSize,bytesWritten;
		if(i+EMPTY_BUF_LEN<length)
		{
			stepSize=EMPTY_BUF_LEN;
		}
		else
		{
			stepSize=length-i;
		}
		bytesWritten=fwrite(empty,1,stepSize,fp);
		if(bytesWritten!=stepSize)
		{
			printf("Write Size Error while Making a Background File:\n");
			printf("  Should be: %u\n",stepSize);
			printf("  Returned:  %u\n",bytesWritten);
			fclose(fp);
			return 1;
		}
	}
	fclose(fp);

	fp=fopen(fName,"rb+");
	if(NULL==fp)
	{
		printf("Cannot Open for Read/Write\n");
		return 1;
	}
	nSeg=(length+stepWrite-1)/stepWrite;
	for(i=nSeg-1; 0<=i && i<nSeg; --i) // Unsigned. 0<=i is automatic.
	{
		if(0==i)
		{
			outp(0x2386,0x02);
		}

		size_t pos=i*stepWrite;
		size_t stepSize,bytesWritten;
		if(pos+stepWrite<length)
		{
			stepSize=stepWrite;
		}
		else
		{
			stepSize=length-pos;
		}
		fseek(fp,pos,SEEK_SET);
		if(pos!=ftell(fp))
		{
			printf("Fseek Failed.\n");
			fclose(fp);
			return 1;
		}
		bytesWritten=fwrite(dataBuf+position+pos,1,stepSize,fp);
		if(bytesWritten!=stepSize)
		{
			printf("Write Size Error:\n");
			printf("  Position0: %u\n",position);
			printf("  Pos inFile:%u\n",pos);
			printf("  Position:  %u\n",position+pos);
			printf("  Should be: %u\n",stepSize);
			printf("  Returned:  %u\n",bytesWritten);
			fclose(fp);
			return 1;
		}
		if(0!=closeEveryPiece)
		{
			fclose(fp);
			fp=fopen(fName,"rb+");
			if(NULL==fp)
			{
				printf("Cannot Open for Read/Write (Piece by Piece)\n");
				return 1;
			}
		}
	}
	fclose(fp);

RETURN:
	return err;
}
int Test(const char fName[],size_t position,size_t length,size_t stepWrite,int closeEveryPiece)
{
	if(0!=Write(fName,position,length,stepWrite,closeEveryPiece) ||
	   0!=Verify(fName,position,length))
	{
		return 1;
	}
	return 0;
}

int main(int ac,char *av[])
{
	int i;

	dataBuf=(unsigned char *)malloc(DATA_BUF_LEN);
	verifyBuf=(unsigned char *)malloc(DATA_BUF_LEN);

	// Disregard overflow
	unsigned int f0=0,f1=1;
	while(dataBufPtr<DATA_BUF_LEN)
	{
		unsigned int f2=Fibonacci(f0,f1);
		Push(f2&255);
		Push((f2>>8)&255);
		Push((f2>>16)&255);
		f0=f1;
		f1=f2;
	}

	for(i=0; i<EMPTY_BUF_LEN; ++i)
	{
		empty[i]=0x77;
	}

	printf("Start\n");

	printf("Random Write Longer than Cluster\n");
	if(0!=TestRandomWrite("TEST.BIN",1487,71234,4321,0) ||
	   0!=Verify("TEST.BIN",1487,71234))
	{
		printf("Error!\n");
		return 1;
	}
	printf("Random Write Longer than Cluster (Close Every Step)\n");
	if(0!=TestRandomWrite("TEST.BIN",1487,71234,4321,1) ||
	   0!=Verify("TEST.BIN",1487,71234))
	{
		printf("Error!\n");
		return 1;
	}

	free(dataBuf);
	free(verifyBuf);

	printf("Test Passed.\n");

	return 0;
}
