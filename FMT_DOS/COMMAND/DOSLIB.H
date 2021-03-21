#ifndef DOSLIB_H_IS_INCLUDED
#define DOSLIB_H_IS_INCLUDED

#include <dos.h>
#include <process.h>

#define DOSPARA 16

#define PSP_ENVSEG 0x2C
#define PSP_COMMANDLINE 0x80

#define MCB_CHAIN_ID	0
#define MCB_PID			1
#define MCB_BLOCK_SIZE	3

#define FOUND 1
#define NOTFOUND 0



#define FARPTR2SEG(ptr) FP_SEG(ptr)
#define FARPTR2OFS(ptr) FP_OFF(ptr);
#define MAKEFARPTR(SEG,OFS) MK_FP((SEG),(OFS))


#define DOSERR_NO_ERROR					0x00
#define DOSERR_INVALID_FUNC				0x01
#define DOSERR_FILE_NOT_FOUND			0x02
#define DOSERR_DIR_NOT_FOUND			0x03
#define DOSERR_TOO_MANY_OPEN_FILES		0x04
#define DOSERR_ACCESS_DENIED			0x05
#define DOSERR_INVALID_HANDLE			0x06
#define DOSERR_MCB_BROKEN				0x07
#define DOSERR_OUT_OF_MEMORY			0x08
#define DOSERR_INVALID_MCB				0x09
#define DOSERR_BAD_ENV					0x0A
#define DOSERR_BAD_FORMAT				0x0B
#define DOSERR_INVALID_ACCESS			0x0C
#define DOSERR_INVALID_DATA				0x0D
#define DOSERR_UNUSED					0x0E
#define DOSERR_INVALID_DRIVE			0x0F
#define DOSERR_CANNOT_DEL_CUR_DIR		0x10
#define DOSERR_NOT_SAME_DRIVE			0x11	; ?
#define DOSERR_NO_MORE_FILES			0x12
#define DOSERR_WRITE_PROTEDTED			0x13
#define DOSERR_UNKNOWN_UNIT				0x14
#define DOSERR_DRIVE_NOT_READY			0x15
#define DOSERR_UNKNOWN_COMMAND			0x16
#define DOSERR_CRC_ERROR				0x17
#define DOSERR_BAD_REQ_LEN				0x18
#define DOSERR_SEEK_ERROR				0x19
#define DOSERR_UNKNOWN_MEDIUM			0x1A
#define DOSERR_SECTOR_NOT_FOUND			0x1B
#define DOSERR_OUT_OT_PAPER				0x1C
#define DOSERR_WRITE_FAULT				0x1D
#define DOSERR_READ_FAULT				0x1E
#define DOSERR_GENERAL_FAULT			0x1F
#define DOSERR_INVALID_DISK_CHANGE		0x22


/*! Initialize ENVSEG
*/
void InitENVSEG(unsigned int ENVSEG,unsigned int len,const char path[]);



/*!
*/
void SetEnv(unsigned int ENVSEG,const char var[],const char data[]);



/*!
*/
const char *GetEnv(unsigned int ENVSEG,const char var[]);



/*!
*/
long int GetArenaBytes(unsigned int SEG);



#endif