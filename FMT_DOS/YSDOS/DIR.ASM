DIR_CLUSTER0				DD		0	; First cluster of the directory.
DIR_CURRENT_CLUSTER			DD		0
DIR_CURRENT_SECTOR			DD		0
DIR_SECTORS_INTO_CLUSTER	DW		0
DIR_BYTES_INTO_SECTOR		DW		0
DIR_COUNT_IN_DIRECTORY		DW		0
DIR_DIRENT_PTR				DD		0	; Last found DIRENT
DIR_SKIP_COUNTER			DW		0



; Input
;   GS:BP  DPB
;   DS:SI  Starting pointer in the fully-qualified file name.
;          If the file name is:
;            C:\COMMAND.COM
;               ^SI must point this.
;   EAX    Starting cluster (0->Root Dir)
;   CX     Attribute Filter, High-Byte ignored.
; Return
;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
;   Lastly scanned directory cluster can be found in DIR_variables
; Don't expect registers are preserved.
;
;If DS:SI is a directory name, and if it matches an entry in the directory,
;it still returns CF=0.  If the caller function is expecting a file name,
;the caller should check the attribute in AL or DIRENT in ES:DI to see
;what is found is a file or a directory.  This function will ignore Volume Label.
;
;If the path is ending with backslash, and path exists, for example, "C:\ABC\XYZ\"
;   CS:[DIR_CLUSTER0]=CS:[DIR_CURRENT_CLUSTER]=First Cluster of Directory "C:\ABC\XYZ\"
;   CS:[DIR_SECTORS_INTO_CLUSTER],CS:[BYTES_INTO_SECTOR]=0.
;   The return error code will be DOSERR_FILE_NOT_FOUND
;IF the path is not ending with backslash, for example, "C:\ABC\XYZ"
;   CS:[DIR_CLUSTER0]=First Cluster of "C:\ABC"
;   CS:[DIR_CURRENT_CLUSTER],CS:[DIR_SECTORS_INTO_CLUSTER],CS:[DIR_BYTES_INTO_SECTOR]=The where DIRENT of "XYZ" is written
;
;
;There are a couple of conclusions
;(1) Didn't find a middle path -> DOSERR_DIR_NOT_FOUND
;(2) Got to the last backslash, but did not find the file name. -> DOSERR_FILE_NOT_FOUND
;(3) Found the file name -> DOSERR_NO_ERROR
;
;	cluster0=AX
;	for(;;)
;	{
;		ExtractNextSegmentIn11ByteBuffer
;		if(Empty)
;		{
;			return DOSERR_FILE_NOT_FOUND;
;		}
;		if(0==cluster0)
;		{
;			foundCluster,foundSector,foundPointer=SearchInRootDir
;		}
;		else
;		{
;			foundCluster,foundSector,foundPointer=SearchInClusterChain
;		}
;		if(found)
;		{
;			if(Is the last segment)
;			{
;				return DOSERR_NO_ERROR
;			}
;			else
;			{
;				if(what's found is a directory)
;				{
;					Update cluster0
;				}
;				else
;				{
;					return DIR_NOT_FOUND
;				}
;			}
;		}
;		else
;		{
;			if(Is the last segment)
;			{
;				return DOSERR_FILE_NOT_FOUND
;			}
;			else
;			{
;				return DOSERR_DIR_NOT_FOUND
;			}
;		}
;	}
FETCH_DIR:
						MOV		CS:[SATTR],CL

FETCH_DIR_LOOP:
						MOV		CS:[DIR_CLUSTER0],EAX
						MOV		CS:[DIR_CURRENT_CLUSTER],EAX
						MOV		WORD PTR CS:[DIR_SKIP_COUNTER],0

						CMP		BYTE PTR DS:[SI],0	; Filename Empty
						JE		FETCH_FILE_NOT_FOUND_FINAL

						PUSH	DS
						PUSH	SI

						MOV		DI,OFFSET TEMPORARY_DIRENT
						PUSH	CS
						POP		ES
						CALL	MAKE_11BYTE_FILENAME

						MOV		WORD PTR CS:[DIR_COUNT_IN_DIRECTORY],0 ; Will be zero-ed in SCAN_DIR_*, but just in case.

						MOV		EAX,CS:[DIR_CLUSTER0]
						OR		EAX,EAX
						JNE		FETCH_DIR_NOT_ROOT
;FETCH_DIR_ROOT:
						CALL	SCAN_DIR_ROOT
						JC		FETCH_DIR_NOT_FOUND
						JMP		FETCH_DIR_FOUND
FETCH_DIR_NOT_ROOT:
						CALL	SCAN_DIR_NOT_ROOT
						JC		FETCH_DIR_NOT_FOUND
FETCH_DIR_FOUND:
						; DS:SI is the sector buffer header
						PUSH	DS
						POP		ES
						MOV		DI,SI ; -> Now ES:DI is the sector buffer header
						MOV		BX,SI ; -> ES:BX is also sector buffer
						ADD		DI,IO_BUF_INFO_size
						ADD		DI,CS:[DIR_BYTES_INTO_SECTOR]

						POP		SI
						POP		DS

						CALL	SEEK_NEXT_BACKSLASH
						; DS:SI points to one after backslash or last zero.
						; AL is backslash or zero.
						OR		AL,AL
						MOVZX	AX,BYTE PTR ES:[DI+DIRENT_ATTR]
						JE		FETCH_DIR_FOUND_FINAL

						TEST	AX,DIRENT_ATTR_DIRECTORY
						JE		FETCH_DIR_NOT_FOUND_FINAL

						MOVZX	EAX,WORD PTR ES:[DI+DIRENT_FIRST_CLUSTER]
						MOV		CS:[DIR_CLUSTER0],EAX

						JMP		FETCH_DIR_LOOP


FETCH_DIR_NOT_FOUND:
						POP		SI	; Sector buffer doesn't matter
						POP		DS

						CALL	SEEK_NEXT_BACKSLASH
						; DS:SI points to one after backslash or last zero.
						; AL is backslash or zero.
						OR		AL,AL
						JE		FETCH_FILE_NOT_FOUND_FINAL
						JMP		FETCH_DIR_NOT_FOUND_FINAL


						; Result is one of the three.
FETCH_DIR_FOUND_FINAL:
						CLC
						RET

FETCH_DIR_NOT_FOUND_FINAL:
						MOV		AX,DOSERR_DIR_NOT_FOUND
						STC
						RET

FETCH_FILE_NOT_FOUND_FINAL:
						; FIND_FIRST needs to return DOSERR_NO_MORE_FILES if it searches for a volume label, and didn't find one.
						; I don't know when to return DOSERR_FILE_NOT_FOUND.
						MOV		AX,DOSERR_NO_MORE_FILES
						STC
						RET



; Input
;   GS:BP  DPB
;   Set:
;   CS:[TEMPORARY_DIRENT]  11-byte file/dir name
;   CS:[SATTR]
; Return
;   CF=0  Found
;   CF=1  Not Found   AX DOS Error Code
;   DS:SI  Last-read sector buffer header
;   Set:
;   DIR_CURRENT_CLUSTER
;   DIR_SECTORS_INTO_CLUSTER
;   DIR_BYTES_INTO_SECTOR
; Don't expect registers are preserved.
SCAN_DIR_ROOT:
						XOR		EAX,EAX
						MOV		CS:[DIR_CURRENT_CLUSTER],EAX
						MOV		CS:[DIR_CLUSTER0],EAX
						MOV		CS:[DIR_SECTORS_INTO_CLUSTER],AX
						MOV		CS:[DIR_BYTES_INTO_SECTOR],AX
						MOV		CS:[DIR_COUNT_IN_DIRECTORY],AX

						PUSH	CS
						POP		ES

SCAN_DIR_ROOT_SECTOR_LOOP:
						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						MOV		DX,GS:[BP+DPB_FIRST_DIR_SECTOR]
						ADD		DX,CS:[DIR_SECTORS_INTO_CLUSTER]
						CMP		DX,GS:[BP+DPB_FIRST_DATA_SECTOR]
						MOV		AX,DOSERR_FILE_NOT_FOUND
						JAE		SCAN_DIR_ROOT_ERROR

						XOR		AL,AL
						MOVZX	EDX,DX
						MOV		CS:[DIR_CURRENT_SECTOR],EDX
						CALL	GETBUFFER_REGULAR
						MOV		SI,DI ; Agh! Why did I make GETBUFFER_REGULAR return DS:DI while all other funcs return DS:SI!?
						MOV		AX,DOSERR_ACCESS_DENIED
						JC		SCAN_DIR_ROOT_ERROR

						OR		BYTE PTR DS:[SI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_DIR

						MOV		CX,GS:[BP+DPB_BYTES_PER_SECTOR]
						SHR		CX,DIRENT_SHIFT

						MOV		WORD PTR CS:[DIR_BYTES_INTO_SECTOR],0

SCAN_DIR_ROOT_DIRENT_LOOP:
						PUSH	CX
						PUSH	SI

						CMP		WORD PTR CS:[DIR_SKIP_COUNTER],0
						JE		SCAN_DIR_ROOT_NO_SKIP
						DEC		WORD PTR CS:[DIR_SKIP_COUNTER]
						JMP		SCAN_DIR_ROOT_DIRENT_NEXT
SCAN_DIR_ROOT_NO_SKIP:

						MOV		DI,OFFSET TEMPORARY_DIRENT

						ADD		SI,IO_BUF_INFO_size+DIRENT_FILENAME
						ADD		SI,CS:[DIR_BYTES_INTO_SECTOR]

						MOV		AL,BYTE PTR DS:[SI+DIRENT_ATTR]
						CALL	SCAN_DIR_MATCH_ATTR
						JC		SCAN_DIR_ROOT_DIRENT_NEXT

						MOV		WORD PTR CS:[DIR_DIRENT_PTR],SI
						MOV		WORD PTR CS:[DIR_DIRENT_PTR+2],DS
						CALL	COMPARE_LESSER_WILDCARD11
						JE		SCAN_DIR_ROOT_FOUND

SCAN_DIR_ROOT_DIRENT_NEXT:
						POP		SI
						POP		CX
						INC		WORD PTR CS:[DIR_COUNT_IN_DIRECTORY]
						ADD		WORD PTR CS:[DIR_BYTES_INTO_SECTOR],DIRECTORY_ENTRY_size
						LOOP	SCAN_DIR_ROOT_DIRENT_LOOP

						INC		WORD PTR CS:[DIR_SECTORS_INTO_CLUSTER]
						JMP		SCAN_DIR_ROOT_SECTOR_LOOP

SCAN_DIR_ROOT_FOUND:
						POP		SI
						POP		CX
						CLC
						RET

SCAN_DIR_ROOT_ERROR:
						STC
						RET



; Input
;   GS:BP  DPB
;   Set:
;   CS:[DIR_CLUSTER0]
;   CS:[TEMPORARY_DIRENT]  11-byte file/dir name
;   CS:[SATTR]
; Return
;   CF=0  Found
;   CF=1  Not Found   AX DOS Error Code
;   DS:SI  Last-read sector buffer header
;   Set:
;   DIR_CURRENT_CLUSTER
;   DIR_SECTORS_INTO_CLUSTER
;   DIR_BYTES_INTO_SECTOR
; Don't expect registers are preserved.
SCAN_DIR_NOT_ROOT:
						MOV		EAX,CS:[DIR_CLUSTER0]
						MOV		WORD PTR CS:[DIR_COUNT_IN_DIRECTORY],0

SCAN_DIR_NORT_CLST_LOOP:
						MOV		CS:[DIR_CURRENT_CLUSTER],EAX

						XOR		EDX,EDX
						MOV		CS:[DIR_SECTORS_INTO_CLUSTER],DX
						MOV		CS:[DIR_DIRENT_PTR],EDX

						MOV		EDX,CS:[DIR_CURRENT_CLUSTER]
						; Input
						;   GS:BP  Drive Parameter Block
						;   DX     Cluster
						CALL	CLUSTER_TO_SECTOR
						; Return
						;   EBX    First Sector of the cluster
						;   EAX,CL Destroyed
						MOV		CS:[DIR_CURRENT_SECTOR],EBX

SCAN_DIR_NORT_SECTOR_LOOP:
						MOV		EDX,CS:[DIR_CURRENT_SECTOR]
						XOR		AL,AL
						;   GS:BP  Drive Parameter Block
						;   DX     LBA
						;   AL     AL==0 Read sector
						CALL	GETBUFFER_REGULAR
						MOV		SI,DI
						JC		SCAN_DIR_NORT_ERROR

						OR		BYTE PTR DS:[SI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_DIR

						MOV		CX,GS:[BP+DPB_BYTES_PER_SECTOR]
						SHR		CX,DIRENT_SHIFT

						; DS:SI is the sector buffer
						MOV		WORD PTR CS:[DIR_BYTES_INTO_SECTOR],0
SCAN_DIR_NORT_DIRENT_LOOP:
						PUSH	CX
						PUSH	SI

						CMP		WORD PTR CS:[DIR_SKIP_COUNTER],0
						JE		SCAN_DIR_NORT_DONT_SKIP
						DEC		WORD PTR CS:[DIR_SKIP_COUNTER]
						JMP		SCAN_DIR_NORT_DIRENT_NEXT

SCAN_DIR_NORT_DONT_SKIP:
						ADD		SI,IO_BUF_INFO_size+DIRENT_FILENAME
						ADD		SI,CS:[DIR_BYTES_INTO_SECTOR]
						MOV		AL,DS:[SI+DIRENT_ATTR]
						CALL	SCAN_DIR_MATCH_ATTR
						JC		SCAN_DIR_NORT_DIRENT_NEXT

						PUSH	CS
						POP		ES
						MOV		DI,OFFSET TEMPORARY_DIRENT

						MOV		WORD PTR CS:[DIR_DIRENT_PTR],SI
						MOV		WORD PTR CS:[DIR_DIRENT_PTR+2],DS
						CALL	COMPARE_LESSER_WILDCARD11
						JE		SCAN_DIR_NOTROOT_FOUND

SCAN_DIR_NORT_DIRENT_NEXT:
						POP		SI
						POP		CX
						INC		WORD PTR CS:[DIR_COUNT_IN_DIRECTORY]
						ADD		WORD PTR CS:[DIR_BYTES_INTO_SECTOR],DIRECTORY_ENTRY_size
						LOOP	SCAN_DIR_NORT_DIRENT_LOOP

						INC		DWORD PTR CS:[DIR_CURRENT_SECTOR]
						INC		WORD PTR CS:[DIR_SECTORS_INTO_CLUSTER]
						MOVZX	CX,BYTE PTR GS:[BP+DPB_CLUSTER_MASK]
						AND		CX,CS:[DIR_SECTORS_INTO_CLUSTER]
						JNE		SCAN_DIR_NORT_SECTOR_LOOP


						MOV		EBX,CS:[DIR_CURRENT_CLUSTER]
						; Input
						;   GS:BP  Drive Parameter Block
						;   BX     Cluster
						CALL	GET_NEXT_CLUSTER
						; Output
						;   CF=0   DX=Next Cluster
						;   CF=1   DX Destroyed
						CMP		DX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JA		SCAN_DIR_NORT_ERROR ; Not Found

						MOVZX	EAX,DX
						JMP		SCAN_DIR_NORT_CLST_LOOP



SCAN_DIR_NOTROOT_FOUND:
						POP		SI
						POP		CX
						CLC
						RET

SCAN_DIR_NORT_ERROR:
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  DPB
;   Set:
;   CS:[DIR_CLUSTER0]
;   CS:[DIR_SKIP_COUNTER]
;   CS:[TEMPORARY_DIRENT]  11-byte file/dir name
; Return
;   CF=0  Found
;   CF=1  Not Found   AX DOS Error Code
;   DS:SI  Last-read sector buffer header
;   Set:
;   DIR_CURRENT_CLUSTER
;   DIR_SECTORS_INTO_CLUSTER
;   DIR_BYTES_INTO_SECTOR
; Don't expect registers are preserved.
SCAN_DIR:
						CMP		DWORD PTR CS:[DIR_CLUSTER0],0
						JNE		SCAN_DIR_JMP_TO_NOTROOT
;SCAN_DIR_JMP_TO_ROOT
						CALL	SCAN_DIR_ROOT
						RET

SCAN_DIR_JMP_TO_NOTROOT:
						CALL	SCAN_DIR_NOT_ROOT
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Match Attrib AL against CS:[SATTR]
; Return:
;  CF=0 Match
;  CF=1 Don't match
SCAN_DIR_MATCH_ATTR:
						TEST	BYTE PTR CS:[SATTR],DIRENT_ATTR_VOLLABEL

;SCAN_DIR_MATCH_ATTR_VOLLABEL:
						JE		SCAN_DIR_MATCH_ATTR_NOT_VOLLABEL
						TEST	AL,DIRENT_ATTR_VOLLABEL
						JNE		SCAN_DIR_MATCH_ATTR_YES
						JMP		SCAN_DIR_MATCH_ATTR_NO


SCAN_DIR_MATCH_ATTR_NOT_VOLLABEL:
						TEST	AL,DIRENT_ATTR_VOLLABEL
						JNE		SCAN_DIR_MATCH_ATTR_NO

						CMP		BYTE PTR CS:[SATTR],0
						JNE		SCAN_DIR_MATCH_ATTR_FILTERED
;SCAN_DIR_MATCH_ATTR_ALL_NORMAL:
						TEST	AL,DIRENT_ATTR_DIRECTORY+DIRENT_ATTR_SYSTEM
						JE		SCAN_DIR_MATCH_ATTR_YES
						JMP		SCAN_DIR_MATCH_ATTR_NO


SCAN_DIR_MATCH_ATTR_FILTERED:
						TEST	AL,CS:[SATTR]
						JNE		SCAN_DIR_MATCH_ATTR_YES
						TEST	AL,DIRENT_ATTR_DIRECTORY+DIRENT_ATTR_SYSTEM
						JE		SCAN_DIR_MATCH_ATTR_YES
						JMP		SCAN_DIR_MATCH_ATTR_NO


SCAN_DIR_MATCH_ATTR_YES:
						CLC
						RET
SCAN_DIR_MATCH_ATTR_NO:
						STC
						RET

; Logic is absurd.
; What constitutes a normal file?  Utterly absurd.
; Is this logic correct?
; if(SATTR&DIRENT_ATTR_VOLLABEL)
; {
; 	if(0==(DIRENT_ATTR&DIRENT_ATTR_VOLLABEL))
; 	{
; 		return CF=1;
; 	}
; 	return CF=0;
; }
; else
; {
; 	if(0!=(DIRENT_ATTR&DIRENT_ATTR_VOLLABEL)))
; 	{
; 		return CF=1;
; 	}
; 	if(SATTR==0)
; 	{
; 		if(0!=(DIRENT_ATTR&(DIRENT_ATTR_SYSTEM|DIRENT_ATTR_DIRECTORY))) // Is hidden file considered a normal file?
; 		{
; 			return CF=1;
; 		}
; 		return CF=0;
; 	}
; 	else
; 	{
; 		if(0!=(SATTR&DIRENT_ATTR)
; 		{
; 			return CF=0;  // Match
; 		}
; 		else if(0==(DIRENT_ATTR&(DIRENT_ATTR_SYSTEM|DIRENT_ATTR_DIRECTORY)))
; 		{
; 			return CF=0;  // Match
; 		}
; 		return CF=1;
; 	}
; }


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  DPB
;   EAX    First cluster of the directory
; Return
;   CF=0   Success.  DS:SI=DIRENT,  DS:BX=BUFFER HEADER
;   CF=1   Fail.
ALLOC_DIRENT:
						PUSH	EAX
						CALL	FIND_AVAIL_DIRENT
						JNC		ALLOC_DIRENT_FOUND
						POP		EAX
						OR		EAX,EAX
						STC
						JE		ALLOC_DIRENT_EXIT	; Root dir cannot be extended.
						; If fail, EDX is the cluster where new cluster should be added
						CALL	EXTEND_DIR
ALLOC_DIRENT_EXIT:
						RET

ALLOC_DIRENT_FOUND:
						POP		EAX
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



FIND_AVAIL_ROOT_DIRENT:



; Input
;   GS:BP  DPB
;   EAX    First cluster of the directory
; Return
;   CF=0   Success.  DS:SI=DIRENT,  DS:BX=BUFFER HEADER  ECX=Sector  EDX=Cluster
;   CF=1   Fail.  EDX is last checked cluster of the directory.
FIND_AVAIL_DIRENT:
						OR		EAX,EAX
						JE		FIND_AVAIL_DIRENT_ROOT

						MOV		EDX,EAX

FIND_AVAILDIR_CLST_LOOP:
						PUSH	EDX
						CALL	CLUSTER_TO_SECTOR
						; EBX is Sector
						XOR		AX,AX
						; AX is nTh sector

FIND_AVAILDIR_SECT_LOOP:
						PUSH	EBX	; SS:[SP] is the latest sector
						PUSH	AX

						MOV		EDX,EBX
						XOR		AL,AL	; Preread
						CALL	GETBUFFER_REGULAR
						JC		FIND_AVAIL_DIRENT_ERROR

						OR		BYTE PTR DS:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_DIR
						MOV		SI,DI
						ROL		ESI,16	; Save buffer header in Hiword of ESI (most likely 0000h though...)
						LEA		SI,[DI+IO_BUF_INFO_size]
						; DS:SI is top of sector

						MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						SHR		ECX,DIRENT_SHIFT

FIND_AVAILDIR_DIRENT_LOOP:
						CMP		BYTE PTR DS:[SI],00h
						JE		FIND_AVAIL_DIRENT_FOUND
						CMP		BYTE PTR DS:[SI],DELETED_FILE_FIRST_BYTE
						JE		FIND_AVAIL_DIRENT_FOUND
						ADD		SI,DIRECTORY_ENTRY_size
						LOOP	FIND_AVAILDIR_DIRENT_LOOP

						POP		AX
						POP		EBX
						INC		EBX
						INC		AX
						TEST	AL,GS:[BP+DPB_CLUSTER_MASK]
						JNE		FIND_AVAILDIR_SECT_LOOP

						POP		EBX
						CALL	GET_NEXT_CLUSTER	; EBX Preserved
						MOVZX	EDX,DX
						CMP		DX,GS:[BP+DPB_MAX_CLUSTER_NUM]
						JBE		FIND_AVAILDIR_CLST_LOOP

						; Not found
						MOV		EDX,EBX
						STC
						RET

FIND_AVAIL_DIRENT_FOUND:
						POP		CX	; Dummy pop
						POP		ECX
						POP		EDX
						SHLD	EBX,ESI,16
						CLC
						RET

FIND_AVAIL_DIRENT_ERROR:
						POP		CX	; Dummy pop
						POP		ECX
						POP		EDX
						STC
						RET



FIND_AVAIL_DIRENT_ROOT:
						MOVZX	EDX,WORD PTR GS:[BP+DPB_FIRST_DIR_SECTOR]

FIND_AVAIL_DIR_ROOT_SECT_LOOP:
						PUSH	EDX

						XOR		AL,AL	; Preread
						CALL	GETBUFFER_REGULAR
						JC		FIND_AVAIL_DIRENT_ROOT_ERROR
						OR		BYTE PTR DS:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_DIR

						MOV		SI,DI
						SHL		ESI,16
						LEA		SI,[DI+IO_BUF_INFO_size]

						MOVZX	ECX,WORD PTR GS:[BP+DPB_BYTES_PER_SECTOR]
						SHR		ECX,DIRENT_SHIFT
FIND_AVAIL_DIR_ROOT_DIRENT_LOOP:
						CMP		BYTE PTR DS:[SI],00h
						JE		FIND_AVAIL_DIR_ROOT_FOUND
						CMP		BYTE PTR DS:[SI],DELETED_FILE_FIRST_BYTE
						JE		FIND_AVAIL_DIR_ROOT_FOUND

						ADD		SI,DIRECTORY_ENTRY_size
						LOOP	FIND_AVAIL_DIR_ROOT_DIRENT_LOOP

						POP		EDX
						INC		EDX
						CMP		DX,GS:[BP+DPB_FIRST_DATA_SECTOR]
						JB		FIND_AVAIL_DIR_ROOT_SECT_LOOP

						; Not Found

						XOR		EDX,EDX
						STC
						RET

;   CF=0   Success.  DS:SI=DIRENT,  DS:BX=BUFFER HEADER  ECX=Sector  EDX=Cluster
FIND_AVAIL_DIR_ROOT_FOUND:
						POP		ECX		; Pop Sector from the stack
						XOR		EDX,EDX	; It's root dir
						SHLD	EBX,ESI,16 ; Get Hiword of ESI in BX
						CLC
						RET

FIND_AVAIL_DIRENT_ROOT_ERROR:
						POP		EDX
						XOR		EDX,EDX	; Last cluster scanned is Root.
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  DPB
;   EDX    Cluster to attach a new cluster.  (If the next cluster is non null, will be error)
; Output
;   CF=0   Success EDX=New Directory Cluster
;   CF=1   Fail
EXTEND_DIR:
						OR		EDX,EDX
						JE		EXTEND_DIR_ERROR	; Root dir cannot be extended.

EXTEND_DIR_NOT_ROOT:
						; To be implemented
						JMP		EXTEND_DIR

EXTEND_DIR_ERROR:
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input:
;   DL Drive  0:Current Drive  1:ADrive
;   DS:SI  64-byte buffer to receive the cwd
; Returns CWD without drive-letter, ':', and the first backslash
GETCWD:
						MOV		AL,DL
						CALL	FCBDRIVE_TO_SANE_DRIVE

						PUSH	DS
						PUSH	SI
						; Input
						;   AL=Drive (0=ADrive)
						CALL	GET_DRIVE_CDS
						; Output
						;   CF=0  DS:BX=CDS      AX Destroyed
						;   CF=1  Drive invalid  AX=DOSERR_INVALID_DRIVE   DS,BX Destroyed
						POP		DI
						POP		ES
						JC	GETCWD_EXIT

						MOV		SI,BX
						ADD		SI,DS:[BX+CDS_CURDIR_ROOTLEN] ; Skip Driveletter, Colon

						MOV		CX,63	; Up-to 63 chars of C-String

						LODSB
						CMP		AL,'\'
						JE		GETCWD_SKIP_SLASH
						CMP		AL,'/'
						JE		GETCWD_SKIP_SLASH
						STOSB
						DEC		CX

						JMP_IF_NOT_KANJI	AL,GETCWD_SKIP_SLASH
						LODSB
						STOSB
						DEC		CX
GETCWD_SKIP_SLASH:
						OR		AL,AL
						JE		GETCWD_COPY_DONE

						CALL	KSTRNCPY_CAPS_BACKSLASH

GETCWD_COPY_DONE:
						MOV		AX,0100h
						; 0100h for success (Undocumented according to http://www.ctyme.com/intr/rb-2933.htm)
						CLC
GETCWD_EXIT:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI File Template
;   CX Attribute Mask (CH=0)
;   CS:[DMA_BUFFER_PTR] Pointer to store FINDSTRUCT
; Output
;   CF=0 Success
;   CF=1 Error AX=Error Code DOSERR_FILE_NOT_FOUND,DOSERR_DIR_NOT_FOUND, or DOSERR_NO_MORE_FILES
FIND_FIRST:
						MOV		BYTE PTR CS:[SATTR],CL

						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						JC		FIND_FIRST_FILE_NOT_FOUND

						; CS:[FILENAME_BUFFER] Full-Path Name

						_LES	DI,CS:[DMA_BUFFER_PTR]
						MOV		CL,CS:[SATTR]
						MOV		ES:[DI+FIND_ATTR_FILTER],CL

						MOV		AL,BYTE PTR CS:[FILENAME_BUFFER]
						SUB		AL,'A'

						INC		AL
						MOV		ES:[DI],AL	; This seems to be an insane (FCB) drive number.
						DEC		AL

						CALL	GET_DRIVE_CDS
						;   CF=0  DS:BX=CDS      AX Destroyed
						;   CF=1  Drive invalid  AX=DOSERR_INVALID_DRIVE   DS,BX Destroyed
						JC		FIND_FIRST_INVALID_DRIVE

						; MS-DOS V3.1 tries INF 2FH AX=1119h (Find First without CDS)
						; But, I don't think it's necessary.
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		FIND_FIRST_NOT_REDIRECTED

;FIND_FIRST_REDIRECTED:
						_LES	DI,CS:[DMA_BUFFER_PTR]
						PUSH	ES
						PUSH	DI

						; SHSUCDX disregards DMA_BUFFER_PTR (DMApp in the source) in function 111Bh (Find FIrst)
						; and always populate CS:[0460h] (SDB).
						; I haven't looked into the original MSCDEX, so I don't know if it was an expected behavior.
						; However, I cannot count on SHSUCDX to fill arbitrary location by controlling
						; CS:[DMA_BUFFER_PTR].  I need to assume the data comes to CS:[SDB] and copy
						; from there.

						MOV		WORD PTR CS:[DMA_BUFFER_PTR],OFFSET SDB
						MOV		WORD PTR CS:[DMA_BUFFER_SEG],CS

						PUSH	CS
						POP		DS
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1],OFFSET FILENAME_BUFFER
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1+2],CS
						MOV		AX,INT2FH_FIND_FIRST
						INT		2Fh

						POP		DI
						POP		ES
						MOV		CS:[DMA_BUFFER_PTR],DI
						MOV		CS:[DMA_BUFFER_PTR+2],ES

						; So, looks like the structure returned by MSCDEX is incompatible with DOS 3.x.

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET SDB

						PUSH	DI
						PUSH	SI
						MOV		CX,15h
						REP MOVSB
						POP		SI
						POP		DI

						; DS is already CS
						MOV		SI,OFFSET SDB+015h
						; ES:DI is already FINDSTRUCT
						CALL	DIRENT_TO_FINDSTRUCT

						RET



FIND_FIRST_NOT_REDIRECTED:
						; GS:BP is the DPB
						LGS		BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]

						; I just need to call FETCH_DIR.
						; I need to know the position in the directory.

						; Need to copy template to DMA_BUFFER_PTR.FIND_WILDCARD

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER

						; Input
						;   DS:SI  Pathname
						CALL	SEEK_LAST_BACKSLASH
						; Return
						;   DS:DI  Pointer to last backslash or slash or zero or just incoming SI
						;   AX     Destroyed
						;   SI     Preserved

						CMP		DI,OFFSET FILENAME_BUFFER
						JE		FIND_FIRST_FILE_NOT_FOUND
						CMP		BYTE PTR DS:[DI],0
						JE		FIND_FIRST_FILE_NOT_FOUND

						LEA		SI,[DI+1]
						; DS:SI is the last part of the file name.
						; DS:[FILENAME_BUFFER] is already lesser wildcard.
						; Make 11-byte name (or pattern) DMA_BUFFER

						_LES	DI,CS:[DMA_BUFFER_PTR]
						ADD		DI,FIND_WILDCARD

						; Input
						;   DS:SI  Source File name
						;   ES:DI  Destination 11-byte file name.
						; Destroys EAX,CX
						CALL	MAKE_11BYTE_FILENAME


						; Now Get to the Directory
						XOR		EAX,EAX	; Root dir
						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3 ; Skip "?:/".  It is not redirected.  So, no worry about "\\Q.A." situation.

						; Input
						;   GS:BP  DPB
						;   DS:SI  Starting pointer in the fully-qualified file name.
						;          If the file name is:
						;            C:\COMMAND.COM
						;               ^SI must point this.
						;   EAX    Starting cluster (0->Root Dir)
						MOVZX	CX,BYTE PTR CS:[SATTR]
						CALL	FETCH_DIR
						; Return
						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
						;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
						;   Lastly scanned directory cluster can be found in DIR_variables
						JC		FIND_FIRST_EXIT

						_LDS	SI,CS:[DMA_BUFFER_PTR]

						MOV		AX,CS:[DIR_COUNT_IN_DIRECTORY]	; Should be 1 for the first file in root.  0 is volume label.
						MOV		DS:[SI+FIND_COUNT_IN_DIR],AX

						MOV		EAX,CS:[DIR_CLUSTER0]
						MOV		DS:[SI+FIND_DIR_CLUSTER],AX

						XCHGSTACK	ES,DS
						XCHG	SI,DI
						CALL	DIRENT_TO_FINDSTRUCT

						CLC
FIND_FIRST_EXIT:
						RET


FIND_FIRST_FILE_NOT_FOUND:
						MOV		AX,DOSERR_FILE_NOT_FOUND
						STC
						RET

FIND_FIRST_INVALID_DRIVE:
						MOV		AX,DOSERR_INVALID_DRIVE
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CX Attribute Mask (CH=0)
;   CS:[DMA_BUFFER_PTR] Pointer to FINDSTRUCT populated by FIND_FIRST
; Output
;   CF=0 Success
;   CF=1 Error AX=Error Code DOSERR_FILE_NOT_FOUND,DOSERR_DIR_NOT_FOUND, or DOSERR_NO_MORE_FILES
FIND_NEXT:
						_LES	DI,CS:[DMA_BUFFER_PTR]

						MOV		CL,ES:[DI+FIND_ATTR_FILTER]
						MOV		CS:[SATTR],CL

						MOVZX	AX,BYTE PTR ES:[DI+FIND_DRIVE]
						CALL	FCBDRIVE_TO_SANE_DRIVE
						JC		FIND_NEXT_INVALID_DRIVE

						CALL	GET_DRIVE_CDS
						;   CF=0  DS:BX=CDS      AX Destroyed
						;   CF=1  Drive invalid  AX=DOSERR_INVALID_DRIVE   DS,BX Destroyed
						JC		FIND_FIRST_INVALID_DRIVE

						; MS-DOS V3.1 tries INF 2FH AX=1119h (Find First without CDS)
						; But, I don't think it's necessary.
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		FIND_NEXT_NOT_REDIRECTED

;FIND_NEXT_REDIRECTED:
						; SHSUCDX assumes SDB, not DTA.  I don't know if it is an expected behavior.
						PUSH	DS
						PUSH	BX	; Save CDS

						_LDS	SI,CS:[DMA_BUFFER_PTR]
						PUSH	CS
						POP		ES
						MOV		DI,OFFSET SDB

						MOV		CX,015h
						REP MOVSB

						POP		DI
						POP		ES	; CDS -> ES:DI

						PUSH	DWORD PTR CS:[DMA_BUFFER_PTR]

						MOV		WORD PTR CS:[DMA_BUFFER_PTR],OFFSET SDB
						MOV		WORD PTR CS:[DMA_BUFFER_PTR+2],CS

						MOV		AX,INT2FH_FIND_NEXT
						INT		2Fh

						POP		DWORD PTR CS:[DMA_BUFFER_PTR]
						JC		FIND_NEXT_EXIT

						_LES	DI,CS:[DMA_BUFFER_PTR]

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET SDB

						MOV		CX,15h
						REP		MOVSB

						MOV		DI,CS:[DMA_BUFFER_PTR]
						; SI is SDB+15h

						CALL	DIRENT_TO_FINDSTRUCT

						CLC
						JMP		FIND_NEXT_EXIT


FIND_NEXT_NOT_REDIRECTED:
						; DS:BX is CDS.
						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]
						_LES	DI,CS:[DMA_BUFFER_PTR]

						MOVZX	EAX,WORD PTR ES:[DI+FIND_DIR_CLUSTER]
						MOV		CS:[DIR_CLUSTER0],EAX

						MOV		AX,ES:[DI+FIND_COUNT_IN_DIR]
						INC		AX
						MOV		CS:[DIR_SKIP_COUNTER],AX

						MOV		EAX,DWORD PTR ES:[DI+FIND_WILDCARD]
						MOV		DWORD PTR CS:[TEMPORARY_DIRENT+DIRENT_FILENAME],EAX
						MOV		EAX,DWORD PTR ES:[DI+FIND_WILDCARD+4]
						MOV		DWORD PTR CS:[TEMPORARY_DIRENT+DIRENT_FILENAME+4],EAX
						MOV		EAX,DWORD PTR ES:[DI+FIND_WILDCARD+7]
						MOV		DWORD PTR CS:[TEMPORARY_DIRENT+DIRENT_FILENAME+7],EAX

						; Input
						;   GS:BP  DPB
						;   Set:
						;   CS:[DIR_CLUSTER0]
						;   CS:[DIR_SKIP_COUNTER]
						;   CS:[TEMPORARY_DIRENT]  11-byte file/dir name
						CALL	SCAN_DIR
						; Return
						;   CF=0  Found
						;   CF=1  Not Found   AX DOS Error Code
						;   DS:SI  Last-read sector buffer header
						;   Set:
						;   DIR_CURRENT_CLUSTER
						;   DIR_SECTORS_INTO_CLUSTER
						;   DIR_BYTES_INTO_SECTOR
						JC		FIND_NEXT_NO_MORE_FILES


						PUSH	DS
						POP		ES
						LEA		DI,[SI+IO_BUF_INFO_size]
						ADD		DI,CS:[DIR_BYTES_INTO_SECTOR]

						_LDS	SI,CS:[DMA_BUFFER_PTR]

						MOV		AX,CS:[DIR_COUNT_IN_DIRECTORY]	; Should be 1 for the first file in root.  0 is volume label.
						MOV		DS:[SI+FIND_COUNT_IN_DIR],AX

						MOV		EAX,CS:[DIR_CLUSTER0]			; Not Supposed to Change
						MOV		DS:[SI+FIND_DIR_CLUSTER],AX		; Not Supposed to Change

						XCHGSTACK	ES,DS
						XCHG	SI,DI
						CALL	DIRENT_TO_FINDSTRUCT

FIND_NEXT_EXIT:
						RET


FIND_NEXT_NO_MORE_FILES:
						MOV		AX,DOSERR_NO_MORE_FILES
						STC
						RET

FIND_NEXT_INVALID_DRIVE:
						MOV		AX,DOSERR_INVALID_DRIVE
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  DIRENT
;   ES:DI  FINDSTRUCT
; Copy DIRENT to Found-File part of FINDSTRUCT
DIRENT_TO_FINDSTRUCT:
						MOV		AL,DS:[SI+DIRENT_ATTR]
						MOV		ES:[DI+FIND_FOUND_ATTR],AL ; +15h

						MOV		EAX,DWORD PTR DS:[SI+DIRENT_TIME]
						MOV		DWORD PTR ES:[DI+FIND_FOUND_TIME],EAX ; +16h (Time and Date)

						MOV		EAX,DWORD PTR DS:[SI+DIRENT_FILE_SIZE]
						MOV		DWORD PTR ES:[DI+FIND_FOUND_FILE_SIZE],EAX ; 1Ah

						ADD		DI,FIND_FOUND_FILENAME
						ADD		SI,DIRENT_FILENAME
						CALL	PLAIN_FILENAME_FROM_11BYTE_FILENAME

						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  DS:SI=C-String Filename
CHDIR:
						CALL	MAKE_FULLPATH_CRUNCH_LESSERWC
						JC		CHDIR_EXIT

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER
						CALL	CHECK_WILDCARD_PRESENCE_CSTR
						JC		CHDIR_DIR_NOT_FOUND

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	GET_DRIVE_CDS
						JC		CHDIR_DIR_NOT_FOUND

						; DS:BX is CDS
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JE		CHDIR_NOT_REDIRECTED
CHDIR_REDIRECTED:
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],BX
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],DS

						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1],OFFSET FILENAME_BUFFER
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1+2],CS

						MOV		AX,INT2FH_CHDIR	; This does not really CHDIR.  It only checks the name is a directory.
						INT		2Fh

						; If no error, file name must be copied to CDS.
						JNC		CHDIR_COPY
						RET


CHDIR_NOT_REDIRECTED:
						MOV		EDX,-1 ; Tentative.  May become CDS_CURDIR_CLUSTER

						MOV		EAX,DWORD PTR CS:[FILENAME_BUFFER]
						XOR		AL,AL
						CMP		EAX,005C3A00h ; '\:'
						JE		CHDIR_COPY

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	MEDIACHECK_READYCDS		; CF=1 Error  CF=0 AL=(0:No Change  1:Disk Changed)
						JC		CHDIR_DIR_NOT_FOUND

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	GET_DRIVE_CDS

						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER+3
						XOR		EAX,EAX

						MOV		CX,DIRENT_ATTR_HIDDEN+DIRENT_ATTR_SYSTEM+DIRENT_ATTR_DIRECTORY

						; Input
						;   GS:BP  DPB
						;   DS:SI  Starting pointer in the fully-qualified file name.
						;          If the file name is:
						;            C:\COMMAND.COM
						;               ^SI must point this.
						;   EAX    Starting cluster (0->Root Dir)
						;   CX     Attribute Filter, High-Byte ignored.
						CALL	FETCH_DIR
						; Return
						;   CF=0  Found.  AL is file attribute  AH=0,  ES:DI=DIRENT,  ES:BX=BUFFER HEADER
						;   CF=1  Not Found.  AX is DOSERR_FILE_NOT_FOUND, DOSERR_DIR_NOT_FOUND, or DOSERR_ACCESS_DENIED
						;   Lastly scanned directory cluster can be found in DIR_variables
						; Don't expect registers are preserved.

						TEST	AL,DIRENT_ATTR_DIRECTORY
						JE		CHDIR_DIR_NOT_FOUND

						MOV		DX,ES:[DI+DIRENT_FIRST_CLUSTER]	; DX is the cluster of the directory

CHDIR_COPY:
						PUSH	CS
						POP		ES
						MOV		DI,OFFSET FILENAME_BUFFER
						CALL	STRLEN_ESDI
						CMP		CX,CDS_CURDIR_LEN_MAX
						JA		CHDIR_DIR_NOT_FOUND

						; Make sure DX survives STRLEN_ESDI

						CALL	DRIVE_NUMBER_FROM_FILENAME_BUFFER
						CALL	GET_DRIVE_CDS

						; DS:BX is CDS
						; DX is cluster of the directory, of 0ffffh, if root dir.

						MOV		DS:[BX+CDS_CURDIR_CLUSTER],DX

						MOV		CX,CDS_CURDIR_LEN_MAX
						PUSH	DS
						POP		ES
						LEA		DI,[BX+CDS_CURDIR]
						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER
						CALL	STRNCPY

						ADD		DI,CX
						NEG		CX
						ADD		CX,CDS_CURDIR_LEN_MAX
						XOR		AL,AL
						REP		STOSB

CHDIR_EXIT:
						RET

CHDIR_DIR_NOT_FOUND:
						MOV		AX,DOSERR_DIR_NOT_FOUND
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
; AX - YYYYYYYMMMMDDDDD,
; DX - HHHHHMMMMMMSSSSS (SSSSS=seconds/2)()}
READ_CLOCK_FOR_DIRENT:
						PUSH	EBX
						PUSH	ECX

						CALL	DEVCALL_READ_CLOCK
						;   AX=(Probably)Days since January 1 1980.
						;   CH=hour;
						;   CL=minute
						;   DH=second
						;   DL=1/100seconds

						MOVZX	DX,DH
						SHR		DX,1	; Low 5-bits seconds/2

						MOVZX	BX,CL
						SHL		BX,5	; Next 6-bits minuts
						OR		DX,BX

						MOVZX	BX,CH
						SHL		BX,11
						OR		DX,BX	; Highest 5-bits hours

						PUSH	DX		; Save DX

						CALL	DAYS_SINCE_1980_TO_YEAR_MONTH_DATE_DAY
						;   BX=Years since 1980
						;   CH=Month
						;   CL=Date
						;   DL=Day of week (0=Sun)
						MOV		AX,BX
						SHL		AX,9

						MOVZX	BX,CH
						SHL		BX,5
						OR		AX,BX

						OR		AL,CL

						POP		DX
						POP		ECX
						POP		EBX
						RET
