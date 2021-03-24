; Included from YSDOS.ASM



INT21H_CALLER_CS		DW		0



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



STORE_LASTERR_IF_CF		MACRO	REG										; --NOT_IN_NASM--
						LOCAL	NOCF									; --NOT_IN_NASM--
						JNC		NOCF									; --NOT_IN_NASM--
						MOV		WORD PTR CS:[EXTENDED_ERROR_CODE],REG	; --NOT_IN_NASM--
NOCF:																	; --NOT_IN_NASM--
						ENDM											; --NOT_IN_NASM--



;%MACRO					STORE_LASTERR_IF_CF		1						; --USE_IN_NASM--
;						JNC		%%NOCF									; --USE_IN_NASM--
;						MOV		WORD CS:[EXTENDED_ERROR_CODE],%1		; --USE_IN_NASM--
;%%NOCF:																; --USE_IN_NASM--
;%ENDMACRO																; --USE_IN_NASM--




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



SET_CF_BEFORE_IRET		PROC
;
;  SP+0  BP
;  SP+2  Return IP for this proc
;  SP+4  Return IP for IRET
;  SP+6  Return SEG for IRET
;  SP+8  FLAGS
						PUSH	BP
						MOV		BP,SP
						JB		SET_CF_BEFORE_IRET_SET
SET_CF_BEFORE_IRET_CLEAR:
						AND		WORD PTR SS:[BP+8],0FFFEh
						POP		BP
						RET
SET_CF_BEFORE_IRET_SET:
						OR		WORD PTR SS:[BP+8],1
						POP		BP
						RET
SET_CF_BEFORE_IRET		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_COMMAND			PROC
; Safe to call functions with absolutely no re-entry before saving registers.
						CMP		BYTE PTR CS:[INDOS],0
						JNE		INT_21H_ALREADY_INDOS

						PUSH	BP
						MOV		BP,SP
						MOV		BP,[BP+2]	; Caller CS
						MOV		CS:[INT21H_CALLER_CS],BP
						POP		BP
INT_21H_ALREADY_INDOS:

						; Ok, Ok.  I'm going to make it a jump table.  I will do it.

						; These are the simple functions. >>
						CMP		AH,19H
						JE		INT_21H_19H_GET_CURRENT_DRIVE
						CMP		AH,1AH
						JE		INT_21H_1AH_SET_DTA_ADDRESS
						CMP		AH,25H
						JE		INT_21H_25H_SET_INTVEC
						CMP		AH,2AH
						JE		INT_21H_2AH_GET_DATE
						CMP		AH,2BH
						JE		INT_21H_2BH_SET_DATE
						CMP		AH,2Ch
						JE		INT_21H_2CH_GET_TIME
						CMP		AH,2Dh
						JE		INT_21H_2DH_SET_TIME
						CMP		AH,30H
						JE		INT_21H_30H_GET_DOS_VERSION
						CMP		AH,34H
						JE		INT_21H_34H_GET_INDOS
						CMP		AH,35H
						JE		INT_21H_35H_GET_INTVEC
						CMP		AH,37H
						JE		INT_21H_37H_SLASH_DEV_PREFIX_USE
						CMP		AH,38H
						JE		INT_21H_38H_GET_COUNTRY_INFO
						CMP		AH,48H
						JE		INT_21H_48H_MALLOC
						CMP		AH,49H
						JE		INT_21H_49H_FREE
						CMP		AH,4AH
						JE		INT_21H_4AH_MREALLOC
						CMP		AH,4Dh
						JE		INT_21H_4DH_GET_RETURNCODE
						CMP		AH,50H
						JE		INT_21H_50H_SET_PSP
						CMP		AH,51H
						JE		INT_21H_51H_GET_PSP
						CMP		AH,52H
						JE		INT_21H_52H_GET_SYSVARS
						CMP		AH,58H
						JE		INT_21H_58H_GET_SET_MALLOC_STRATEGY
						CMP		AH,59H
						JE		INT_21H_59H_GET_EXTENDED_ERROR_INFO
						CMP		AH,5Dh
						JE		INT_21H_5DH_INTERNAL
						CMP		AH,5Fh
						JE		INT_21H_5FH_INT_2FH_TUNNEL
						CMP		AH,62H
						JE		INT_21H_62H_GET_PSP
						CMP		AH,63H
						JE		INT_21H_63H_GET_KANJI_LEAD_BYTE
						CMP		AH,65H
						JE		INT_21H_65H_GET_EXT_COUNTRYINFO
						CMP		AH,71H
						JE		INT_21H_71H_LONG_FILENAME_FUNCTIONS
						CMP		AH,0F8H
						JE		INT_21H_F8H_SET_OEM_FUNCTION
						JA		INT_21H_F9H_TO_FFH_CALL_OEM_FUNCTION
						; These are the simple functions. <<



; Not-so-simple Functions >>
; Save registers for the functions that may re-enter from the device-driver.
						SAVE_REGISTERS
						CMP		BYTE PTR CS:[INDOS],0
						JNE		INT_21H_REGISTERS_SAVED

						PUSH	CS
						POP		SS
						MOV		SP,OFFSET YSDOS_STACK
INT_21H_REGISTERS_SAVED:
						INC		BYTE PTR CS:[INDOS]

						CMP		AH,00H
						JE		INT_21H_00H_LEGACY_EXIT_PROCESS
						CMP		AH,02H
						JE		INT_21H_02H_PUTC
						CMP		AH,06H
						JE		INT_21H_06H_DIRECT_CONOUT
						CMP		AH,09H
						JE		INT_21H_09H_PUTS
						CMP		AH,0AH
						JE		INT_21H_0AH_GETS
						CMP		AH,0BH
						JE		INT_21H_0BH_KBHIT
						CMP		AH,0DH
						JE		INT_21H_0DH_FLUSH_BUFFERS
						CMP		AH,0EH
						JE		INT_21H_0EH_SET_CURRENT_DRIVE

						CMP		AH,0FH
						JE		INT_21H_10H_TO_17H_FCB
						CMP		AH,10H
						JE		INT_21H_10H_TO_17H_FCB
						CMP		AH,11H
						JE		INT_21H_10H_TO_17H_FCB
						CMP		AH,12H
						JE		INT_21H_10H_TO_17H_FCB
						CMP		AH,13H
						JE		INT_21H_10H_TO_17H_FCB
						CMP		AH,14H
						JE		INT_21H_10H_TO_17H_FCB
						CMP		AH,15H
						JE		INT_21H_10H_TO_17H_FCB
						CMP		AH,16H
						JE		INT_21H_10H_TO_17H_FCB
						CMP		AH,17H
						JE		INT_21H_10H_TO_17H_FCB

						CMP		AH,1CH
						JE		INT_21H_1CH_GET_DISK_ALLOC_INFO
						CMP		AH,29H
						JE		INT_21H_29H_PARSE_FILENAME_INTO_FCB
						CMP		AH,31H
						JE		INT_21H_31H_EXIT_AND_STAY_RESIDENT
						CMP		AH,36H
						JE		INT_21H_36H_GET_FREE_DISK_SPACE
						CMP		AH,39H
						JE		INT_21H_39H_MKDIR
						CMP		AH,3AH
						JE		INT_21H_3AH_RMDIR
						CMP		AH,3BH
						JE		INT_21H_3BH_CHDIR
						CMP		AH,3CH
						JE		INT_21H_3CH_FCREATE
						CMP		AH,3DH
						JE		INT_21H_3DH_FOPEN
						CMP		AH,3EH
						JE		INT_21H_3EH_FCLOSE
						CMP		AH,3FH
						JE		INT_21H_3FH_FREAD
						CMP		AH,40H
						JE		INT_21H_40H_FWRITE
						CMP		AH,41h
						JE		INT_21H_41H_FDELETE
						CMP		AH,42h
						JE		INT_21H_42H_FSEEK
						CMP		AH,43h
						JE		INT_21H_43H_SET_GET_FILE_ATTRIB
						CMP		AH,44H
						JE		INT_21H_44H_IOCTL
						CMP		AH,45H
						JE		INT_21H_45H_DUPLICATE_FILE_HANDLE
						CMP		AH,46H
						JE		INT_21H_46H_FORCE_DUPLICATE_FILE_HANDLE
						CMP		AH,47H
						JE		INT_21H_47H_GETCWD
						CMP		AH,4BH
						JE		INT_21H_4BH_EXEC_OR_LOAD
						CMP		AH,4CH
						JE		INT_21H_4CH_EXIT_PROCESS
						CMP		AH,4Eh
						JE		INT_21H_4EH_FIND_FIRST
						CMP		AH,4Fh
						JE		INT_21H_4FH_FIND_NEXT
						CMP		AH,55H
						JE		INT_21H_55H_CREATE_CHILD_PSP
						CMP		AH,57H
						JE		INT_21H_57H_SET_GET_TIME_STAMP
						CMP		AH,5BH
						JE		INT_21H_5BH_CREATE_BUT_NOT_TRUNCATE_FILE
						CMP		AH,60h
						JE		INT_21H_60H_TRUENAME
						CMP		AH,68h
						JE		INT_21H_68H_FFLUSH

; Not-so-simple Functions <<


INT_21H_NOTYET:
						DEC		BYTE PTR CS:[INDOS]
						RESTORE_REGISTERS

;	TSUGARU_DEBUG_BREAK 0

						JMP		ORIGINAL_INT_21H_COMMAND



INT_RESTORE_AND_IRET:
						DEC		BYTE PTR CS:[INDOS]

						JNS		INT_RESTORE_AND_IRET_GOOD
						TSUGARU_DEBUG_BREAK	YSDOS_REENTER_COUNT_IS_NEGATIVE
INT_RESTORE_AND_IRET_GOOD:

						RESTORE_REGISTERS
						IRET



INT_RESTORE_AND_IRET_WITH_CF:
						DEC		BYTE PTR CS:[INDOS]	; DEC won't change CF.

						JNS		INT_RESTORE_AND_IRET_WITH_CF_GOOD
						TSUGARU_DEBUG_BREAK	YSDOS_REENTER_COUNT_IS_NEGATIVE
INT_RESTORE_AND_IRET_WITH_CF_GOOD:

						RESTORE_REGISTERS
						CALL	SET_CF_BEFORE_IRET
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=00H Legacy Exit Process
INT_21H_00H_LEGACY_EXIT_PROCESS:
						XOR		AL,AL	; Return code is always zero.
						MOV		DS,CS:[INT21H_CALLER_CS]
						JMP		EXIT_PROCESS_WITH_RETURNCODE



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_02H_PUTC:
						MOV		AL,DL
						CALL	PUTC
						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; I don't know what to do if AL=0FFh
INT_21H_06H_DIRECT_CONOUT:
						MOV		AL,DL
						CMP		AL,0FFh
						JE		INT_RESTORE_AND_IRET	; I don't know what to do.
						CALL	PUTC
						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_09H_PUTS:
						MOV		SI,DX
						CALL	PUTS
						JMP		INT_RESTORE_AND_IRET




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_0AH_GETS:
						MOV		SI,DX
						CALL	GETS
						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
; 00h Buffer empty
; 0FFh At least one letter in the buffer.
INT_21H_0BH_KBHIT:
						CALL	KBHIT
						MOV		AH,0Bh ; Recover AH

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_0DH_FLUSH_BUFFERS:
						CALL	FLUSH_BUFFERS
						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DL Drive
; Output
;   CF=0 Success
;   CF=1 Drive not available
;   AL=NUM CDS
INT_21H_0EH_SET_CURRENT_DRIVE:
						MOV		AL,DL
						PUSH	AX
						CALL	IS_DRIVE_AVAILABLE
						STORE_LASTERR_IF_CF	DOSERR_INVALID_DRIVE
						POP		AX

						OR		BH,BH
						STC
						JNE		INT_21H_0EH_SET_CURRENT_DRIVE_EXIT
						MOV		CS:[CURRENT_DRIVE],AL

						; Do I need to update CURRENT_CDS?
						MOV		AH,CURRENT_DIR_STRUCT_size
						MUL		AH
						ADD		AX,WORD PTR CS:[FIRST_CDS_PTR]
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],AX
						MOV		AX,WORD PTR CS:[FIRST_CDS_SEG]
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT_SEG],AX

						CLC

INT_21H_0EH_SET_CURRENT_DRIVE_EXIT:
						MOV		AL,CS:[NUM_CDS]
						MOV		AH,0Eh  ; Recover AH


						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_10H_TO_17H_FCB:
						CALL	FCB_NOT_SUPPORTED

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						MOV		AX,0ffffh
						RETURN_REGISTERW	AX

						STORE_LASTERR_IF_CF	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_19H_GET_CURRENT_DRIVE:
						MOV		AL,CS:[CURRENT_DRIVE]
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:DX DTA Address
INT_21H_1AH_SET_DTA_ADDRESS:
						MOV		CS:[DMA_BUFFER_PTR],DX
						MOV		CS:[DMA_BUFFER_SEG],DS
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DL=FCB Drive
; Return
;   AL=Sectors per cluster or 0FFh if invalid drive
;   CX=Bytes per sector
;   DX=Total number of clusters
;   DS:BX=Points to CS:[MEDIA_DESC_BYTE(0530h)]
INT_21H_1CH_GET_DISK_ALLOC_INFO:
						MOV		AL,DL
						CALL	FCBDRIVE_TO_SANE_DRIVE
						JC		INT_RESTORE_AND_IRET

						CALL	GET_FREE_DISK_SPACE
						MOV		BX,OFFSET MEDIA_DESC_BYTE

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX
						RETURN_REGISTERW	DX
						RETURN_REGISTERW	BX
						MOV		SS:[BP+SAVED_DS],CS

						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=25H Set INT Vector
; Input
;   AL=INTNum
;   DS:DX=New INTVec
INT_21H_25H_SET_INTVEC:
						PUSH	ES
						PUSH	BX
						XOR		BX,BX
						MOV		ES,BX
						MOVZX	BX,AL
						SHL		BX,2
						STI
						MOV		ES:[BX],DX
						MOV		ES:[BX+2],DS
						POP		BX
						POP		ES
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_2AH_GET_DATE:
						PUSH	BX
						CALL	DEVCALL_READ_CLOCK
						CALL	DAYS_SINCE_1980_TO_YEAR_MONTH_DATE_DAY

						;   BX=Years since 1980
						;   CH=Month
						;   CL=Date
						;   DL=Day of week (0=Sun)

						MOV		AL,DL	; AL=Day of week
						MOV		DX,CX	; DX=Month/Date
						MOV		CX,BX
						ADD		CX,1980	; CX=Year

						POP		BX
						MOV		AH,2Ah ; Recover AH
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Tsugaru takes time from the host-computer's clock.
; Just ignore this call.
INT_21H_2BH_SET_DATE:
						XOR		AL,AL
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_2CH_GET_TIME:
						PUSH	AX
						CALL	DEVCALL_READ_CLOCK
						POP		AX
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Tsugaru takes time from the host-computer's clock.
; Just ignore this call.
INT_21H_2DH_SET_TIME:
						XOR		AL,AL
						IRET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=30H Get DOS Version
; Return:
;   AL  Major Version Number (Must be 3 or greater for SHSUCDX to work)
;   AH  Minor Version Number (Must be 30 or greater for SHSUCDX to work)
;   BL  High-Byte of User Serial (FM TOWNS's MSDOS.SYS returns 0)
;   CX  Low-Word of User Serial (FM TOWNS's MSDOS.SYS returns 0)
; No mention about CF.  Should I clear it?
INT_21H_30H_GET_DOS_VERSION:
						CMP		BYTE PTR CS:[STARTING_SHSUCDX],0
						JNE		INT_21H_30H_GET_DOS_VERSION_3_3

						MOV		AX,YSDOS_VERSION_WORD
						XOR		BL,BL
						XOR		CX,CX
						IRET

INT_21H_30H_GET_DOS_VERSION_3_3:
						MOV		AX,YSDOS_VERSION_WORD_SHSUCDX
						XOR		BL,BL
						XOR		CX,CX
						IRET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_34H_GET_INDOS:
						MOV		BX,OFFSET INDOS
						PUSH	CS
						POP		ES
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=35H Get INT Vector
; Input
;   AL=INTNum
; Return
;   ES:BX=INT Vec
INT_21H_35H_GET_INTVEC:
						PUSH	AX
						MOVZX	BX,AL
						XOR		AX,AX
						MOV		ES,AX
						SHL		BX,2
						LES		BX,ES:[BX]
						POP		AX
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_36H_GET_FREE_DISK_SPACE:
						MOV		AL,DL
						CALL	FCBDRIVE_TO_SANE_DRIVE
						STORE_LASTERR_IF_CF	AX
						JC		INT_RESTORE_AND_IRET

						CALL	GET_FREE_DISK_SPACE
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX
						RETURN_REGISTERW	BX
						RETURN_REGISTERW	CX
						RETURN_REGISTERW	DX
						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Get/Set "/DEV/" usage for CHARDEV.
; Always it is optional.  DL==Nonzero
; FM TOWNS IO.SYS expects it to be 02Fh.
; Let it be so.
INT_21H_37H_SLASH_DEV_PREFIX_USE:
						MOV		DL,02Fh
						XOR		AL,AL
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  DS:DX Buffer
;Fixed to Japan
INT_21H_38H_GET_COUNTRY_INFO:
						XCHG	BX,DX

						MOV		WORD PTR [BX+COUNTRY_DATEFOM],2
						MOV		DWORD PTR [BX+COUNTRY_CURRENCY],'\'
						MOV		BYTE PTR [BX+COUNTRY_CURRENCY+4],0
						MOV		WORD PTR [BX+COUNTRY_THOUSANDSEP],','
						MOV		WORD PTR [BX+COUNTRY_DECIMALSEP],'.'
						MOV		WORD PTR [BX+COUNTRY_DATESEP],'-'
						MOV		WORD PTR [BX+COUNTRY_TIMESEP],':'
						MOV		BYTE PTR [BX+COUNTRY_CURRENCYFOM],0
						MOV		BYTE PTR [BX+COUNTRY_CURRENCY_BELOWDECIMAL],0
						MOV		BYTE PTR [BX+COUNTRY_TIMEFOM],1
						MOV		WORD PTR [BX+COUNTRY_CASE_ROUTINE],OFFSET CASE_ROUTINE
						MOV		WORD PTR [BX+COUNTRY_CASE_ROUTINE+2],CS
						MOV		WORD PTR [BX+COUNTRY_DATASEP],','

						XCHG	BX,DX
						IRET

CASE_ROUTINE:			RETF




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_39H_MKDIR:
						MOV		SI,DX
						CALL	MKDIR

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_3AH_RMDIR:
						MOV		SI,DX
						CALL	RMDIR

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_3BH_CHDIR:
						MOV		SI,DX
						CALL	CHDIR

						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET
						



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=48H Malloc
; Input
;   BX  Number of pages requested
; Output
;   CF=0 -> AX=MCB of the new arena
;   CF=1 -> AX=Error Code  BX=Max available pages  Out of memory or broken MCB
INT_21H_48H_MALLOC:
						CLI
						CALL	MALLOC
						STORE_LASTERR_IF_CF	AX
						CALL	SET_CF_BEFORE_IRET
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=49H Free
; Input:
;   ES  Segment returned by MALLOC
; Output:
;   CF=0  Success
;   CF=1  Error  AX=DOSERR_INVALID_MCB(7)
; This function does not check if the arena is owned by the current PDB.
INT_21H_49H_FREE:
						CLI
						CALL	MFREE
						STORE_LASTERR_IF_CF	AX
						CALL	SET_CF_BEFORE_IRET
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=4AH MRealloc
; Input
;    BX=New size in number of paragraphs
;    ES=Segment (MCB+1) to resize
; Output
;    CF=0  Success  AX,BX unchanged.
;    CF=1  AX=error code  BX=maxinum number of paragraphs possible for resize
;          Error code can be one of:
;            DOSERR_MCB_BROKEN    (7)
;            DOSERR_OUT_OF_MEMORY (8)
;            DOSERR_INVALID_MCB   (9)
INT_21H_4AH_MREALLOC:
						CLI
						CALL	MREALLOC
						STORE_LASTERR_IF_CF	AX
						CALL	SET_CF_BEFORE_IRET
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
;   AH Return Type  0:Normal  1:Ctrl-C  2:Critical Error  3:Terminate and Stay Resident
;   AL ERRORLEVEL
;   CF=0
INT_21H_4DH_GET_RETURNCODE:
						MOV		AH,BYTE PTR CS:[TERMINATION_TYPE]
						MOV		AL,BYTE PTR CS:[ERRORLEVEL]
						CLC
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=52H Get SYSVARS
; Return:
;   ES  DOS Segment
;   BX  Offset to SYSVARS
; No mention about CF.  Should I clear it?
INT_21H_52H_GET_SYSVARS:
						MOV		BX,CS
						MOV		ES,BX
						MOV		BX,OFFSET SYSVARS
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=29H
;   AL=Parsing Options
; Input
;   AL Flags
;     01h  Skip Leading Separator and Spaces
;     02h  Don't clear FCB Drive Byte
;     04h  Don't clear FCB File Name field
;     08h  Don't clear FCB Extension field
;   DS:SI Filename
;   ES:DI FCB (First byte is drive, 11-bytes from the second byte is 11-byte format filename)
; Output
;   ES:DI Parsed FCB
;   DS:SI Next letter
;   AL=0 No wildcard
;   AL=1 With wildcard
;   AL=0FFh Error
INT_21H_29H_PARSE_FILENAME_INTO_FCB:
						CALL	PARSE_TO_FCB

						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX
						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=31H EXIT PROC AND STAY RESIDENT
;   AL=Returncode
;   DX=Number of Paragraphs to keep (Directly given to MREALLOC to resize PSP arena)
INT_21H_31H_EXIT_AND_STAY_RESIDENT:
						MOV		DS,CS:[CurrentPDB]
						JMP		EXIT_PROCESS_AND_STAY_RESIDENT



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=3CH FCREATE
;   AL=Open Mode
;   CL=File Attribute
;   DS:DX  Filename in C-String
; Return
;   CF=0  Successful  AX=File Handle (JFN  What does 'J' stand for?)
;   CF=1  AX=Error Code
INT_21H_3CH_FCREATE:
						MOV		SI,DX
						CALL	FCREATE

						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=3DH FOPEN
;   AL=Open Mode
;   DS:DX  Filename in C-String
; Return
;   CF=0  Successful  AX=File Handle (JFN  What does 'J' stand for?)
;   CF=1  AX=Error Code
INT_21H_3DH_FOPEN:
						MOV		SI,DX
						CALL	FOPEN

						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; AH=3EH FCLOSE
; Return:
;   CF=0  Successful
;   CF=1  AX=Error Code
INT_21H_3EH_FCLOSE:
						MOV		AX,BX
						CALL	FCLOSE
						STORE_LASTERR_IF_CF	AX
						JNC		INT_RESTORE_AND_IRET_WITH_CF

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF
INT_21H_COMMAND			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AH=3FH FREAD
;   BX=JFN
;   CX=Bytes to Read
;   DS:DX Read buffer
; Return
;   CF=0 AX=Number of bytes read
;   CF=1 AX=Error Code
INT_21H_3FH_FREAD:
						MOV		AX,BX
						ROL		EDX,16
						MOV		DX,DS
						ROL		EDX,16
						MOVZX	ECX,CX	; INT 21H Don't Read more than 64KB at a time.
						CALL	FREAD_FROM_JFN
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP

						JC		INT_21H_3FH_FREAD_AX_CX
						MOV		AX,CX
INT_21H_3FH_FREAD_AX_CX:
						RETURN_REGISTERW	AX
						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AH=40H FWRITE
;   BX=JFN
;   CX=Bytes to Write
;   DS:DX Data Pointer
; Return
;   CF=0 AX=Number of bytes written
;   CF=1 AX=Error Code
INT_21H_40H_FWRITE:
						MOV		AX,BX
						ROL		EDX,16
						MOV		DX,DS
						ROL		EDX,16
						; CX is CX;
						CALL	FWRITE_TO_JFN
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP

						JC		INT_21H_40H_FWRITE_AX_CX
						MOV		AX,CX
INT_21H_40H_FWRITE_AX_CX:
						RETURN_REGISTERW	AX
						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:DX=C-String Filename
INT_21H_41H_FDELETE:
						MOV		SI,DX
						CALL	FDELETE
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP

						RETURN_REGISTERW	AX
						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL=mode (0:SEEK_SET 1:SEEK_CUR 2:SEEK_END)
;   BX=File Handle
;   CX:DX=Offset to move
INT_21H_42H_FSEEK:
						XCHG	BX,AX
						ROL		EDX,16
						MOV		DX,CX
						ROL		EDX,16
						CALL	FSEEK_BY_HANDLE
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP

						JC		INT_21H_42H_FSEEK_JC
						; JNC means no error.  DX:AX must be new position.  Now EDX is new position
						MOV		EAX,EDX
						SHLD	EDX,EAX,16
						CLC
						RETURN_REGISTERW	DX
INT_21H_42H_FSEEK_JC:
						RETURN_REGISTERW	AX
						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL=0  Get File Attribute
;   AL=1,CX=Attrib  Set File Attribute
;   DS:DX=C-String Filename
; Output
;   CF=0 AL=0 -> CX=File Attribute
;   CF=1 AX=DOS Error Code
INT_21H_43H_SET_GET_FILE_ATTRIB:
						CMP		AL,0
						JE		INT_21H_43H_GET_FILE_ATTRIB
						CMP		AL,1
						JE		INT_21H_43H_SET_FILE_ATTRIB
						STC
						; MOV		CS:[ERROR_LOCUS],ERRLOCUS_UNKNOWN

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP

						MOV		AX,DOSERR_INVALID_FUNC
						RETURN_REGISTERW	AX
						JMP		INT_RESTORE_AND_IRET_WITH_CF

INT_21H_43H_GET_FILE_ATTRIB:
						MOV		SI,DX
						CALL	GET_FILE_ATTRIB
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX
						RETURN_REGISTERW	CX

						JMP		INT_RESTORE_AND_IRET_WITH_CF

INT_21H_43H_SET_FILE_ATTRIB:
						MOV		SI,DX
						CALL	SET_FILE_ATTRIB
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL=Sub Command
;   AL=1 -> IOCTL_GET_DEVINFO  BX=File Handle (JFN)
;   AL=2 -> IOCTL_SET_DEVINFO  BX=File Handle (JFN)  DX=Devinfo.  DH must be zero.  DL is Lobyte of SF_DEVFLAGS
;   AL=3 -> ILCTL_READ_CHARDEV BX=File Handle (JFN)  CX=Number of bytes  DS:DX=Data Buffer
INT_21H_44H_IOCTL:
						XCHG	AX,BX
						CALL	IOCTL
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX
						RETURN_REGISTERW	DX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   BX=File Handle
INT_21H_45H_DUPLICATE_FILE_HANDLE:
						MOV		AX,BX
						CALL	DUPLICATE_FILE_HANDLE
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_46H_FORCE_DUPLICATE_FILE_HANDLE:
						MOV		AX,BX
						CALL	FORCE_DUPLICATE_FILE_HANDLE
						STORE_LASTERR_IF_CF	AX
						JNC		INT_RESTORE_AND_IRET_WITH_CF

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DL=Drive Letter
;   DS:SI=Buffer to receive CWD
; Output
;   DS:SI populated with CWD without drive letter, colon, and the first backslash.
INT_21H_47H_GETCWD:
						CALL	GETCWD
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL=0:Load and Exec  1:Load but Don't Exec  3:Load Overlay (DEVICE=)
;   DS:DX=C-String Filename
;   ES:BX=Exec Param Block
; Output
;   If Exec Succeeds -> Don't return
;   Else:
;     CF=0  Successfully loaded
;     CF=1  Error Code
INT_21H_4BH_EXEC_OR_LOAD:
						MOV		SI,DX		; Make DS:SI Filename
						MOV		DI,BX		; Make ES:DI Parameter Block
						CALL	EXEC_OR_LOAD_PROC
						STORE_LASTERR_IF_CF	AX
						JNC		INT_21H_4BH_EXEC_OR_LOAD_EXIT

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

INT_21H_4BH_EXEC_OR_LOAD_EXIT:
						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL=Returncode
INT_21H_4CH_EXIT_PROCESS:
						MOV		DS,CS:[CurrentPDB]
						JMP		EXIT_PROCESS_WITH_RETURNCODE



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL=Special Flag?
;   CX=Attrib Filter (eg. 08h and A:\*.* will return Volume Label)
;   DS:DX=Search Template C-String
INT_21H_4EH_FIND_FIRST:
						MOV		SI,DX
						CALL	FIND_FIRST
						STORE_LASTERR_IF_CF	AX

						JNC		INT_RESTORE_AND_IRET_WITH_CF

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DTA Area=FINDSTRUCT returned by FindFirst or preceding FindNext
; Output
;   Updated FINDSTRUCT
INT_21H_4FH_FIND_NEXT:
						CALL	FIND_NEXT
						JNC		INT_RESTORE_AND_IRET_WITH_CF
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;
INT_21H_50H_SET_PSP:
						MOV		CS:[CurrentPDB],BX
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_51H_GET_PSP:
						MOV		BX,CS:[CurrentPDB]
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DX=New PSP for CHild Process
;   SI=Value to stored in ENDMEM (DX:[PSP_ENDMEM])
INT_21H_55H_CREATE_CHILD_PSP:
						CALL	CREATE_PDB	; PDB or PSP!?  WTF!?
						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   BX=File Handle
INT_21H_57H_SET_GET_TIME_STAMP:
						CMP		AL,0
						JE		INT_21H_57H_GET_TIME_STAMP
						CMP		AL,1
						JE		INT_21H_57H_SET_TIME_STAMP
						; MOV		CS:[ERROR_LOCUS],ERRLOCUS_UNKNOWN

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP

						MOV		AX,DOSERR_INVALID_FUNC
						RETURN_REGISTERW	AX
						JMP		INT_RESTORE_AND_IRET_WITH_CF

INT_21H_57H_GET_TIME_STAMP:
						MOV		AX,BX
						CALL	GET_FILE_TIME_STAMP
						STORE_LASTERR_IF_CF	AX

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX
						RETURN_REGISTERW	CX
						RETURN_REGISTERW	DX

						JMP		INT_RESTORE_AND_IRET_WITH_CF

INT_21H_57H_SET_TIME_STAMP:
						MOV		SI,DX
						CALL	SET_FILE_TIME_STAMP
						STORE_LASTERR_IF_CF	AX
						JNC		INT_RESTORE_AND_IRET_WITH_CF

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_5BH_CREATE_BUT_NOT_TRUNCATE_FILE:
						MOV		SI,DX
						CALL	FCREATE_IF_NOT_EXIST

						_LSS	SP,CS:[SP_RESTORE_POINT]
						MOV		BP,SP
						RETURN_REGISTERW	AX

						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL=0  Get MALLOC Strategy   ->  Return AX=Current Strategy
;   AL=1  Set MALLOC Strategy, BX=New MALLOC Strategy
;   AL=2  Mystery
;   AL=3  Something to do with UMB
INT_21H_58H_GET_SET_MALLOC_STRATEGY:
						PUSH	BP
						; BP+6 FLAGS
						; BP+4 CS
						; BP+2 IP
						; BP   BP
						MOV		BP,SP
						AND		BYTE PTR [BP+6],0FEh

						OR		AL,AL
						JE		INT_21H_58H_GET_MALLOC_STRATEGY
						DEC		AL
						JE		INT_21H_58H_SET_MALLOC_STRATEGY

						OR		BYTE PTR [BP+6],1
						MOV		AX,DOSERR_INVALID_FUNC
						POP		BP
						IRET

INT_21H_58H_GET_MALLOC_STRATEGY:
						MOVZX	AX,BYTE PTR CS:[MALLOC_STRATEGY]
						POP		BP
						IRET

INT_21H_58H_SET_MALLOC_STRATEGY:
						MOV		CS:[MALLOC_STRATEGY],BL
						AND		BYTE PTR [BP+6],0FEh
						MOV		AL,1	; Restore AL
						POP		BP
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_59H_GET_EXTENDED_ERROR_INFO:
						MOV		AX,CS:[EXTENDED_ERROR_CODE]
						MOV		BH,CS:[ERROR_CLASS]
						MOV		BL,CS:[ERROR_RECOMMENDED_ACTION]
						MOV		CH,CS:[ERROR_LOCUS]
						CMP		AX,DOSERR_INVALID_DISK_CHANGE
						JNE		INT_21H_59H_EXIT
						LES		DI,CS:[PREVIOUS_DISK_LABEL]
INT_21H_59H_EXIT:
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; This INT is supposed to be internal use only.
; Or, AL=07,08,09
; can be used for redirected printer mode.
; Or, AL=0Ah
; can be used for setting extended error information.
; according to http://www.ctyme.com/intr/int-21.htm.
; If it is redirected-printer mode, just ignore.
; If not, trap it so that I know the function is actually used.
INT_21H_5DH_INTERNAL:
						CMP		AL,7
						JE		INT_21H_5DH_IGNORE
						CMP		AL,8
						JE		INT_21H_5DH_IGNORE
						CMP		AL,9
						JE		INT_21H_5DH_IGNORE
INT_21H_5DH_STOP:		JMP		INT_21H_5DH_STOP

INT_21H_5DH_IGNORE:		IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_5FH_INT_2FH_TUNNEL:
						PUSH	AX	; Function in the Stack.
						MOV		AX,INT2FH_TUNNEL_FROM_21H
						INT		2FH

						PUSH	BP
						MOV		BP,SP
						; [BP]    BP
						; [BP+2]  AX
						; [BP+4]  IP
						; [BP+6]  CS
						; [BP+8]  FLAGS
						JNC		INT_21H_5FH_INT_2FH_TUNNEL_NOERR
						OR		WORD PTR [BP+8],1				; Return CF
						POP		BP
						ADD		SP,2
						IRET

INT_21H_5FH_INT_2FH_TUNNEL_NOERR:
						AND		WORD PTR [BP+8],0fffeh			; Return CF
						POP		BP
						ADD		SP,2
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_60H_TRUENAME:
						CALL	TRUENAME
						STORE_LASTERR_IF_CF	AX
						JMP		INT_RESTORE_AND_IRET_WITH_CF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;
INT_21H_62H_GET_PSP:
						MOV		BX,CS:[CurrentPDB]
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



LEADBYTERANGE			DB	081h,0ffh,0,0

INT_21H_63H_GET_KANJI_LEAD_BYTE:
						PUSH	BP
						; BP+6 FLAGS
						; BP+4 CS
						; BP+2 IP
						; BP   BP
						MOV		BP,SP
						AND		BYTE PTR [BP+6],0FEh
						MOV		AX,7100h
						POP		BP

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET LEADBYTERANGE

						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_65H_GET_EXT_COUNTRYINFO:
						PUSH	BP
						MOV		BP,SP
						; [BP]    BP
						; [BP+2]  AX
						; [BP+4]  IP
						; [BP+6]  CS
						; [BP+8]  FLAGS
						OR		WORD PTR [BP+8],1				; Return CF
						POP		BP
						MOV		AX,DOSERR_INVALID_FUNC
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Unsupported.  Return CF=0 and AX=7100h
INT_21H_71H_LONG_FILENAME_FUNCTIONS:
						PUSH	BP
						; BP+6 FLAGS
						; BP+4 CS
						; BP+2 IP
						; BP   BP
						MOV		BP,SP
						AND		BYTE PTR [BP+6],0FEh
						MOV		AX,7100h
						POP		BP
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_68H_FFLUSH:
						CALL	FLUSH_BUFFERS
						JMP		INT_RESTORE_AND_IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_F8H_SET_OEM_FUNCTION:
						MOV		WORD PTR CS:[OEM_INT_21H_HANDLER],DX
						MOV		WORD PTR CS:[OEM_INT_21H_HANDLER+2],DS
						IRET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



INT_21H_F9H_TO_FFH_CALL_OEM_FUNCTION:
						CMP		WORD PTR CS:[OEM_INT_21H_HANDLER],0ffffh
						JE		INT_21H_F9H_TO_FFH_NONE

;						JMP		FAR [CS:OEM_INT_21H_HANDLER]		; --USE_IN_NASM--
						JMP		DWORD PTR CS:[OEM_INT_21H_HANDLER]	; --NOT_IN_NASM--

INT_21H_F9H_TO_FFH_NONE:
						XOR		AL,AL
						IRET



