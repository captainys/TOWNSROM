#include <fstream>
#include "fssimplewindow.h"



unsigned char dat[32768];

int main(int ac,char *av[])
{
	std::ifstream ifp(av[1],std::ios::binary);
	ifp.seekg(131072+32768,ifp.beg);
	ifp.read((char *)dat,32768);
	ifp.close();

	FsOpenWindow(0,0,800,600,1);

	for(;;)
	{
		FsPollDevice();
		auto key=FsInkey();
		if(FSKEY_ESC==key)
		{
			break;
		}

		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
		for(int i=0; i<256; ++i)
		{
			unsigned char bmp[128];
			auto ptr=dat+i*128;

			for(int y=0; y<32; ++y)
			{
				bmp[y*4  ]=ptr[(31-y)*4];
				bmp[y*4+1]=ptr[(31-y)*4+1];
				bmp[y*4+2]=ptr[(31-y)*4+2];
				bmp[y*4+3]=ptr[(31-y)*4+3];
			}

			int x=32*(i%16);
			int y=32*(i/16);
			glRasterPos2i(x,y+32);
			glBitmap(32,32,0,0,0,0,bmp);
		}
		FsSwapBuffers();
	}

	return 0;
}
