#ifndef UTIL_H_IS_INCLUDED
#define UTIL_H_IS_INCLUDED

#include "DEF.H"


#define GetUint16(ptr) ((ptr)[0]|((ptr)[1]<<8))
#define SetUint16(ptr,data) {(ptr)[0]=((data)&255);(ptr)[1]=(((data)>>8)&255);}


#define OK 1
#define ERR 0



/*! Drop ' ', '\t', and control code at the tail of the string.
*/
void ClearTailSpace(char *str);


void Capitalize(char str[]);


int IsKanji(char c);


/*! Copy from src to dst up to dstLen-1.
    It will always terminate by 0, while strlen may make the string open.
    Returns actually copied length (excluding the last 0).
*/
unsigned int strncpy_close_nf(char *dst,char far *src,unsigned int dstLen);


/*!
*/
int CaseInsensitiveCompare(char a,char b);


/*! Replace String.
    maxStrLen should be the length of the string excluding \0.
    If the strLen is too short to replace, it will return 0.
    If successful, it returns the length of the new string.
*/
int ReplaceStringNF(char str[],unsigned int maxStrLen,const char from[],const char far to[]);
int ReplaceStringNN(char str[],unsigned int maxStrLen,const char from[],const char to[]);


/*! Substitute environment variables to %var%.
    Returns OK or ERR.
*/
int ExpandEnvVar(unsigned int ENVSEG,char lineBuf[],unsigned int lineBufLen);

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
	if exe!=NULL, argv[0] will point exe, and argv[1..] will be taken from cmdLine.
*/
int ParseString(int *argc,char *argv[],char exe[],char cmdLine[]);

/*! Returns a pointer to '.' in the file name.
    Or can point 0.
*/
const char *GetExtension(const char *fName);

/*! Replaces the extension of the file.
    ext can be like ".EXT" or "EXT".
    If fName length exceeds MAX_PATH, this function won't do anything.
*/
void ReplaceExtension(char fName[],const char ext[]);


/*! Returns OK or ERR.
*/
int ExpandBatchArg(char lineBuf[],int batArgc,char *batArgv[],unsigned int lineBufLen);


#endif
