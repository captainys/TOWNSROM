#ifndef DOSLIB_H_IS_INCLUDED
#define DOSLIB_H_IS_INCLUDED

#include <dos.h>
#include <process.h>

#define DOSPARA 16

#define PSP_ENVSEG 0x2C
#define PSP_COMMANDLINE 0x80



#define FARPTR2SEG(ptr) FP_SEG(ptr)
#define FARPTR2OFS(ptr) FP_OFF(ptr);
#define MAKEFARPTR(SEG,OFS) MK_FP((SEG),(OFS))



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



/*! Initialize ENVSEG
*/
void InitENVSEG(unsigned int ENVSEG,unsigned int len,const char path[]);


#endif