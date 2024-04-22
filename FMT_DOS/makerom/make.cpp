#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <cstdint>
#include <vector>
#include <string>

unsigned char SHSUCDXPatchFrom[]=
{
	// Looks like DOS will return seconds by this.
	// PUSH WORD PTR 0
	// POP DS
	// MOV AX,[046CH]
	0x6A,0x00,0x1F,0xA1,0x6C,0x04
};
unsigned char SHSUCDXPatchTo[]=
{
	// Use YSDOS extension.
	// MOV AX,77D2H
	// INT 21H
	// NOP
	0xB8,0xD2,0x77,0xCD,0x21,0x90
};




const uint32_t ROM_SIZE=512*1024;     // 512KB ROM
const uint32_t SND_START=0x00040000;  // Sound data starts at 256KB border.
unsigned char rom[ROM_SIZE];

const uint32_t CLUSTER_0_PTR=4096;
const uint32_t CLUSTER_SIZE=1024;
const uint32_t MSDOS_SYS_CLUSTER=0x4E;  // For some reason, IO.SYS fails to read MSDOS.SYS unless it starts at 0x4E

bool ApplyPatch(std::vector <unsigned char> &data,size_t fromLen,unsigned char from[],size_t toLen,unsigned char to[],std::string label)
{
	bool foundMatch=false;
	if(fromLen!=toLen)
	{
		std::cout << "Implementation error!  Patch size mismatch!" << std::endl;
		return false;
	}
	std::cout << "Applying " << label << std::endl;
	for(size_t i=0; i+fromLen<=data.size(); ++i)
	{
		bool match=true;
		for(size_t j=0; j<fromLen; ++j)
		{
			if(data[i+j]!=from[j])
			{
				match=false;
				break;
			}
		}
		if(true==match)
		{
			printf("Found at 0x%04llx\n",i);
			foundMatch=true;
			for(size_t j=0; j<fromLen; ++j)
			{
				data[i+j]=to[j];
			}
		}
	}
	return foundMatch;
}

std::vector <unsigned char> ReadFile(std::string fName)
{
	std::ifstream fp(fName,std::ios::binary);
	if(true!=fp.is_open())
	{
		std::cout << "Cannot open " << fName << std::endl;
		exit(1);
	}

	fp.seekg(0,std::ios::end);
	auto fSize=fp.tellg();
	fp.seekg(0,std::ios::beg);

	std::vector <unsigned char> buf;
	buf.resize(fSize);

	fp.read((char *)buf.data(),fSize);

	return buf;
}

void SetDword(unsigned char *dst,uint32_t src)
{
	dst[0]=src&255;
	dst[1]=(src>>8)&255;
	dst[2]=(src>>16)&255;
	dst[3]=(src>>24)&255;
}
void SetWord(unsigned char *dst,uint16_t src)
{
	dst[0]=src&255;
	dst[1]=(src>>8)&255;
}

void WriteSoundData(uint32_t &sndOffset,uint32_t &dataOffset,const std::vector <unsigned char> &src,std::string soundName)
{
	auto soundArea=rom+SND_START;

	if(ROM_SIZE<=SND_START+dataOffset+src.size())
	{
		std::cout << "Overflow." << std::endl;
		exit(1);
	}

	// Record where the sound is stored.
	SetDword(soundArea+sndOffset,dataOffset);

	// Write data
	for(int i=0; i<src.size(); ++i)
	{
		soundArea[dataOffset+i]=src[i];
	}

	// Change name
	for(int i=0; i<8; ++i)
	{
		if(i<soundName.size())
		{
			soundArea[dataOffset+i]=soundName[i];
		}
		else
		{
			soundArea[dataOffset+i]=0;
		}
	}

	sndOffset+=4;
	dataOffset+=src.size();
}

void WriteCluster(unsigned int clusterNum,unsigned int data)
{
	unsigned char *fatPrimaryPtr=rom+0x200;
	unsigned char *fatBackUpPtr=rom+0x600;

	unsigned int pairPtr=(clusterNum/2)*3;
	unsigned int mask=(0==(clusterNum&1) ? 0xfff000 : 0xfff);
	unsigned int shift=(0==(clusterNum&1) ? 0 : 12);
	for(int i=0; i<2; ++i)
	{
		unsigned char *fatPtr=(0==i ? fatPrimaryPtr : fatBackUpPtr);

		unsigned int clusterPair=
			fatPtr[pairPtr]|
			(fatPtr[pairPtr+1]<<8)|
			(fatPtr[pairPtr+2]<<16);

		clusterPair&=mask;
		clusterPair|=(data<<shift);

		fatPtr[pairPtr]  =clusterPair&0xff;
		fatPtr[pairPtr+1]=(clusterPair>>8)&0xff;
		fatPtr[pairPtr+2]=(clusterPair>>16)&0xff;
	}
}

void SetTime(unsigned char *ptr)
{
}
void SetDate(unsigned char *ptr)
{
}

void WriteOneFile(std::string fName,uint32_t &startCluster)
{
	auto dat=ReadFile("files/"+fName);
	std::cout << fName << " " << dat.size() << " bytes." << std::endl;

	if("SHSUCDX.COM"==fName)
	{
		ApplyPatch(dat,sizeof(SHSUCDXPatchFrom),SHSUCDXPatchFrom,sizeof(SHSUCDXPatchTo),SHSUCDXPatchTo,"SHSUCDX Clock Patch.");
	}

	uint32_t nCluster=(dat.size()+(CLUSTER_SIZE-1))/CLUSTER_SIZE;

	std::cout << "Takes " << nCluster << " clusters from " << startCluster << std::endl;

	for(int i=0; i<nCluster; ++i)
	{
		auto cluster=startCluster+i;
		if(i==(nCluster-1))
		{
			WriteCluster(cluster,0xFFF);
		}
		else
		{
			WriteCluster(cluster,cluster+1);
		}
	}

	auto ptr=CLUSTER_0_PTR+CLUSTER_SIZE*startCluster;
	for(uint32_t i=0; i<dat.size(); ++i)
	{
		rom[ptr+i]=dat[i];
	}


	unsigned char *dirPtr=rom+0xA00;
	while(0!=*dirPtr)
	{
		dirPtr+=0x20;
	}
	std::cout << "Directory Entry Offset " << (dirPtr-rom) << std::endl;

	// Clear Directory Entry
	for(int i=0; i<11; ++i)
	{
		dirPtr[i]=' ';
	}
	for(int i=12; i<0x20; ++i)
	{
		dirPtr[i]=0;
	}

	int fileNamePtr=0;
	for(auto c : fName)
	{
		if('.'==c)
		{
			fileNamePtr=8;
		}
		else
		{
			dirPtr[fileNamePtr++]=c;
		}
		if(11<=fileNamePtr)
		{
			break;
		}
	}
	dirPtr[11]=0x20; // 0x20:Archive
	SetTime(dirPtr+0x16);
	SetDate(dirPtr+0x18);
	SetWord(dirPtr+0x1A,(uint16_t)startCluster);
	SetDword(dirPtr+0x1C,dat.size());

	startCluster+=nCluster;
}

void WriteFiles(void)
{
	rom[0]='I';
	rom[1]='P';
	rom[2]='L';
	rom[3]='4';
	rom[4]=0xCB; // RET


	unsigned char *dirPtr=rom+0xA00;
	dirPtr[ 0]='O';
	dirPtr[ 1]='S';
	dirPtr[ 2]='-';
	dirPtr[ 3]='R';
	dirPtr[ 4]='O';
	dirPtr[ 5]='M';
	dirPtr[ 6]=' ';
	dirPtr[ 7]=' ';

	dirPtr[ 8]=' ';
	dirPtr[ 9]=' ';
	dirPtr[10]=' ';
	dirPtr[11]=0x28;  // 0x20:Archive Bit,  0x08:Volume Bit

	SetTime(dirPtr+0x16);
	SetDate(dirPtr+0x18);

	WriteCluster(0,0xFFB);
	WriteCluster(1,0xFFF);

	uint32_t startCluster=MSDOS_SYS_CLUSTER;
	std::ifstream ifp("files/files.txt");
	while(true!=ifp.eof())
	{
		std::string fName;
		std::getline(ifp,fName);
		if(""!=fName)
		{
			WriteOneFile(fName,startCluster);
		}
	}
}

void WriteSound(void)
{
	const uint32_t numSound=10;  // 10 sound data
	std::string sndName[numSound]=
	{
		"oha",
		"konniti",
		"konban",
		"bye",
		"sayo",
		"oya",
		"era",
		"nyu",
		"gomenne",
		"kak",
	};
	std::string sndFileName[numSound]=
	{
		"voice/OHA.snd",
		"voice/KONNITI.snd",
		"voice/KONBAN.snd",
		"voice/BYE.snd",
		"voice/SAYO.snd",
		"voice/OYA.snd",
		"voice/ERA.snd",
		"voice/NYU.snd",
		"voice/GOMENNE.snd",
		"voice/KAK.snd",
	};
	SetDword(rom+SND_START,numSound);
	uint32_t sndOffset=4;
	uint32_t dataOffset=4+4*numSound;
	for(int i=0; i<numSound; ++i)
	{
		auto sndData=ReadFile(sndFileName[i]);
		std::cout << sndFileName[i] << "=" << sndData.size() << " bytes." << std::endl;
		while(0!=(sndData.size()&3))
		{
			sndData.push_back(0);
		}
		std::cout << "Padded to " << sndData.size() << " bytes." << std::endl;

		WriteSoundData(sndOffset,dataOffset,sndData,sndName[i]);
	}
}

void PrintClusters(void)
{
	unsigned char *fat=rom+0x200;
	for(int i=0; i<256/3; ++i)
	{
		unsigned int pair=fat[i*3]|(fat[i*3+1]<<8)|(fat[i*3+2]<<16);
		printf("0x%02x  %03x\n",i*2,pair&0xFFF);
		printf("0x%02x  %03x\n",i*2+1,(pair>>12)&0xFFF);
	}
}

int main(void)
{
	for(auto &c : rom)
	{
		c=0;
	}

	WriteFiles();
	WriteSound();

	PrintClusters();

	std::ofstream ofp("FMT_DOS.ROM",std::ios::binary);
	ofp.write((const char *)rom,ROM_SIZE);
	ofp.close();

	return 0;
}
