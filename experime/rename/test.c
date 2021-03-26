#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <direct.h>
#include <dos.h>



/*
Question:
INT 21H AH=56H RENAME is capable of moving a file within the same drive.

If, DS:DX and ES:DI both are full-path name, no brainer.

If, ES:DI has slash or backslash, probably makes sense to take it a relative path to the cwd.

If, ES:DI does not include a path name, slash or backslash, and the DS:DX is not cwd, should I:
  (1) rename the file name without moving the file, or
  (2) move the file to the cwd?

Ther answer is (2).  Confirmed the behavior with this program in Towns OS V2.1 L20 and DOSBox.
*/
int main(void)
{
	const char *from=".\\xyz\\abc\\test";
	const char *to="moved";

	union REGS regIn,regOut;
	struct SREGS sregs;

	mkdir("xyz");
	mkdir("xyz\\abc");
	remove("moved");
	remove("xyz\\abc\test");
	remove("xyz\\abc\moved");
	{
		FILE *fp=fopen("xyz\\abc\\test","w");
		fprintf(fp,"Test\n");
		fclose(fp);
	}

	segread(&sregs);

	sregs.es=sregs.ds;
	regIn.x.ax=0x5600;
	regIn.x.dx=(unsigned int)from;
	regIn.x.di=(unsigned int)to;
	intdosx(&regIn,&regOut,&sregs);

	return 0;
}
