/*
version 2003.03.04.1
   BMP to TOWNS System Icon Data Converter
   
   by Kasanova
*/

/*
	システムアイコン作成用BMPのフォーマット

	・BMPのサイズは512x544(横に大きいぶんには問題ない)
	・256色BMPのみ対応
	・色番号0が1、それ以外の色番号はすべて0に2値変換される
	・32x32ドットのアイコンを 横8x縦16 で配置
	・一番下の列には32x32ドットの起動用アイコンを横に8個配置
	・[パターン]と[マスクパターン]の2つを横に並べて配置すること
	・起動用アイコンにマスクパターンはいらない
	・したがって下のような構成になる
	
	----- 64ドット -----
	[パターン0][マスク0] [パターン1][マスク1] [パターン2][マスク2] [パターン3][マスク3]・・・
	[パターン8][マスク8] [パターン9][マスク9] [パターンa][マスクa] [パターンb][マスクb]・・・
	   ・
	   ・
	   ・
	[パターン0][パターン1][パターン2][パターン3][パターン4][パターン5][パターン6][パターン7]
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BMPHEADERSIZE    14
#define ICONMAX         128
#define ICONBOOTMAX       8
#define ICONPATTERNSIZE 256
#define ICON_W           32
#define ICON_H           32
#define ICONPITCH       (ICON_W/8)

#define ICONMATRIX_W   8
#define ICONMATRIX_H  (16+1)

char srcfile[128];
char dstfile[]  = "fmt_sys2.icn";
char dstfile2[] = "fmt_sys5.ic2";
char buffer[2048];
char iconbuffer [ ICONPATTERNSIZE*ICONMAX ]; /* 32768 */
char icon2buffer[ (ICONPATTERNSIZE/2)*ICONBOOTMAX ];
FILE *fp, *fpw, *fpw2;


void pack8dot( unsigned int bmpptr, unsigned int iconptr )
{
	int i;
	char c;
	
	c = 0;
	for( i=0 ; i<8 ; i++ )
	{
		c <<= 1;
		c |= buffer[bmpptr+i]==0 ? 1 : 0;
	}
	iconbuffer[iconptr] = c;
}


int do_convert()
{
	int readsiz, w,h, x,y,yy, pitch;
	unsigned int ptr;

	if( fread( buffer, 1, BMPHEADERSIZE, fp) != BMPHEADERSIZE )
	{
		puts( "ヘッダ読み込み失敗(1)\n" );
		return( 1 );
	}

	if( (buffer[0]!='B')||(buffer[1]!='M') )
	{
		puts( "BMPファイルではありません\n" );
		return( 1 );
	}

	/* BMPINFOHEADER */
	readsiz = *(int*)(buffer+10);
	readsiz -= BMPHEADERSIZE;
	if( fread( buffer, 1, readsiz, fp) != readsiz )
	{
		puts( "ヘッダ読み込み失敗(2)\n" );
		return( 1 );
	}

	if( buffer[14] != 8 )
	{
		puts( "256色BMP以外には対応していません\n" );
		return( 1 );
	}
	
	w = *(int*)(buffer+4);
	h = *(int*)(buffer+8);
	pitch = w;

	if( w < ICON_W*ICONMATRIX_W )
	{
		puts( "BMPの水平サイズが足りません\n" );
		return( 1 );
	}

	if( h < ICON_H*ICONMATRIX_H )
	{
		puts( "BMPの垂直サイズが足りません\n" );
		return( 1 );
	}

	if( pitch > sizeof(buffer) )
	{
		puts( "BMPの水平サイズが大きすぎます\n" );
		return( 1 );
	}

	/* 下から行きます */
	/* ブートアイコン */
	for( yy=ICON_H-1 ; yy>=0 ; yy-- )
	{
		if( fread( buffer, 1, pitch, fp) != pitch )
		{
			puts( "読み込み失敗\n" );
			return( 1 );
		}

		for( x=0 ; x<ICONBOOTMAX ; x++ )
		{
			ptr = ((ICONPATTERNSIZE/2)*x) + (yy*ICONPITCH);

			pack8dot( x*ICON_W   , ptr );
			pack8dot( x*ICON_W+8 , ptr+1 );
			pack8dot( x*ICON_W+16, ptr+2 );
			pack8dot( x*ICON_W+24, ptr+3 );
		}
	}
	memcpy( icon2buffer, iconbuffer, sizeof(icon2buffer) );

	/* システムアイコン */
	for( y=ICONMATRIX_H-2 ; y>=0 ; y-- )
	{
		for( yy=ICON_H-1 ; yy>=0 ; yy-- )
		{
			if( fread( buffer, 1, pitch, fp) != pitch )
			{
				puts( "読み込み失敗\n" );
				return( 1 );
			}

			for( x=0 ; x<ICONMATRIX_W ; x++ )
			{
				ptr = (ICONPATTERNSIZE*(x+(y*ICONMATRIX_W)))
					 + (yy*ICONPITCH);

				/* アイコン */
				pack8dot( x*ICON_W*2   , ptr );
				pack8dot( x*ICON_W*2+8 , ptr+1 );
				pack8dot( x*ICON_W*2+16, ptr+2 );
				pack8dot( x*ICON_W*2+24, ptr+3 );

				/* マスク */
				pack8dot( x*ICON_W*2+32, ptr+128 );
				pack8dot( x*ICON_W*2+40, ptr+129 );
				pack8dot( x*ICON_W*2+48, ptr+130 );
				pack8dot( x*ICON_W*2+56, ptr+131 );
			}
		}
	}

	return( 0 );
}	


int main( int argc, char *argv[] )
{
	if( argc < 2 )
	{
		puts( "BMPファイルを指定してください\n" );
		return( 0 );
	}
	
	strcpy( srcfile, argv[1] );

	if( (fp=fopen(srcfile,"rb")) == NULL )
	{
		puts( "読み込みファイルのオープンに失敗しました\n" );
		return( 0 );
	}

	if( do_convert() ) puts( "変換できませんでした\n" );
	else
	{
		/* システムアイコン書き込み */
		if( (fpw=fopen(dstfile,"wb")) != NULL )
		{
			if( fwrite( iconbuffer, 1, sizeof(iconbuffer), fpw) != sizeof(iconbuffer) )
			{
				puts( "書き込みに失敗しました(システムアイコン)\n" );
			}
			fclose( fpw );
		} else
		{
			puts( "書き込みファイルのオープンに失敗しました(システムアイコン)\n" );
		}

		/* ブートアイコン書き込み */
		if( (fpw2=fopen(dstfile2,"wb")) != NULL )
		{
			if( fwrite( icon2buffer, 1, sizeof(icon2buffer), fpw2) == sizeof(icon2buffer) )
			{
				puts( "正常終了\n" );
			} else
			{
				puts( "書き込みに失敗しました(ブートアイコン)\n" );
			}
			fclose( fpw2 );
		} else
		{
			puts( "書き込みファイルのオープンに失敗しました(ブートアイコン)\n" );
		}
	}
	fclose( fp );

	return( 0 );
}

