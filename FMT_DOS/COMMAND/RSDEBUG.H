#ifndef RS232C_PUTC

#include <conio.h>
// FM-TOWNS Serial I/O
#define RS232C_PUTC(c) \
{ \
	int i; \
	for(i=0; i<1000 && 0==(inp(0xA02)&3); ++i) \
	{ \
	} \
	outp(0xA00,c); \
}

#define RS232C_PUTS(s) \
{ \
	int i; \
	for(i=0; 0!=(s)[i]; ++i) \
	{ \
		RS232C_PUTC((s)[i]); \
	} \
}

#endif
