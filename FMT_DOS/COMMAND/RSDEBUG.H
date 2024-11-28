#ifndef RS232C_PUTC

// FM-TOWNS Serial I/O
#define RS232C_PUTC(c) \
{ \
	int i; \
	for(i=0; i<1000 && 0==(_inp(0xA02)&3); ++i) \
	{ \
	} \
	_outp(&0xA00,c); \
}

#endif
