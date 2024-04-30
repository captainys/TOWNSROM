#ifndef DOSCALL_H_IS_INCLUDED
#define DOSCALL_H_IS_INCLUDED



#include "DEF.H"



/*! Returns the PSP segment.
*/
unsigned int DOSGETPSP(void);



/*! Make a true full-path name.
    0:No Error
    1:Error
*/
int DOSTRUENAME(char fullpath[],const char src[]);



/*! Execute a binary.
*/
int DOSEXEC(unsigned int PSP,unsigned int ENVSEG,const char exeFullPath[],const char commandArg[]);



/*! Returns ERRORLEVEL
*/
int DOSGETERRORLEVEL(void);



/*! Change directory, but do not change current drive.
    chdir of DIRECT.H may end up changing the drive.
*/
int DOSCHDIR(const char dir[]);



/*! Use INT 21H AH=0AH to get one line of input.
    buf must be minimum LINEBUFLEN.
*/
int DOSGETS(char buf[LINEBUFLEN]);


/*! PUTS and PUTC using AH=02H
*/
void DOSPUTS(const char str[]);
void DOSPUTC(char c);


void DOSWRITES(int fd,const char str[]);

/*! Returns a file handle if success, or -1 if fail. */
int DOSREADOPEN(const char fileName[]);
/*! Returns a file handle if success, or -1 if fail. */
int DOSWRITEOPEN(const char fileName[]);


unsigned long int DOSSEEK(int fd,unsigned long int fpos,unsigned char from);


void DOSGETCWD(char cwd[MAX_DIR]);


/*!
dup2 in Open WATCOM 1.9 C Runtime Library links malloc and free, which are unnecessary. to increase binary size by 2KB.
*/
int DOSDUP2(int fdFrom,int fdTo);

#endif
