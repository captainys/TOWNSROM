#ifndef DOSCALL_H_IS_INCLUDED
#define DOSCALL_H_IS_INCLUDED


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



#endif
