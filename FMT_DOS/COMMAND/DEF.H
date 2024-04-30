#ifndef DEF_H_IS_INCLUDED
#define DEF_H_IS_INCLUDED

#define ASCII_CR 0x0D
#define ASCII_LF 0x0A

#define LINEBUFLEN 256
#define MAX_PATH 128
#define MAX_ARG 64
#define MAX_EXEPARAM 128

#define DOS_STDIN  0
#define DOS_STDOUT 1
#define DOS_STDERR 2
#define DOS_STDAUX 3
#define DOS_STDPRN 4

#define DOS_OPEN_READ  0
#define DOS_OPEN_WRITE 1
#define DOS_OPEN_RW    2

#define DOS_LINEBREAK "\r\n"

#define DOS_SEEK_SET 0
#define DOS_SEEK_CUR 1
#define DOS_SEEK_END 2

enum
{
	COMTYPE_UNKNOWN,
	COMTYPE_BINARY,
	COMTYPE_BINARY32,
	COMTYPE_BATCH
};

#endif
