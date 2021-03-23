#ifndef DOSCALL_H_IS_INCLUDED
#define DOSCALL_H_IS_INCLUDED



#include "DEF.H"



/*! Returns the PSP segment.
*/
unsigned int DOSGETPSP(void);



/*! Returns the segment.
*/
unsigned int DOSMALLOC(unsigned int pages);



/*! Frees the segment returne by DOSMALLOC.
    Does nothing if SEG==0.
*/
void DOSFREE(unsigned int SEG);



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



#endif
