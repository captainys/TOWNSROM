;						CPU		386						; --USE_IN_NASM--
;						BITS	16						; --USE_IN_NASM--
;ADDRESSZERO:											; --USE_IN_NASM--
;%macro					PLACE 1							; --USE_IN_NASM--
;						TIMES	%1-($-$$) DB 0			; --USE_IN_NASM--
;%endmacro												; --USE_IN_NASM--


						.386				; --NOT_IN_NASM-- 
						ASSUME	CS:CODE		; --NOT_IN_NASM-- 


; FM TOWNS's IO.SYS reads MSDOS.SYS for 7800h bytes from physical address C2014800
; 
; To use it with COMMAND.COM taken from FM TOWNS MX ROM,
; 0D41H must be altered:
;     76H -> EBH
; so that it skips the version check.
;
; Well, eventually free COMMAND.COM also will replace it.



						INCLUDE		UTILMAC.ASM
						INCLUDE		DOSDEF.ASM
						INCLUDE		TOWNSMAC.ASM


; Is MASM really a two-pass assembler?
; I need to define this constant before used.
; MASM gives Phase Error between Passes, otherwise.
YSDOS_RELOC_BUFFER_LEN	EQU		1024


CODE					SEGMENT	USE16

						JMP		DOSINIT


						INCLUDE	DOSLABEL.ASM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI   Driver Info
;   ES:BX   Device Driver Request Header
CALL_STRATEGY_AND_INTERRUPT		PROC
						PUSH	GS	; TownsOS V1.1 drivers may destroy GS and FS
						PUSh	FS
						CALL	CALL_STRATEGY
						CALL	CALL_INTERRUPT
						POP		FS
						POP		GS
						RET
CALL_STRATEGY_AND_INTERRUPT		ENDP

;...............................................................................

CALL_STRATEGY			PROC
						MOV		AX,DS:[SI+SYSDEV_STRATEGY]
						MOV		CS:[CALL_POINTER],AX
						MOV		CS:[CALL_POINTER+2],DS
;						CALL	FAR [CS:CALL_POINTER]		; --USE_IN_NASM--
						CALL	DWORD PTR CS:[CALL_POINTER]	; --NOT_IN_NASM--
						RET
CALL_STRATEGY			ENDP

;...............................................................................

CALL_INTERRUPT			PROC
						MOV		AX,DS:[SI+SYSDEV_INTERRUPT]
						MOV		CS:[CALL_POINTER],AX
						MOV		CS:[CALL_POINTER+2],DS
;						CALL	FAR [CS:CALL_POINTER]		; --USE_IN_NASM--
						CALL	DWORD PTR CS:[CALL_POINTER]	; --NOT_IN_NASM--
						RET
CALL_INTERRUPT			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Create PDB (Program Data Block) aka PSP (Process Segment Prefix).  WTF!
; Input:
;    DX=Segment of PSP to create
;    SI=ENDMEM (Don't know if it is always ENDMEM)
; Output:
;    DX stays the same
;    DS=ES=DX
;    Pretty much everything destroyed.  SI and DI for sure.
; Memo to myself: Need to be careful about the high-word of 32-bit registers.
;                 Maybe called from DOS-Extender.
; 6AFF
CREATE_PDB				PROC
						PUSH	FS

						MOV		DS,CS:[CurrentPDB]
						MOV		ES,DX

						XCHG	DX,SI	; ENDMEM(?) saved in DX

						; First Copy
						XOR		SI,SI
						XOR		DI,DI
						MOV		CX,PROG_SEG_PREFIX_size
						REP MOVSB
						MOV		ES:[PSP_ENDMEM],DX

						MOV		DX,ES	; Recover DS not to confuse myself.

						; At this time:
						;    DS is previous current PDB (or PSP WTF!)
						;    ES is the new PSP.

						MOV		SI,PSP_FILE_TABLE
						MOV		CX,DS:[PSP_FILE_TABLE_SIZE]
CREATE_PDB_JFN_LOOP:
						; Tentatively AL=0FFH (not open)

						; First find file handle from JFN -> BX
						; Guaranteed to be within the PSP_FILE_TABLE_SIZE
						MOVZX	AX,BYTE PTR DS:[SI]
						MOV		BYTE PTR ES:[SI],0FFH		; Tentative
						CMP		AL,0FFH
						JE		CREATE_PDB_NEXT_JFN

						; Then find file-table entry from SF_TABLE link.
						CALL	GET_SF_ENTRY_FROM_SFN	; My version returns FS:DI and preserves ES.

						; FS:DI is SF_TABLE
						JB		CREATE_PDB_NEXT_JFN
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_NO_INHERIT
						JNE		CREATE_PDB_NEXT_JFN

						; Yes inherit. (By the way AX is already destroyed)
						MOV		AL,BYTE PTR FS:[DI+SF_MODE]
						AND		AL,0F0h
						CMP		AL,070h					
						; OK.  What is this mode?  I need research.
						; https://sites.google.com/site/pcdosretro/dostables
						; This tells bit4-7 of SF_MODE is sharing.  However, all bits are not supposed to be 1 simultaneously.
						; What makes (sf.SF_MODE & 0xF0)==0x70?
						JE		CREATE_PDB_NEXT_JFN

						CALL	DEVCALL_OPEN_SF		; This destroys AL
						INC		WORD PTR FS:[DI+SF_REFCOUNT]

						MOV		AL,DS:[SI]
						MOV		ES:[SI],AL

CREATE_PDB_NEXT_JFN:
						INC		SI
						LOOP	CREATE_PDB_JFN_LOOP


						; Connect current PDB to the next of new PDB
						; Make new PDB current.
						MOV		AX,CS:[CurrentPDB]
						MOV		ES:[PSP_CALLER_PSP_SEG],AX
						MOV		CS:[CurrentPDB],ES


						; Also SETMEM.  Don't forget to recover AX=[ENDMEM].
						MOV		AX,ES:[PSP_ENDMEM]
						CALL	SETMEM
						MOV		BYTE PTR CS:[CREATE_PDB_FLAG],0		; Looks like it is not used.
						POP		FS
						RET
CREATE_PDB				ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Initialize part of the PSP.
; Input:
;   DX   PSP Segment
;   AX   ENDMEM (Not sure if it is always ENDMEM)
; On Return:
;   DX unchanged
;   DS=ES=DX
;   SI,DI destroyed.
;   DF=0
; It does not initialize PSP:[PSP_CALLF_TO_DOS] (make it CALLF 0:0)
; The original MSDOS.SYS is writing a meaningless address.
; I don't think it is actually used.
SETMEM					PROC
						MOV		ES,DX
						PUSH	0
						POP		DS

						MOV		ES:[PSP_ENDMEM],AX

						CLD
						MOV		SI,22H*4
						MOV		DI,PSP_INT22H
						MOVSD						; INT 22H Vector
						MOVSD						; INT 23H Vector
						MOVSD						; INT 24H Vector

						MOV		DS,DX
						MOV		BYTE PTR DS:[PSP_CALLF_TO_DOS],09AH	; Inst for CALLF
						MOV		DWORD PTR DS:[PSP_CALLF_TO_DOS+1],0	; 0:0  I don't think it is used.

						MOV		WORD PTR DS:[PSP_INT20H],20CDH			; Inst for INT 20H
						MOV		WORD PTR DS:[PSP_INT21H_RETF],21CDH	; Inst for INT 21H
						MOV		WORD PTR DS:[PSP_INT21H_RETF+2],0CBH	; Inst for RETF

						MOV		WORD PTR DS:[PSP_FILE_TABLE_POINTER],PSP_FILE_TABLE
						MOV		WORD PTR DS:[PSP_FILE_TABLE_POINTER+2],DX
						MOV		WORD PTR DS:[PSP_FILE_TABLE_SIZE],PSP_FILE_LEN

						MOV		DWORD PTR DS:[PSP_NEXT_PSP],0FFFFFFFFh

						RET
SETMEM					ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input:
;    DS:SI  Source BPB (BIOS Parameter Block)
;    ES:BP  DPB to create
;    BX,CX,DX destroyed
; Original SETDPB also destroys AX
; Tentative:
; RUN 1679:00006BD3
SETDPB					PROC
						PUSH	EAX
						PUSH	ECX

						; The disk layout:
						; 
						; Sector 0
						;     Number of reserve sectors.  IPL etc.
						; --------
						;     File Allocation Table
						;     Back Up File Allocation Table
						;     (In total File Allocation Table times [BPB_NUM_FATS])
						; --------
						;     Root Directory
						; --------
						;     Data
						; --------

						; Skip DRIVE and UNIT.  Will be set outside of this function.

						MOV		AX,DS:[SI+BPB_BYTES_PER_SECTOR]
						MOV		ES:[BP+DPB_BYTES_PER_SECTOR],AX

						MOVZX	AX,DS:[SI+BPB_SECTORS_PER_CLUSTER]
						MOV		ES:[BP+DPB_CLUSTER_MASK],AL
						DEC		BYTE PTR ES:[BP+DPB_CLUSTER_MASK]

						BSF		AX,AX	; AX=1->0,  2->1,  4->2, ...
						; I think BSF does op1=log2(op2).
						; The question is why the original MSDOS.SYS is not using this instruction.
						; Was this added in 80386 or 80286?
						MOV		ES:[BP+DPB_CLUSTER_SHIFT],AL

						MOV		AX,DS:[SI+BPB_NUM_RESERVE_SECTORS]  ; Sectors to skip to get to FAT.  Will make DPB_FIRST_FAT_SECTOR
						MOV		ES:[BP+DPB_FIRST_FAT_SECTOR],AX

						MOV		AL,DS:[SI+BPB_NUM_FATS]		; I expect it to be two.
						MOV		ES:[BP+DPB_NUM_FATS],AL

						MOV		AX,DS:[SI+BPB_NUM_ROOTDIR_ENTS]
						MOV		ES:[BP+DPB_NUM_DIRENTS],AX

						MOV		AL,DS:[SI+BPB_MEDIA_DESC_TYPE]
						MOV		ES:[BP+DPB_MEDIA_DESC_TYPE],AL


						MOV		AX,DS:[SI+BPB_SECTORS_PER_FAT]	; Looks like WORD in BPB, but BYTE in DPB.
						MOV		ES:[BP+DPB_SECTORS_PER_FAT],AL

						; Looks like a disk have multiple File Allocation Tables for redundancy.
						; I saw a 1232KB disk image has two.
						; This probably calculates total number of sectors used by all FATs.
						MUL		BYTE PTR DS:[SI+BPB_NUM_FATS]
						ADD		AX,DS:[SI+BPB_NUM_RESERVE_SECTORS]
						; Directory sector follows File Allocation Tables.
						MOV		ES:[BP+DPB_FIRST_DIR_SECTOR],AX



						; Next want to get to the first data sector.
						; The first data sector follows the root directory.

						MOV		CX,DS:[SI+BPB_BYTES_PER_SECTOR]
						TEST	CX,(BYTES_PER_DIRENT-1)
						SHR		CX,DIRENT_SHIFT						; CX=SectorLength/BytesPerDirEnt=num_dirent_per sector
						; CX is number of directory entries per sector

						MOV		AX,DS:[SI+BPB_NUM_ROOTDIR_ENTS]
						; AX is number of directory entries

						ADD		AX,CX
						DEC		AX
						; Round up.  In case [BPB_NUM_ROOTDIR_ENTS]!=Integer * (num of DIRENTs per sector)

						XOR		DX,DX
						DIV		CX
						; AX/CX will give how many sectors are used for directory entries.

						ADD		AX,ES:[BP+DPB_FIRST_DIR_SECTOR]
						; Add first directory sector (root directory sector) to get to the data sector.

						MOV		ES:[BP+DPB_FIRST_DATA_SECTOR],AX



						; Next want to get to DPB_MAX_CLUSTER_NUM
						MOVZX	ECX,AX
						; ECX is the first data sector.

						MOVZX	EAX,WORD PTR DS:[SI+BPB_TOTAL_NUM_SECTORS] ; Is this why DOS3.x could only use up to 128MB?
						AND		EAX,EAX
						JNE		SETDPB_HAVE_TOTAL_NUM_SECTORS
						MOV		EAX,DS:[SI+BPB_TOTAL_NUM_SECTORS32]
SETDPB_HAVE_TOTAL_NUM_SECTORS:
						; EAX is total number of sectors.

						SUB		EAX,ECX
						; EAX is total number of data sectors.

						MOV		CL,ES:[BP+DPB_CLUSTER_SHIFT]
						SHR		EAX,CL
						; EAX is total number of clusters.

						INC		EAX
						; I don't understand why increment by one, but MSDOS.SYS does it.
						; If it is DEC, it is more understandable, EAX will be the maximum cluster number.
						; By incrementing, it's not even the maximum cluster number, nor the number of clusters.
						; WTF!

						MOV		ES:[BP+DPB_MAX_CLUSTER_NUM],AX




						MOV		DWORD PTR ES:[BP+DPB_LAST_CLUSTER_ALLOC],0FFFF0000h
						; LAST_CLUSTER_ALLOC or Current Directory?  MS-DOS V2.0 source says 0000h means cwd is root.
						; Number of free clusters is 0ffffh (unknown at this time)

						POP		ECX
						POP		EAX
						RET
SETDPB					ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



NUL_STRATEGY:
						OR		WORD PTR ES:[BX+REQ_STATUS],DEVREQ_STATUS_NOERROR
						RETF
NUL_INTERRUPT:
						RETF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



YSDOS_INFINITE_LOOP:	JMP		YSDOS_INFINITE_LOOP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



JUST_IRET:				IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



						INCLUDE		TOWNSPRC.ASM
						INCLUDE		TOWNSDAT.ASM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



						INCLUDE		INT21H.ASM
						INCLUDE		INT2FH.ASM
						INCLUDE		WILDCARD.ASM
						INCLUDE		UTIL.ASM
						INCLUDE		MEMORY.ASM
						INCLUDE		PROCESS.ASM
						INCLUDE		FILE.ASM
						INCLUDE		DISK.ASM
						INCLUDE		SFTABLE.ASM
						INCLUDE		FAT.ASM
						INCLUDE		DIR.ASM
						INCLUDE		BUFFER.ASM
						INCLUDE		STDIO.ASM
						INCLUDE		DEVCALL.ASM
						INCLUDE		SYSDEV.ASM
						INCLUDE		COMPATI.ASM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; To allow abort while processing INT, SS,SP and all other registers need to be
; saved, and restored.  Use SAVE_REGISTERS and RESTORE_REGISTERS macros.
						ALIGN	4
SP_RESTORE_POINT		DW		0
SS_RESTORE_POINT		DW		0


PREVIOUS_DISK_LABEL		DD		0


FILENAME_BUFFER_LEN		EQU		128	; 128 letters
MAX_PATH				EQU		FILENAME_BUFFER_LEN-1
FILENAME_BUFFER2		DB		FILENAME_BUFFER_LEN dup(0)
						DD		0	; Terminate C-String
TEMP_16CHAR_BUFFER		DB	16 dup(0)


YSDOS_UTILITY_BUFFER:
YSDOS_STACK_BEGIN		DB		512 dup (0)	; One entrance takes 32-bit reg*7 + 16-bit reg*4 + 16-bit mem*2=34 bytes.
YSDOS_STACK				DB		0CCh,0CCh	; Two-byte cowards.

YSDOS_RELOC_BUFFER		DW		(YSDOS_RELOC_BUFFER_LEN/2) dup(0)
						; Rather than just wasting, I use it for relocation-table buffer.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



						ALIGN	010h
						; Initialization Code here will be used as a system buffer once initialization is done.
SYSTEM_BUFFER:

; INPUT from IO.SYS
;    DX     ENDMEM 0C000H in TOWNS
;    DS:SI  DEVHEAD
DOSINIT:
						CALL	DOSINIT_TOWNS_NOTIFY_CS

						CLD
						CLI


						ROR		ESI,16
						MOV		SI,DS
						ROR		ESI,16

						MOV		DWORD PTR CS:[DEVHEAD],ESI


;;;;;;;; This region will be unnecessary when this code fully take over MSDOS.SYS >>
						MOV		WORD PTR CS:[MAXSEC],MINIMUM_SECTOR_LENGTH
						MOV		WORD PTR CS:[DMA_BUFFER_PTR],DMA_BUFFER_INITIAL_OFFSET
;;;;;;;; This region will be unnecessary when this code fully take over MSDOS.SYS <<


						; Don't touch DS and SI

						MOV		CS:[ENDMEM],DX
						MOV		CS:[INITSP],SP
						MOV		CS:[INITSS],SS

						PUSH	CS
						POP		ES
						PUSH	CS
						POP		SS
						MOV		SP,INITSTACK


						MOV		EAX,0CCCCCCCCh
						MOV		DI,OFFSET TEMPORARY_DPB
						MOV		CX,400h
						REP		STOSB


						XOR		AX,AX
						MOV		FS,AX	; FS Real-Mode INT Vectors


						; INT 2AH Handler
						MOV		WORD PTR FS:[02AH*4]  ,OFFSET JUST_IRET
						MOV		WORD PTR FS:[02AH*4+2],CS


						; First CON device.
						MOV		DWORD PTR CS:[SFT_CONSDEV_SI],ESI
						MOV		DWORD PTR CS:[BCON],ESI

						CALL	CHARINIT

						ADD		SI,SYSDEV_NAME	; Point to the File Name.  Supposed to be "CON"
						MOV		DI,OFFSET SFT_CONSDEV_FILE_NAME
						MOVSD
						MOVSD

						; Question is if there is a reason to do this flag-setting after CHARINIT.
						; Shouldn't it be set before calling CHARINIT?
						; Both MS-DOS V2.0 source and FM TOWNS MSDOS.SYS does it after CHARINIT.
						MOV		SI,CS:[SFT_CONSDEV_SI]
						OR		WORD PTR [SI+SYSDEV_DEVFLAGS],SYSDEV_DEVFLAG_CONS_IN+SYSDEV_DEVFLAG_CONS_OUT



						; Looks like IO.SYS is supposed to assemble a chain so that
						; CON device comes first and CLOCK device last.
DOSINIT_UNTIL_CLOCK_LOOP:
						LDS		SI,[SI]	; Next device
						CALL	CHARINIT
						TEST	WORD PTR [SI+SYSDEV_DEVFLAGS],SYSDEV_DEVFLAG_CLOCK
						JE		DOSINIT_UNTIL_CLOCK_LOOP

						; DS:[SI] is the fisrt-discovered CLOCK device, but probably is the last.
						MOV		WORD PTR CS:[BCLOCK],SI
						MOV		CS:[BCLOCK+2],DS

						; Question is what this BP will become in the end.
						MOV		BP,TEMPORARY_DPB
						LDS		SI,[SI]	; Next device
DOSINIT_BLOCK_DEV_LOOP:
						CALL	CHARINIT
						; DOS2.0 labels 8000H as SDEVTYP
						; https://sites.google.com/site/pcdosretro/dostables labels as a redirected device.
						; Both MSDOS.SYS disassembly and MS-DOS V2.0 source tests against 8000H.
						; What's the correct interpretation?
						; -> Turned out SF_ENTRY.DEVFLAGS and SYSDEV.DEVFLAGS have different meaning.
						;    It is checking BLOCK devices.
						TEST	WORD PTR [SI+SYSDEV_DEVFLAGS],SYSDEV_DEVFLAG_IS_CHARDEV
						JNE		DOSINIT_NEXT_BLOCK_DEV


						; Bit15 of SYSDEV_DEVFLAGS is zero
						MOVZX	CX,BYTE PTR CS:[DEVCALL+REQ_INIT_NUM_UNIT_RETURN]
						MOV		[SI+SYSDEV_NAME],CL	; Confirmed behavior.  Writing CL to where name should be?

						; DL=Drive Code
						; DH=Unit Code
						MOVZX	DX,BYTE PTR CS:[NUM_DPB]


						; Save Device Info (?) Pointer
						PUSH	DS
						PUSH	SI

						; What's BPB?  -> BIOS Parameter Block
						_LDS	BX,CS:[DEVCALL+REQ_INIT_BPB_ARRAY_RETURN]

						; Repeat NUM_UNIT times (CX times)
DOSINIT_UNIT_LOOP:
						MOV		SI,[BX]
						ADD		BX,2

; #ifdef FOR_TOWNS
						CALL	DOSINIT_PATCH_TOSV11L30_MENU_DRV
; #endif

						; Looks like NUM_DPB is number of drives.
						MOV		WORD PTR CS:[BP+DPB_DRIVE_CODE],DX ; Drive Code, Unit Code

						; SETDPB
						;  In:  BP    Pointer to DBP
						;       DS:SI Pointer to BIOS Parameter Block (BPB)
						PUSH	BX
						PUSH	CX
						PUSH	DX
						CALL	SETDPB
						MOV		DX,CS:[BP+DPB_BYTES_PER_SECTOR]
						CMP		DX,CS:[MAXSEC]
						JLE		DOSINIT_NOT_UPDATE_MAXSEC
						MOV		CS:[MAXSEC],DX
DOSINIT_NOT_UPDATE_MAXSEC:
						POP		DX
						POP		CX
						POP		BX

						POP		EAX
						MOV		CS:[BP+DPB_PTR_TO_DEV_DRIVER],EAX
						PUSH	EAX

						INC		DH
						INC		DL

						ADD		BP,DRIVE_PARAM_BLOCK_size
						LOOP	DOSINIT_UNIT_LOOP

						MOV		BYTE PTR CS:[NUM_DPB],DL

						POP		SI
						POP		DS

DOSINIT_NEXT_BLOCK_DEV:
						LDS		SI,[SI]				; Next Device Driver
						CMP		SI,0FFFFH
						JNE		DOSINIT_BLOCK_DEV_LOOP



						; At this time:
						; Temporary DPBs are from TEMPORARY_DPB
						; 20H times [NUM_DPB] bytes.

						; BP-TEMPORARY_DPB=Total DPB size

						; No longer need to traverse device-driver chain using DS:SI

						; From SYSTEM_BUFFER,
						; Offset           Bytes        Usage
						; +0000H           10H          For Memory-Management?
						; +0010H           [MAXSEC]     Sector Buffer.  If TOWNS_CD is installed, it should be 0800H
						; +0010H+[MAXSEC]  20H*[NUM_DPB]  True DPB (DPB will be transferred)

						; [FIRST_DPB_PTR]<-SYSTEM_BUFFER+[MAXSEC]+0010H

						PUSH	CS
						POP		DS

						; [FIRST_DPB_PTR] is the location where DPB will be finally transferred.
						MOV		AX,OFFSET SYSTEM_BUFFER+IO_BUF_INFO_size
						ADD		AX,[MAXSEC]
						MOV		[FIRST_DPB_PTR],AX
						MOV		[FIRST_DPB_PTR+2],CS

						MOVZX	EBX,BP
						SUB		BX,OFFSET TEMPORARY_DPB	; BX=Total DPB length
						ADD		BX,AX				; [FIRST_DPB_PTR]+DBP length is true address of free memory.

						PUSH	BX					; Remember true address of free memory. (*1)



						; The original MSDOS.SYS leaves DPB in the temporary-DPB buffer, and then
						; transfers to the permanent location in MOVDPB.
						; The reason why doing so is because the permanent location may overlap
						; with this initialization code if [MAXSEC] is very small, which won't be
						; the case in FM TOWNS since TOWNS_CD will return 2KB sector size.
						; To be safe I force [MAXSEC] to be at least 2KB by initializing [MAXSEC] to 2KB.
						; So, I can transfer DPB to the permanent location here.

						; Supposed to be DS=ES=CS.
						; AX is supposed to be FIRST_DPB_PTR
						PUSH	AX

						MOV		SI,OFFSET TEMPORARY_DPB
						MOV		DI,AX
						MOV		AH,CS:[NUM_DPB]
						MOV		AL,DRIVE_PARAM_BLOCK_size
						MUL		AH
						MOV		CX,AX
						REP		MOVSB

						MOV		DI,CS
						SHL		EDI,16
						POP		DI							; Now DI=Pointer to DPBs, High-Word of EDI is CS
						MOVZX	CX,BYTE PTR [NUM_DPB]			; Number of DPBs
DOSINIT_MAKE_DPB_CHAIN:
						MOV		DWORD PTR [DI+DPB_PTR_TO_NEXT_DPB],EDI
						ADD		WORD PTR [DI+DPB_PTR_TO_NEXT_DPB],DRIVE_PARAM_BLOCK_size  ; Second DPB location after transferred
						MOV		BYTE PTR [DI+DPB_ACCESS_FLAG],0FFH		; -1 means never accessed.
						ADD		DI,DRIVE_PARAM_BLOCK_size
						LOOP	DOSINIT_MAKE_DPB_CHAIN

						MOV		DWORD PTR [DI+DPB_PTR_TO_NEXT_DPB-DRIVE_PARAM_BLOCK_size],0FFFFFFFFH  ; Termination



						;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
						; Done with DPBs
						;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



						; BX is still offset to the true address of free memory.
						MOV		DX,CS
						SHL		EDX,4
						ADD		EDX,EBX
						ADD		EDX,0FH
						SHR		EDX,4	; Make it Segment Scale.



						; Purpose at this time unknown.
						MOV		WORD PTR CS:[DSKCHRET+3],CS



						; Set up Real-Mode INT Handlers
						XOR		AX,AX
						MOV		ES,AX
						MOV		AX,CS
						SHL		EAX,16

						MOV		AX,OFFSET INT_00H_HANDLER
						MOV		DWORD PTR ES:[0000H],EAX

						MOV		AX,OFFSET JUST_IRET
						MOV		DI,020H*4	; INT 20H Handler
						MOV		CX,9
						REP STOSD

						MOV		DI,02AH*4	; INT 2AH Handler
						MOV		CX,016H
						REP STOSD


						; MSDOS.SYS writes:
						;    0000:000000C0 EA88117916                JMPF    1679:1188
						; which destroys INT vector for INT 30h and 31h.
						; I am suspecting it is a bug.
						; MOV		DWORD PTR ES:[0C0h],0791188EAh
						; MOV		BYTE PTR ES:[0C4h],016h

						MOV		WORD PTR ES:[20h*4],OFFSET INT_20H_ABORT
						MOV		WORD PTR ES:[21h*4],OFFSET INT_21H_COMMAND

						MOV		WORD PTR ES:[22h*4],0100h	; INT 22H Handler seems to be in the first free memory block+100h
						MOV		ES:[22h*4+2],DX				; DX is the first free segment.

						MOV		WORD PTR ES:[25h*4],OFFSET INT_25H_BIOS_DISKREAD
						MOV		WORD PTR ES:[26h*4],OFFSET INT_26H_BIOS_DISKWRITE
						MOV		WORD PTR ES:[27h*4],OFFSET INT_27H_END_BUT_STAY_RESIDENT
						MOV		WORD PTR ES:[2Fh*4],OFFSET INT_2FH_HANDLER



						; Restore ES=CS,  BP must be BP=CS on JMP MOVDPB
						MOV		BP,CS
						MOV		ES,BP



						; What's this Jump Table?  Need further research.
						; Doesn't exist in MSDOS V2.0 soruce.
						MOV		DI,OFFSET UNKNOWN_JUMP_TABLE+2
						MOV		AX,CS
						MOV		CX,15
DOSINIT_INIT_UNKNOWN_JUMP_TABLE:
						STOSW
						ADD		DI,2
						LOOP	DOSINIT_INIT_UNKNOWN_JUMP_TABLE



						; Set up PSP for MSDOS.SYS (Looks like)
						; AX is still CS
						SHL		EAX,4
						ADD		EAX,OFFSET INITBLOCK+0FH	; 0fh for rounding up to page border.
						SHR		EAX,4
						MOV		CS:[CurrentPDB],AX			; Actually PDB=PSP, apparently.

						PUSH	BP							; (*2)
						PUSH	DX							; (*3)
						MOV		DX,AX
						MOV		AX,CS:[ENDMEM]

						; SETMEM
						; According to MISC.ASM of MS-DOS V2.0 source,
						;   Input DX=Segment (PDB:Process Data Block?)
						;         AX=Size of Memory in Paragraphs
						;   ES=DS=Incoming_DX upon return.
						;   Completely prepares a program base at specified segment.
						;   All registers except BP and DX will be destroyed.
						; Size of Memory appears to mean entire conventional memory.
						; Not the size of the program.

						; My implementation destroys EAX, set DS=ES=DX,
						; and make CALLF_TO_DOS as CALLF 0000:0000 since the original MSDOS.SYS
						; is not setting a meaningful address anyway.
						CALL	SETMEM

						MOV		DI,OFFSET PSP_FILE_TABLE

						XOR		EAX,EAX
						DEC		AL
						ROR		EAX,8
						STOSD	; MOV		DWORD PTR [PSP_FILE_TABLE   ],0FF000000h

						XOR		EAX,EAX
						DEC		EAX
						STOSD	; MOV		DWORD PTR [PSP_FILE_TABLE+ 4],0FFFFFFFFh
						STOSD	; MOV		DWORD PTR [PSP_FILE_TABLE+ 8],0FFFFFFFFh
						STOSD	; MOV		DWORD PTR [PSP_FILE_TABLE+12],0FFFFFFFFh
						STOSD	; MOV		DWORD PTR [PSP_FILE_TABLE+16],0FFFFFFFFh

						PUSH	CS
						POP		DS
						PUSH	CS
						POP		ES

						; CS:[FIRST_SFT_PTR] is already DW OFFSET SFTABLE.
						MOV		CS:[FIRST_SFT_PTR+2],CS	; MSDOS V2.0 Source tells necessary for console out.


						; Print-Logo loop from CS:0F08h, but I don't need it.


						POP		DX	; (*3)
						POP		BP	; (*2)
						POP		CX  ; (*1) Must be true address of free memory.


						MOV		CS:[DMA_BUFFER_SEG],DX

						MOV		SS,CS:[INITSS]
						MOV		SP,CS:[INITSP]



						; I make sure SYSTEM_BUFFER is 16-byte aligned, but just in case, add 0FH and then shift.
						; According to MS-DOS V2.0 source, SYSTEM_BUFFER will become the first I/O Buffer.
						MOV		DI,OFFSET SYSTEM_BUFFER+0FH
						AND		DI,0FFF0H

						MOV		WORD PTR CS:[DI+IO_BUF_DRV_LOGICAL],00FFH	; Logical Drive=-1, Dirty=0
						MOV		DWORD PTR CS:[DI+IO_BUF_NEXT],0FFFFFFFFH	; Next=NULL

						SHR		DI,4
						MOV		AX,CS
						ADD		AX,DI
						MOV		WORD PTR CS:[IO_BUFF_PTR],0
						MOV		WORD PTR CS:[IO_BUFF_SEG],AX

						; Looks like I shouldn't initiailize LASTBUFFER here.
						; Towns OS V1.1 destroys buffer if I do so.
						; MOV		WORD PTR CS:[LASTBUFFER],0
						; MOV		WORD PTR CS:[LASTBUFFER+2],AX


						; Make one big memory arena.
						MOV		FS,DX
						MOV		BYTE PTR FS:[MCB_CHAIN_ID],MCB_CHAIN_ID_LAST
						MOV		WORD PTR FS:[MCB_PID],MCB_PID_SYSTEM
						MOV		AX,CS:[ENDMEM]
						SUB		AX,DX
						DEC		AX
						MOV		WORD PTR FS:[MCB_BLOCK_SIZE],AX
						MOV		WORD PTR CS:[FIRST_MCB],DX
						; According to https://www.drdobbs.com/architecture-and-design/mapping-dos-memory-allocation/184408026
						; block size does not include MCB itself.  Therefore, DEC AX.



						; Create Process Data Block aka PSP.  Ah, wait.  Wasn't it done in SETMEM?
						; Turned out CreatePDB proc falls down to SETMEM.  The two processes share
						; some bytes.  Or, in other words, SETMEM is part of CreatePDB.

						MOV		SI,CS:[ENDMEM]
						; DX is still first free segment
						INC		DX
						CALL	CREATE_PDB
						PUSH	CS
						POP		ES
						; Input: DX=Segment for PDB to Create
						;        SI=ENDMEM?
						; On return:
						;        DS=ES=Incoming_DX
						;        Pretty much everything except DX will be destroyed
						;        Updates CS:[CurrentPDB] to the one created.
						;        Somehow, CONSDEV refcount is increased from 3 to 6

						; CS:[CurrentPDB] must be equal to 1+(First Free Segment), which is earlier DX.



						; Finishing Up!
						; Somehow CREATE_PDB increase console-device refcount from 3 to 6.  Make it back to 3.
						MOV		WORD PTR CS:[SFT_CONSDEV_REFCOUNT],3

						; Return from initialization must be DS:DI pointing to FIRST_DPB_PTR
						MOV		DI,OFFSET FIRST_DPB_PTR

						; DS needs to be as returned from CREATE_PDB.
						; So, DS is PSP for MSDOS.SYS?

						CALL	DOSINIT_TOWNS_CLS
						CALL	DOSINIT_TOWNS_PALETTE

						RETF



; MS-DOS V2.0 source code labels this function as CHARINIT.
; I don't know why it is called "CHARINIT".  Maybe it has a historical meaning.
CHARINIT				PROC
						MOV		BX,OFFSET DEVCALL
						MOV		DWORD PTR CS:[BX+REQ_LEN],REQ_INIT_LEN+(REQ_INIT_CMD*10000h)
						MOV		WORD PTR CS:[BX+REQ_STATUS],0

						; FM TOWNS MSDOS.SYS is saving ES,AX, and BX, but I think AX and BX don't need to be saved.
						; At least IO.SYS of TOWNS OS looks to be happy with not saving AX and BX.
						PUSH	ES
						PUSH	CS
						POP		ES
						CALL	CALL_STRATEGY_AND_INTERRUPT
						POP		ES
						RET

CHARINIT				ENDP



						INCLUDE	TOWNSINI.ASM



; INITSTACK and MEMSTART (Temporary-DPB location) in TOWNS's MSDOS.SYS was defined as:
; INITSTACK				EQU		06E16H
; MEMSTART				EQU		06E18H
; However, MSDOS.SYS was designed for really low-memory configuration, which I don't care.
; I only care FM TOWNS, which has 1MB RAM minimum.  Therefore, I can put temporary stack and
; temporary DPB far back in CS, which make room for more code insertion.
INITSTACK				EQU		0EFFCh
TEMPORARY_DPB			EQU		0F000h


CODE					ENDS	; --NOT_IN_NASM--

						END		; --NOT_IN_NASM--
