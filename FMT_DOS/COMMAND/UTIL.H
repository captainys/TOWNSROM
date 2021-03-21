#ifndef UTIL_H_IS_INCLUDED
#define UTIL_H_IS_INCLUDED



#define GetUint16(ptr) ((ptr)[0]|((ptr)[1]<<8))
#define SetUint16(ptr,data) {(ptr)[0]=((data)&255);(ptr)[1]=(((data)>>8)&255);}



void ClearTailSpace(char *str);
int IsKanji(char c);



#endif
