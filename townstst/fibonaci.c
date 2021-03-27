#include <stdio.h>
#include <stdlib.h>

#define DATA_BUF_LEN (256*1024)

unsigned int dataBufPtr=0;
unsigned char *dataBuf;

unsigned char *verifyBuf;

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

int main(void)
{
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

	// This is the way I made the data disk.
	// FILE *fp=fopen("fibo24.bin","wb");
	// fwrite(dataBuf,1,DATA_BUF_LEN,fp);
	// fclose(fp);

	printf("Start\n");

	FILE *fp;
	size_t readSize,i,position;

	fp=fopen("fibo24.bin","rb");
	if(NULL==fp)
	{
		fprintf(stderr,"Cannot Open!\n");
		return 1;
	}
	readSize=fread(verifyBuf,1,DATA_BUF_LEN,fp);
	if(readSize!=DATA_BUF_LEN)
	{
		fprintf(stderr,"Read Size Error!\n");
		fprintf(stderr,"  Should be %d!\n",DATA_BUF_LEN);
		fprintf(stderr,"  Returned  %d!\n",readSize);
		return 1;
	}
	for(i=0; i<DATA_BUF_LEN; ++i)
	{
		if(verifyBuf[i]!=dataBuf[i])
		{
			fprintf(stderr,"Data Mismatch at %u(0x%x)!\n",i,i);
			fprintf(stderr,"  Should be %d!\n",dataBuf[i]);
			fprintf(stderr,"  Returned  %d!\n",verifyBuf[i]);
			return 1;
		}
	}

	readSize=ftell(fp);
	if(readSize!=DATA_BUF_LEN)
	{
		fprintf(stderr,"Wrong File Position Returned.\n");
		fprintf(stderr,"  Should be %d\n",DATA_BUF_LEN);
		fprintf(stderr,"  Returned  %d\n",readSize);
		return 1;
	}

	fclose(fp);



	fp=fopen("fibo24.bin","rb");
	if(NULL==fp)
	{
		fprintf(stderr,"Cannot Open!\n");
		return 1;
	}
	fseek(fp,0,SEEK_END);
	readSize=ftell(fp);
	if(readSize!=DATA_BUF_LEN)
	{
		fprintf(stderr,"Wrong File Size Returned.\n");
		fprintf(stderr,"  Should be %d\n",DATA_BUF_LEN);
		fprintf(stderr,"  Returned  %d\n",readSize);
		return 1;
	}


	printf("Testing Short Read.\n");
	for(position=1271; position<65536; position+=5677)
	{
		size_t positionReturned;
		fseek(fp,position,SEEK_SET);
		positionReturned=ftell(fp);
		if(position!=positionReturned)
		{
			fprintf(stderr,"Wrong File Position Returned.\n");
			fprintf(stderr,"  Should be %d\n",position);
			fprintf(stderr,"  Returned  %d\n",positionReturned);
			return 1;
		}

		size_t toRead=63;
		readSize=fread(verifyBuf,1,toRead,fp);
		positionReturned=ftell(fp);
		if(position+toRead!=positionReturned)
		{
			fprintf(stderr,"Wrong File Position Returned.\n");
			fprintf(stderr,"  Should be %d\n",position+toRead);
			fprintf(stderr,"  Returned  %d\n",positionReturned);
			return 1;
		}

		for(i=0; i<toRead; ++i)
		{
			if(verifyBuf[i]!=dataBuf[position+i])
			{
				fprintf(stderr,"Data Mismatch at %u(0x%x)!\n",position+i,position+i);
				fprintf(stderr,"  Should be %d!\n",dataBuf[position+i]);
				fprintf(stderr,"  Returned  %d!\n",verifyBuf[i]);
				return 1;
			}
		}
	}



	printf("Testing Medium Read.\n");
	for(position=81173; position>8192; position-=5677)
	{
		size_t positionReturned;
		fseek(fp,position,SEEK_SET);
		positionReturned=ftell(fp);
		if(position!=positionReturned)
		{
			fprintf(stderr,"Wrong File Position Returned.\n");
			fprintf(stderr,"  Should be %d\n",position);
			fprintf(stderr,"  Returned  %d\n",positionReturned);
			return 1;
		}

		size_t toRead=4096;
		readSize=fread(verifyBuf,1,toRead,fp);
		positionReturned=ftell(fp);
		if(position+toRead!=positionReturned)
		{
			fprintf(stderr,"Wrong File Position Returned.\n");
			fprintf(stderr,"  Should be %d\n",position+toRead);
			fprintf(stderr,"  Returned  %d\n",positionReturned);
			return 1;
		}

		for(i=0; i<toRead; ++i)
		{
			if(verifyBuf[i]!=dataBuf[position+i])
			{
				fprintf(stderr,"Data Mismatch at %u(0x%x)!\n",position+i,position+i);
				fprintf(stderr,"  Should be %d!\n",dataBuf[position+i]);
				fprintf(stderr,"  Returned  %d!\n",verifyBuf[i]);
				return 1;
			}
		}
	}


	printf("Testing Long Read.\n");
	for(position=180000; position>80000; position-=65536)
	{
		size_t positionReturned;
		fseek(fp,position,SEEK_SET);
		positionReturned=ftell(fp);
		if(position!=positionReturned)
		{
			fprintf(stderr,"Wrong File Position Returned.\n");
			fprintf(stderr,"  Should be %d\n",position);
			fprintf(stderr,"  Returned  %d\n",positionReturned);
			return 1;
		}

		size_t toRead=68000;
		readSize=fread(verifyBuf,1,toRead,fp);
		positionReturned=ftell(fp);
		if(position+toRead!=positionReturned)
		{
			fprintf(stderr,"Wrong File Position Returned.\n");
			fprintf(stderr,"  Should be %d\n",position+toRead);
			fprintf(stderr,"  Returned  %d\n",positionReturned);
			return 1;
		}

		for(i=0; i<toRead; ++i)
		{
			if(verifyBuf[i]!=dataBuf[position+i])
			{
				fprintf(stderr,"Data Mismatch at %u(0x%x)!\n",position+i,position+i);
				fprintf(stderr,"  Should be %d\n",dataBuf[position+i]);
				fprintf(stderr,"  Returned  %d\n",verifyBuf[i]);
				fprintf(stderr,"  Read Size %d\n",toRead);
				fprintf(stderr,"  Start Pos %d\n",position);
				fprintf(stderr,"  Offset    %d\n",i);
				return 1;
			}
		}
	}

	printf("Testing Reading Last Bytes\n");
	for(i=0; i<80000; i=(i+1)*2)
	{
		fseek(fp,DATA_BUF_LEN-i,SEEK_SET);
		readSize=fread(verifyBuf,1,DATA_BUF_LEN,fp);
		if(readSize!=i)
		{
			fprintf(stderr,"Wrong Read Size.\n");
			fprintf(stderr,"  Should be %d\n",i);
			fprintf(stderr,"  Returned  %d\n",readSize);
			return 1;
		}
		unsigned int j;
		for(j=0; j<i; ++j)
		{
			if(verifyBuf[j]!=dataBuf[DATA_BUF_LEN-i+j])
			{
				fprintf(stderr,"Data Mismatch at %u(0x%x)!\n",DATA_BUF_LEN-i+j,DATA_BUF_LEN-i+j);
				fprintf(stderr,"  Should be %d!\n",dataBuf[DATA_BUF_LEN-i+j]);
				fprintf(stderr,"  Returned  %d!\n",verifyBuf[j]);
				return 1;
			}
		}
	}


	printf("Step-by-Step Read (Cluster Boundary)\n");
	position=0x1000;
	readSize=1024;
	fseek(fp,position,SEEK_SET);
	for(position=position; position>0x8000; position+=readSize)
	{
		fread(verifyBuf,1,readSize,fp);
		for(int j=0; j<readSize; ++j)
		{
			if(verifyBuf[j]!=dataBuf[position+j])
			{
				fprintf(stderr,"Data Mismatch at %u(0x%x)!\n",position+j,position+j);
				fprintf(stderr,"  Should be %d!\n",dataBuf[position+j]);
				fprintf(stderr,"  Returned  %d!\n",verifyBuf[j]);
				return 1;
			}
		}
	}

	printf("Step-by-Step Read (Shorter than Cluster)\n");
	position=0x8000;
	readSize=1011;
	fseek(fp,position,SEEK_SET);
	for(position=position; position>0x10000; position+=readSize)
	{
		fread(verifyBuf,1,readSize,fp);
		for(int j=0; j<readSize; ++j)
		{
			if(verifyBuf[j]!=dataBuf[position+j])
			{
				fprintf(stderr,"Data Mismatch at %u(0x%x)!\n",position+j,position+j);
				fprintf(stderr,"  Should be %d!\n",dataBuf[position+j]);
				fprintf(stderr,"  Returned  %d!\n",verifyBuf[j]);
				return 1;
			}
		}
	}

	printf("Step-by-Step Read (Longer than Cluster)\n");
	position=0x10000;
	readSize=1237;
	fseek(fp,position,SEEK_SET);
	for(position=position; position>0x18000; position+=readSize)
	{
		fread(verifyBuf,1,readSize,fp);
		for(int j=0; j<readSize; ++j)
		{
			if(verifyBuf[j]!=dataBuf[position+j])
			{
				fprintf(stderr,"Data Mismatch at %u(0x%x)!\n",position+j,position+j);
				fprintf(stderr,"  Should be %d!\n",dataBuf[position+j]);
				fprintf(stderr,"  Returned  %d!\n",verifyBuf[j]);
				return 1;
			}
		}
	}



	fclose(fp);

	free(dataBuf);
	free(verifyBuf);

	printf("Test Passed.\n");

	return 0;
}
