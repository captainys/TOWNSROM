#ifndef DOSCALL_H_IS_INCLUDED
#define DOSCALL_H_IS_INCLUDED



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



/*! 
*/



#endif
