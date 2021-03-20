;
; Freed Up
;   MAKE_FULLPATH from CS:6208h
;   SETDPB        from CS:18B6h to CS:191Eh
;
;

						ORG		0014H
OEM_INT_21H_HANDLER		DD		0FFFFFFFFh

						ORG		001AH
PROB_RETRY_COUNT		DW		0		; Used in 1679:00006A09 8B1E1A00   MOV     BX,[001AH]
						ORG		001CH
PROB_BUSY_LOOP_COUNT	DW		0		; Used in 1679:00001A8C 368B0E1C00 MOV     CX,SS:[001CH]

						ORG		001EH
LASTBUFFER				DD		0

						ORG		0024H
FIRST_MCB				DW		0		; In segment scale

; SYSVARS aka List of Lists
; https://sites.google.com/site/pcdosretro/sysvars
; NUM_DPB needs to be FIRST_DPB_PTR+20h.
; IO.SYS is assuming NUM_DPB is ES:[DI+20h] on return from initialization.
; NUM_DPB apparently mean the number of drive letters (need to confirm).
						ORG		0026H
SYSVARS:
						; 0026H  SYSVARS+00h
FIRST_DPB_PTR			DW		0				; Labeled as DPBHEAD in MS-DOS V2.0 source
FIRST_DPB_SEG			DW		0
						; 002AH  SYSVARS+04h
FIRST_SFT_PTR			DD		OFFSET SFTABLE	; --NOT_IN_NASM--
;FIRST_SFT_PTR			DD		SFTABLE			; --USE_IN_NASM--
FIRST_SFT_SEG			EQU		FIRST_SFT_PTR+2
						; 002EH  SYSVARS+08h
BCLOCK					DD		0
BCLOCK_SEG				EQU		BCLOCK+2
						; 0032H  SYSVARS+0ch
BCON					DD		0
BCON_SEG				EQU		BCON+2
						; 0036H  SYSVARS+010h
MINIMUM_SECTOR_LENGTH	EQU		0800h
MAXSEC					DW		MINIMUM_SECTOR_LENGTH
						; 0038H  SYSVARS+12h
IO_BUFF_PTR				DD		0
IO_BUFF_SEG				EQU		IO_BUFF_PTR+2
						; 003Ch  SYSVARS+16h
FIRST_CDS_PTR			DD		0				; Pointer to Current Directory Structure
FIRST_CDS_SEG			EQU		FIRST_CDS_PTR+2
						; 0040h  SYSVARS+1Ah
FCB_SFT_PTR				DW		0
FCB_SFT_SEG				DW		0
FCB_KEEP_COUNT			DW		0
						; 0046H  SYSVARS+20h
NUM_DPB					DB		0				; Labeled as NUMIO in MS-DOS V2.0 source
NUM_CDS					DB		0				; Number of current directory structures. Returned by INT 21H AH=0EH
						; 0048H  SYSVARS+22h
DEVHEAD					DW		0,0				; Also SYSDEV for NUL Device
						; SYSVARS+26h
						DW		SYSDEV_DEVFLAG_NUL+SYSDEV_DEVFLAG_IS_CHARDEV	; SYSDEV_DEVFLAGS
						DW		NUL_STRATEGY									; SYSDEV_STRATEGY
						DW		NUL_INTERRUPT									; SYSDEV_INTERRUPT
						DB	"NUL     "
						; 005Ah  SYSVARS+34h
NUM_JOINED_DRV			DB		0


						DB		077h    ; Is offset 005Bh used?


						ORG		005CH
UNKNOWN_JUMP_TABLE		DW		0
						; Default behavior is CLC, RETF
						; 02h  Used during FCLOSE 1679:00006A76 CALLF   WORD PTR [0064H]
						; 08h  Used during FREAD  1679:00006A0E CALLF   WORD PTR [007CH] with BX=[001AH]
						; 0Eh  Used during FCLOSE 1679:00003606 CALLF   WORD PTR [0094H]
						; DWORD times 15

						ORG		0098H
; System File Table:  First entry is always a console device.
SFTABLE					DD		-1
						DW		SF_DEFAULT_NUMBER
; One strange thing is why the original MSDOS.SYS does not write initial value in here.
; The original MSDOS.SYS seems to be cutting down the size to the last byte.  However,
; DOSINIT is using 27 (1Bh) bytes to write constant values to this area.
SFT_CONSDEV_REFCOUNT	DW		0003H       ; +00h  03 00 Refcount
						DW		0002H       ; +02h  02 00 Access Mode RD/WR
						DB		0           ; +04h  00    Attribute Byte
						; FCB
						DW		0C3H        ; +05h  C3 00   IS_CHAR|NO_EOF|CONS_OUT|CONS_IN
SFT_CONSDEV_SI	DW		0           ; +07h  DA 08
SFT_CONSDEV_DS	DW		0           ; +09h  48 10
						DB		6 DUP(0)    ; +0Bh  00 00 00 00 00 00  First Cluster,Time,Date
						DB		4 DUP(0FFH) ; +11h  FF FF FF FF  File Size
						DB		4 DUP(0)    ; +15h  00 00 00 00  File Pointer
						DB		7 DUP(077h)    ; +19h  00 00 00 00 00 00 00  Rel Cluster Num,Abs Cluster Num,DirEntSect,PosInSect
SFT_CONSDEV_FILE_NAME	DB		20h,20h,20h,20h,20h,20h,20h,20h ; +20h
SFT_CONSDEV_FILE_EXT	DB		20h,20h,20h                     ; +28h
						DD		077h			; +2Bh
						DW		07777h			; +31h
						DW		07777h			; +33h


						ORG		00D3H ; NUL device comes immediately after CON
PROB_SF_ENTRY_NUL_DEVICE	DB	0


			            DB      ((SF_DEFAULT_NUMBER-2)*(SF_ENTRY_size)) DUP (0)


						ORG		01A7H
CARPOS					DB		0			; Used from CONOUT

						ORG		02ACH
PROB_COUT_SIMUL_PRN		DB		0			; Non-Zero->Simultaneous printer output.

						ORG		02ADH
PROB_VERIFY_WRITE_FLAG	DB		0			; In 1679:0000478F, 

						ORG		02AEH
CONOUT_CTRLC_CHECK_CTR	DB		0			; In the original MSDOS.SYS,
											; INT 21H AH=02H increments it and checks Ctrl+C and Print Spoolerevery 4 counts.

						ORG		02AFh
AVAILDEV				DB		02Fh		; Usage of /DEV/ prefix for CHARDEV.

						ORG		02B0h
MALLOC_STRATEGY			DB		0			; Set/Get in INT 21H AH=58H CS:5E23h

						ORG		02B1H
USE_OPPENCLOSE_BLOCKDEV		DB		0
; Used in 46BEH and 3121H
; Prob: If zero, 46BEH proc won't issue DEVREQ Close.

						ORG		02CEH
ERRORMODE				DB		0			; SHSUCDX denotes it as DTApp

; Memo to myself:
; A very good question is if INT 21H is made safe for Ctrl+C during the re-entrance.
; It is possible that INT 21H routine calls a device driver, which then uses INT 21H
; from within.
; The original MSDOS.SYS overwrites USER_SS and USER_SP at the beginning of
; INT 21H handler.
; But, it considers Ctrl+C only if the re-entrance count (INDOS) is 1, which means
; it is the first-level call.  So, I guess it's safe after all then.
						ORG		02CFH
INDOS					DB		0			; Flag to detect re-entrance in INT 21H (maybe 20H to 24H)
											; The original MSDOS.SYS checks Ctrl+C during some operations
											; only if [INDOS]==1.
											; I get it!  To process Ctrl+C, it needs to know the state of
											; the registers at the time of INT 21H.
											; INDOS means user_SS,user_SP are valid, and the previous
											; state of the registers can be recovered from there.

						ORG		02D0H
UNKNOWN_FLAG_USED_IN_BUFWRITE	DB	077h
; BUFWRITE will refuse to write if it is zero.
; 0FFh is written in INT 21H AH=4Ch,31h,00h
; Proc 00005708 compares this byte against IO_BUF_DRIVE.

						ORG		02D1h
ERROR_LOCUS				DB		0			; Referred by INT 21H AH=59H (CS:17D7)

						ORG		02D2h
EXTENDED_ERROR_CODE		DW		0
; Returned in AX in INT 59H.  
; Used in Critical Error Handler 1679:507Dh
;   00ffh Console Error (from 1679:0000502A)
;   0fffh Invalid Cluster or Broken FAT (from 1679:00005263)

						ORG		02D4h
ERROR_RECOMMENDED_ACTION	DB		0
ERROR_CLASS					DB		0

						ORG		02D6h
MEDIA_ID_STRUCT_ON_ERROR:	DD		0		; Referred by INT 21H AH=59H (CS:17D7)  Used only if media-change error.

						ORG		02DAH
DMA_BUFFER_INITIAL_OFFSET	EQU		0080H
DMA_BUFFER_PTR			DW		DMA_BUFFER_INITIAL_OFFSET
DMA_BUFFER_SEG			DW		0
; According to http://www.ctyme.com/intr/rb-4312.htm and SHSUCDX.NSM,
; this is DTA field of SDA.
; How MSCDEX communicates?  How does it identify it is the address?

						ORG		02DEH
CurrentPDB				DW		0

						ORG		02E2h
ERRORLEVEL				DW		0

						ORG		02E4h
CURRENT_DRIVE			DB		0			; Confirmed. Set in INT 21H AH=0EH (Set Current Drive)

						ORG		02E8h
UnknownPDB				DW		0			; FOPEN compares this value against SF_PSP_OWNER.

						ORG		02EAH
MACHINE_NUMBER			DW		0			; FOPEN/FCLOSE function checks [SF_ENTRY+02fH] against this.

						ORG		02ECH
FirstArena				DW		0
BestArena				DW		0
LastArena				DW		0

						ORG		02F2H
ENDMEM					DW		0			; DX value at initial call from IO.SYS

						ORG		02F4h
NTH_FILE_IN_DIRECTORY	DW		0
; Used in Proc 1679:4148.

						ORG		02F6H
PROB_ERROR_FROM_DEVCALL	DB		0			; At the end of FCLOSE, it is used as an error return from DEVCALL Write Sector.

						ORG		02F7h
FLAGS_FATAL_ERROR_HANDLING		DB		0	; Controlls behavior of Fatal Error Handling (1679:0000507D,1679:00005091)
; 18H at 1679:3B3B  FATSECRD (Read FAT Sector)
; 08H at 1679:525A  GETNEXTCLUSTER
; If Bit3 (08H) is clear, INT 24H will kill the process.

						ORG		02F9h
UNKNOWN_FLAG_02F9h		DB		0ffh		; INT 21H AH=4Ch will set return type as CtrlC if this byte is zero.


						ORG		02FCH
DATE					DB		0
MONTH					DB		0
YEAR					DW		0	; Year since 1980.

						ORG		0300h
PROB_DAYS_SINCEX		DW		0			; Most likely days since certain time point.  Max 43830=365*120
PROB_DAY_OF_WEEK		DB		0			; Most likely day of week.

						ORG		0303h
CONSWAP					DB		0			; Used in INT 21H handler.  Is it for redirection?
IDLEINT					DB		0			; Used in INT 21H handler.  Prob 0->Disable INT 28H
UNKNOWN_FLAG_0305h		DB		0			; INT 21H AH=4Ch Writes 0FFh then Clears before IRET Back to CALLER Process

						ORG		0306H		; 309H is REQ_STATUS
DEVCALL:				DW		0

						ORG		0313H
CALLUNIT				DB		0			; Initial 0
						; 0314h used in FCLOSE as scratch buffer for making BPB.
DEVCALL_BUFFER_PTR		DD		0			; Wait, it is part of DEVREQ from 0306h...
DEVCALL_BUFFER_SEG		EQU		DEVCALL_BUFFER_PTR+2

						ORG		0318H
CALLBPB					DW		0,0			; Initial 0

						ORG		0320H
CALL_POINTER			DW		0,0

						ORG		0324H
CONSDEV_REQHDR2			DB		16h dup (0)			; Used from routine 1679:459B

						ORG		033AH
CONSDEV_REQHDR			DB		0			; +00h Used in Non-Destructive-Read and Read from CONSDEV
						DB		0			; +01h
						DB		0			; +02h Read(4),Non-Destructive Read (5)
						DW		0			; +03h
						DB		8 dup(0)	; +05h
DSKCHRET				DB		0			; +0dh Character Return in Non-Destructive-Read and Read.  DSKCHRET in MS-DOS V2.0 source
						; 0348H
						DD		0			; +0eh Pointer to the Data Buffer
						; 034CH used from Ctrl+C handler
						DW		0			; +12h Sector count In -> Num sectors transferred Out
						DW		0			; +14h Starting Sector




						ORG		0350H
CREATE_PDB_FLAG			DB		0

						ORG		0352H
; See http://www.ctyme.com/intr/rb-2711.htm
DOS_SERIAL_LOW			DW		0
DOS_SERIAL_HIGH			DB		0


						; Looks like this INITBLOCK (256 bytes + 10h for round up) is PSP aka PDB aka Program Header for MSDOS.SYS
						ORG		0358H
INITBLOCK:

						ORG		035EH
ONE_BYTE_OUT_BUFFER:	; Used by one-byte out 1679:459B

						ORG		0360H
FILENAME_BUFFER			DB		128 dup(0)
; Looks like used as a file-name buffer.  It overwrites PSP made in INITBLOCK during DOSINIT.
; SHSUCDX is taking this as FN1p.
						; Confirmed.  FOPEN uses it as a qualified file-name buffer.
						; 1679:000067CA BF6003                    MOV     DI,0360H

						ORG		03E6h
PROB_FILE_NAME_BUFFER2:
						; While making a full path (fully-qualified) file name,
						; this address is pointed by
						; 1679:00006309 8DAD8600                  LEA     BP,[DI+0086H]

						ORG		0460h
SDB						DB		0
; SHSUCDX labels it as SDBp.  Previous 256 bytes are for file-name buffer, then is it a data buffer?
; SHSUCDX disregards DMA_BUFFER_PTR on AX=111Bh.
; It always writes FIND_STRUCT to SDB.
; Confirmed:
;	; Fill in the SDB
;	les	di, [BP_(SDBp)]
; SHSUDEX does disregard DMA_BUFFER_PTR (DTApp in SHSUCDX source).


						ORG		0468H
INITSP					DW		0		; Used for storing incoming SS:SP during initialization
INITSS					DW		0

						ORG		046CH
ORIGINAL_MOVDPB:

						ORG		0495H
TEMPORARY_CDS			DB		CURRENT_DIR_STRUCT_size DUP (0)	; Used from 1679:00006130

						ORG		04E6H
TEMPORARY_DIRENT:		; Looks like it is used as a temporary directory entry.
PROB_FNAME_11BYTE		DB		0bH dup(' ') ; Probably 11-byte ' ' padded file name and extension
; A device driver may start with '05h' in which case, changed to 'E5h' before strcmp in 1679:00004414.
						; 04EEH Extnensions
						; 04F1H Attribute
						; 04FCH TIME
						; 04FEH DATE
						; 0500h Starting cluster
						; 0502h DD File Size

						ORG		0506H
PROB_SAVE_SF_ATTR		DB		0

						ORG		0508H
SATTR					DB		0
; SHSUCDX labels 0508h (2CEh+23Ah) as SAttrp.
; FOPEN (INT 21H AH=3DH) Set this value to CL if BYTE PTR CS:[050Dh] (NO_SET_DIR) is 0FFh.
; Will be transferred to 0506h (SF_ATTR) if the file name starts with '/dev/' at 1679:00004585.

						ORG		0509h
PROB_SAVE_OPEN_MODE:
; Storing open mode during fopen at 1679:000032A4 A20905 MOV [0509H],AL

						ORG		050DH
NO_SET_DIR				DB		0FFh	; According to MSCODE.ASM, 'set directories on search'
										; Used in 1679:00001A83.  Purpose unknown.
; This byte probably is set to 00h once global current-directory structure is ready to go.
; 1679:00006117 creates and uses a temporary CDS (51h bytes from CS:0495h) if
; this byte is 0FFh.

						ORG		050EH
SECTORS_INTO_CLUSTER	DB		0		; Used in a fread subroutine (1679:00003C49)
										; Also used in directory-entry read (1679:00003AD5)

						ORG		0511H
PROB_SAVE_SF_DRIVE		DB		0


						ORG		0512h
PROB_NUM_DIR_SECTORS:	
; Set in Proc 1679:42A1
; as DPB_FIRST_DATA_SECTOR-DPB_FIRST_DIR_SECTOR
; Set in Proc 1679:4397
; as a sectors per cluster.

						ORG		0515h
UNKNOWN_FLAG_0515h		DB		0ffh	; Unknown flag.  If it is not 0ffh, INT 21H returns error.

						ORG		0517h
TERMINATION_TYPE		DB		00h		; 00h is set in INT 21H AH=00h or AH=4Ch, 03h in INT 21H AH=31h
										; Returned as high-byte of AX (Return Type) by INT 21H AH=4Dh

						ORG		0519h
SPECIAL_FILE_NAME_HEAD	DB		0E5h
; Looks like a file name starting with 0E5h has a special meaning.

						ORG		051AH
SAVE_DPB_IN_ERROR_HANDLING	DD	0
						; Used in error handling 1679:5081
						; Also used as a return address (CS:IP) for exitting from process at CS:51E3 and CS:5201

						ORG		051EH
USER_SP					DW		0		; Used for saving SP and SS while handling interrupts.
USER_SS					DW		0
						; 051Eh is also used for saving and restoring AX during process termination in AH=31h, 4Ch, and 00h.
						; Probably, due to that, these three functions are not usable from inside DOS.

						ORG		0522H
PROB_SAVE_SP_DURING_CRITICAL_ERROR_HANDLING		DW		0	; Saved at CS:000050C7, Restored at CS:5107 in INT 24H Handler.

						ORG		0524H
DPB_OR_SYSDEV			DD		0		; Used in a fread subroutine (1679:3BF2) also fopen subroutine (1679:000043F3)
DPB_OR_SYSDEV_OFSSET	EQU		DPB_OR_SYSDEV
DPB_OR_SYSDEV_SEG		EQU		DPB_OR_SYSDEV+2

						ORG		052CH
PREREAD					DW		0		; MSDATA.ASM tells 0->Preread  1->Preread is optional

						ORG		0530h
MEDIA_DESC_BYTE			DB		0		; Used for returning media-desc byte in AH=1Ch

						ORG		0532H
DEVICE_DRIVER_PTR		DD		0		; Written 1679:0000445F,

						ORG		0536H
CUR_SF_ENTRY			DD		0		; Used for temporarily storing SF_TABLE pointer
CUR_SF_ENTRY_SEG		EQU		CUR_SF_ENTRY+2

						ORG		053AH
CURRENT_CDS_STRUCT		DD		0						; CDS Used from proc 1679:00006058
CURRENT_CDS_STRUCT_SEG	EQU		CURRENT_CDS_STRUCT+2	; Accessing [DI+043H]
; This may be used from MSCDEX.  http://www.ctyme.com/intr/rb-4328.htm says SDA CDS pointer should point to the CDS of the drive.

						ORG		0542H
PROB_ERRCODE_IN_CASE_CRITICAL_ERROR	DW	0	; Used in FOPEN.  Maybe SFN.
						ORG		0546H
PROB_LOCATION_STORE_CRITICAL_ERRCODE	DD	0
; In some situation (1679:00005147), critical error happened while handling previous,
; Low byte of CS:[0542H] is copied to the far address stored in CS:[0546H]
; If CS:[0542h] is 0ffffh, the value won't be copied. 
; If it is the first-level critical, error, 0ffh is written to the far poitner 
; pointed by CS:[0546h], if CS:[0542h] is not 0ffh. (1679:000050CE)

						ORG		054AH
FILENAME_BUFFER_PTR1:
; Used in 1679:000041C9 as a pointer to directory name.
						ORG		054Eh
FILENAME_BUFFER_PTR2:
; Stored at 1679:0000638B
; Most likely, if it is not 0ffffh, Proc 1679:41C9 looks to interpret it as a relative path.
; Both FILENAME_BUFFER_PTR1 and FILENAME_BUFFER_PTR2 are used as an offset for
; filname buffer.  In Proc 41C9h, DS:SI (Fully-Qualified Path) is taken from
; [054Eh] if it is not 0ffffh, or from [054Ah] otherwise.

						ORG		0550H
DMABUFF_OFFSET_LOW4BITS	DB		0		; Used in fread

						ORG		0554H
CLUSTERS_INTO_FILE		DW		0		; Used in a fread subroutine (1679:3C54)
; In Proc 417B,
;   Used as an absolute cluster.

						ORG		0556h
DIR_SECTOR				DW		0		; Set at 1679:000041C3 in Proc 1679:41AA
; Also set in Proc 1679:417B

						ORG		0558h
USED_IN_DIRENT_SEARCH:					; Prob 0 means root directory.
										; Looks like it is a cluster.

						ORG		055AH
ORIGINAL_SECTORS_INTO_FILE		DW		0
						DW		0
ORIGINAL_BYTES_INTO_SECTOR		DW		0	; 055Eh

						ORG		0560H
TEMPORARY_FILE_LOCATION	DD		0		; Used in Fread Subroutine.

						ORG		0564H
BYTES_TO_READ_FROM_THIS_SECTOR	DW		0	; Used in fread subroutine. (Maybe also used from fwrite?)
BYTES_TO_READ_FROM_LAST_SECTOR	DW		0	; Used in fread subroutine. (Maybe also used from fwrite?)
NUM_SECTORS_WHOLE_READ	DW		0		; Used in fread subtoutine.

						ORG		056Ah
PROB_OUTPUT_FILE_NUM_IN_SECTOR:

						ORG		056Ch
PROB_MAX_NUM_FILES_IN_DIR:				; Used in Proc 1679:000040FA

						ORG		056EH
COPY_CLUSTERS_INTO_FILE:				; Used in 1679:3AD5

						ORG		0574H
CURBUF					DD		0		; Current Sector Buffer

						ORG		0578H
PROB_COUT_SF_ENTRY_PTR	DD		0		; Most likely SF_ENTRY for redirected console output.
PROB_COUT_SF_ENTRY_SEG	EQU		PROB_COUT_SF_ENTRY_PTR+2

						ORG		057CH
SAVE_BX					DW		0		; Used at least in the original INT 21H handler.
SAVE_DS					DW		0

						ORG		0580H
TEMPORARY_IP			DW		0			; Used for temporarily storing return IP

						ORG		0584H
NSP						DW		0		; Used in the original INT 21H handler.  Usage unknown.
NSS						DW		0

						ORG		0706H
AUXSTACK:				; Stack extends backward

						ORG		0C78H
						; Should pretend Version 3.30 or newer to use SHSUCDX
DOS_MAJOR_VERSION		DB		3
DOS_MINOR_VERSION		DB		31

						ORG		0D8Dh
UNKNOWN_TABLE_0D8Dh		DD		0		; Used 13FCh proc called from 507D proc
						ORG		0DDDh
UNKNOWN_TABLE_0DDDh		DB		13h,14h,15h,16h,17h,18h,19h,1Ah,1Bh,1Ch,1Dh,1Eh,1Fh,1Fh,22h	; 16-byte table used in 507D proc

						ORG		0DEEh
NUM_INT_21H_FUNCTIONS	DB		077h
INT_21H_FUNC_JUMP_TABLE	DW		07777h

						ORG		0EB7h
UNKNOWN_VAR_IN_INT24H_HANDLER_USES:		; INT 24H Handler pushes these valures in stack at CS:1495

						ORG		1111h
EXE_INITIAL_SP			DD		0
EXE_INITIAL_SS			EQU		EXE_INITIAL_SP+2
						ORG		1115h
EXE_INITIAL_IP			DD		0
EXE_INITIAL_CS			EQU		EXE_INITIAL_IP+2
						ORG		1119h
EXE_HEADER_BUFFER		DB		01Ah dup(0)

						ORG		1181h
INT_20H_ABORT:			JMP		INT_20H_ABORT

						ORG		01187H
ORIGINAL_JUST_IRET:		IRET

						ORG		11a2h
ORIGINAL_INT_21H_COMMAND:	JMP		ORIGINAL_INT_21H_COMMAND

						ORG		12D8h
GET_USER_SSSP_IN_DSSI:	JMP		GET_USER_SSSP_IN_DSSI

						ORG		133eh
INT_25H_BIOS_DISKREAD:	JMP		INT_25H_BIOS_DISKREAD

						ORG		136DH
INT_26H_BIOS_DISKWRITE:	JMP		INT_26H_BIOS_DISKWRITE

						ORG 	147AH
ORIGINAL_INT_2FH_HANDLER:		JMP		ORIGINAL_INT_2FH_HANDLER
; R:\RUN386.EXE will cause drive-not-ready, and invokes INT 2FH AX=1206h.
; Probably that's the only possibility when this function is called.
; Easiest implementation can be just return AL=3 (Fail).

						ORG		155CH
ORIGINAL_READ_CLOCK:	JMP		ORIGINAL_READ_CLOCK
; Read CLock. 
; AX - YYYYYYYMMMMDDDDD, 
; DX - HHHHHMMMMMMSSSSS (SSSSS=seconds/2)()}

						ORG		018B6H
ORIGINAL_SETDPB:		JMP		ORIGINAL_SETDPB

; In FM TOWNS MSDOS.SYS, CREATE_PDB will fall down to SETMEM.
						ORG		0191FH
ORIGINAL_CREATE_PDB:
ORIGINAL_INT_21H_55H_CREATE_CHILD_PSP:
						MOV		AH,055H
						CALL	COMPAT_INT21
						MOV		DS,DX
						MOV		ES,DX
						RET
						NOP


						ORG		0199CH
ORIGINAL_SETMEM:		JMP		ORIGINAL_SETMEM

						ORG		01F69H
ORIGINAL_OUTMES:		JMP		ORIGINAL_OUTMES


						ORG		03121h
; Used from CREATE_PDB.
; It takes a SF_TABLE pointer as input.
; If:
;     BYTE PTR CS:[02B1H] is non zero, and
;     0!=SF_DEVFLAG_REDIRECTED & [SF_DEVFLAGS], and
;     0!=SYSDEV_DEVFLAGS_OPEN_CLOSE_SUPPORTED & [SYSDEV_DEVFLAGS],
; it sends close command (0Eh) to the SF_TABLE.
; This procedure also increments the refcount of SF_TABLE.
UNKNOWN_FUNCTION_3121H:


						ORG		04738H
ORIGINAL_CALL_STRATEGY_AND_INTERRUPT:	JMP	ORIGINAL_CALL_STRATEGY_AND_INTERRUPT

						ORG		04FC8H
INT_00H_HANDLER:		JMP		INT_00H_HANDLER

						ORG		5225H
ORIGINAL_GET_NEXT_CLUSTER:	JMP	COMPAT_GET_NEXT_CLUSTER
						NOP



						ORG		540Ch
; For testing MEDIACHECK_READYCDS
						CALL	COMPAT_MEDIACHECK_READYCDS
						RET



						ORG		565DH
ORIGINAL_GETBUFFR:		XOR		SI,SI
						ORG		565FH
						JMP		COMPAT_GETBUFFR

						ORG		575EH
ORIGINAL_BUFFWRITE:		JMP		ORIGINAL_BUFFWRITE



; Make sure to catch internal call, which is not supposed to happen though.
						ORG		57C5h
ORIGINAL_INT_21H_4BH_EXEC_OR_LOAD:
						TSUGARU_DEBUG_BREAK	0FFh
						JMP		ORIGINAL_INT_21H_4BH_EXEC_OR_LOAD	; Not supposed to come here any longer

						ORG		5BF6h
						NOP
						NOP
						NOP
						NOP
						NOP
						NOP
						NOP
						NOP
						NOP
						NOP
						NOP
						NOP
EXEC_OR_LOAD_LAST:		JMP		EXEC_OR_LOAD_LAST



						ORG		5C04h
ORIGINAL_INT_21H_31H_EXIT_STAY_RESIDENT:



						ORG		5C2DH
INT_27H_END_BUT_STAY_RESIDENT:	JMP		INT_27H_END_BUT_STAY_RESIDENT



						ORG		6208h
						NOP
						NOP
						NOP
						NOP
						NOP
						NOP
						JMP		COMPAT_MKFUL ; 1679:0000620E
; For testing MAKE_FULLPATH



						ORG		65FDh
ORIGINAL_INT_21H_3EH_FCLOSE:
						MOV		AH,03EH
						CALL	COMPAT_INT21
						RET
						NOP

						ORG		6630h
ORIGINAL_INT_21H_3FH_FREAD:
						MOV		AH,03FH
						CALL	COMPAT_INT21
						RET
						NOP

						ORG		6689h
ORIGINAL_INT_21H_42H_LSEEK:
						MOV		AH,042H
						CALL	COMPAT_INT21
						RET
						NOP

						ORG		6784h
ORIGINAL_INT_21H_3DH_FOPEN:
						MOV		AH,03DH
						CALL	COMPAT_INT21
						RET
						NOP
