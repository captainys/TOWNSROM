#ifndef UTIL_H_IS_INCLUDED
#define UTIL_H_IS_INCLUDED



#define GetUint16(ptr) ((ptr)[0]|((ptr)[1]<<8))
#define SetUint16(ptr,data) {(ptr)[0]=((data)&255);(ptr)[1]=(((data)>>8)&255);}



/*! Drop ' ', '\t', and control code at the tail of the string.
*/
void ClearTailSpace(char *str);


void Capitalize(char str[]);


int IsKanji(char c);

/*! Substitute environment variables to %var%.
*/
int ExpandEnvVar(char lineBuf[],unsigned int lineBufLen);

/*! Extract the first argument of the command line.
    Returns the first divider.
    I need this non-destructive function separate from ParseString because
    if the command I may need un-altered command line if the command is an
    executable binary.
	In DOS 3.1, the first argument is not supposed to be aware of double-quote,
	so I don't take double-quote into account.
	argv0 must be minimum MAX_PATH.
*/
int GetFirstArgument(char argv0[],const char cmdLine[]);

/*! Returns a pointer to the rest of the command line after the first argument.
    Can be "".
*/
char *GetAfterFirstArgument(char cmdLine[],int argv0Len);

/*! Divide a string into arguments by ' ' and '\t'.
    Up to MAX_ARG.
    Returns number of arguments.
    Separators will be replaced with 0.
    Aware of double-quote.
*/
int ParseString(int *argc,char *argv[],char cmdLine[]);

/*! Returns FOUND if found.
    Returns NOTFOUND if not found.
	fName must be long enoubh to hold MAX_PATH.
*/
int FindExecutableFromPath(char fName[],const char srcFName[]);

#endif
