#ifndef UTIL_H_IS_INCLUDED
#define UTIL_H_IS_INCLUDED



#define GetUint16(ptr) ((ptr)[0]|((ptr)[1]<<8))
#define SetUint16(ptr,data) {(ptr)[0]=((data)&255);(ptr)[1]=(((data)>>8)&255);}

#define FOUND 1
#define NOTFOUND 0



/*! Drop ' ', '\t', and control code at the tail of the string.
*/
void ClearTailSpace(char *str);


int IsKanji(char c);

/*! Substitute environment variables to %var%.
*/
int ExpandEnvVar(char lineBuf[],unsigned int lineBufLen);

/*! Divide a string into arguments by ' ' and '\t'.
    Up to MAX_ARG.
    Returns number of arguments.
    Separators will be replaced with 0.
*/
int ParseString(int *argc,char *argv[],char cmdLine[]);

/*! Returns FOUND if found.
    Returns NOTFOUND if not found.
	fName must be long enoubh to hold MAX_PATH.
*/
int FindExecutableFromPath(char fName[],const char srcFName[]);

#endif
