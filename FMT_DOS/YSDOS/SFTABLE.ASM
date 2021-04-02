; Input
;   AX  File Handle (JFN)
; Output
;   CF=0  AX=SFN, FS:DI  SF_TABLE
;   CF=1  File not open  AX=DOSERR_FILE_NOT_FOUND
;   GS    CurrentPDB
; ES,DX Preserved
; Other registers destroyed
GET_SFN_SFENTRY_FROM_JFN:
						CALL	GET_SFN_FROM_JFN
						JC		GET_SFN_SFENTRY_FROM_JFN_ERR

						PUSH	AX
						CALL	GET_SF_ENTRY_FROM_SFN
						POP		AX
						JC		GET_SFN_SFENTRY_FROM_JFN_ERR

GET_SFN_SFENTRY_FROM_JFN_EXIT:
						RET

GET_SFN_SFENTRY_FROM_JFN_ERR:
						MOV		AX,DOSERR_FILE_NOT_FOUND
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX  JFN
; Output
;   CF=0  FS:DI  SF_TABLE
;   CF=1  File not open
;   GS    CurrentPDB
; ES Preserved
; AX,BX Destroyed
; DX Preserved
GET_SF_ENTRY_FROM_JFN	PROC
						CALL	GET_SFN_FROM_JFN
						JB		GET_SF_ENTRY_FROM_JFN_RET
						CALL	GET_SF_ENTRY_FROM_SFN
GET_SF_ENTRY_FROM_JFN_RET:
						RET
GET_SF_ENTRY_FROM_JFN	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input:
;    AX  JFN
; Output:
;    CF=0  AX  SFN
;    CF=1  Unavailable  BX destroyed
;    GS    CurrentPDB
; DS,ES Preserved
; DI Destroyed
GET_SFN_FROM_JFN		PROC
						MOV		GS,CS:[CurrentPDB]
						CMP		AX,GS:[PSP_FILE_TABLE_SIZE]
						JAE		GET_SFN_FROM_JFN_ERROR
						MOV		DI,AX
						MOVZX	AX,BYTE PTR GS:[PSP_FILE_TABLE+DI]
						CMP		AX,FILE_NOT_OPEN
						JE		GET_SFN_FROM_JFN_ERROR
						CLC
						RET
GET_SFN_FROM_JFN_ERROR:
						STC
						RET
GET_SFN_FROM_JFN		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input:
;    AX  SFN (System Global File Serial Number, apparently.  0==CONS DEV)
; Return:
;    CF=0  FS:DI=SF Pointer (Pointer to SF_ENTRY structure)
;    CF=1  Error
;    AX destroyed.
; ES Preserved.
; Equivalent to get_sf_from_sfn in MS-DOS V2.0 source.
GET_SF_ENTRY_FROM_SFN	PROC
						LFS		DI,CS:[FIRST_SFT_PTR]

						; I hope there is at least one SFT.
GET_SF_ENTRY_FROM_SFN_LOOP:
						CMP		AX,FS:[DI+SFT_COUNT]
						JB		GET_SF_ENTRY_FROM_SFN_FOUND
						SUB		AX,FS:[DI+SFT_COUNT]
						LFS		DI,FS:[DI+SFT_NEXT]
						CMP		DI,0FFFFh
						JNE		GET_SF_ENTRY_FROM_SFN_LOOP
						STC
						RET

GET_SF_ENTRY_FROM_SFN_FOUND:
						MOV		AH,SF_ENTRY_size
						MUL		AH
						ADD		DI,SFT_size
						ADD		DI,AX
						CLC
						RET

GET_SF_ENTRY_FROM_SFN	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   FS:DI  SF_ENTRY
; Return
;   DS:SI  Device Driver Pointer
;   CL     Drive (0 if chardev)
;   CH     Unit (0 if chardev)
;   AH     Media Descriptor (0 if chardev)
;   AL     0FFh CHARDEV, Zero Not CHARDEV
;   ZF=1(E)    If redirected (INT 2F device)
;   ZF=0(NE)   Redirected (INT 2F device)
;   BX,DX  Preserved
GET_SF_DEVICE_DRIVER	PROC
						XOR		CX,CX
						XOR		AX,AX
						DEC		AL
						LDS		SI,FS:[DI+SF_DRIVER_POINTER]

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						JNE		GET_SF_DEVICE_RET

						; If not CHARDEV, DS:SI is now Drive Parameter Block
						INC		AL
						MOV		CX,WORD PTR DS:[SI+DPB_DRIVE_CODE] ; DPB_UNIT follows DPB_DRIVE
						MOV		AH,DS:[SI+DPB_MEDIA_DESC_TYPE]
						LDS		SI,DS:[SI+DPB_PTR_TO_DEV_DRIVER]

GET_SF_DEVICE_RET:
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_REDIRECTED
						RET
GET_SF_DEVICE_DRIVER	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   CX     Clusters into file
;   FS:DI  SF_ENTRY
; Output
;   CF=0   DX=Cluster CXth cluster of the file
;   CF=1   Gone beyond the end of file
;          SF.CUR_ABS_CLUSTER_NUM and SF_REL_CLUSTER_NUM updated.
;   GS:BP  DRIVE_PARAMETER_BLOCK
;   CX Preserved
;   EDI  Destroyed from GET_NEXT_CLUSTER
;   EAX  Destroyed from GET_NEXT_CLUSTER
;   DS Destroyed   <-<-<-<- Exterme Caution
; Will crash unless SF_ENTRY is a BLOCK device.
GET_CLUSTERS_INTO_FILE	PROC
						PUSH	ECX
						PUSH	EDI

						LGS		BP,FS:[DI+SF_DRIVER_POINTER]

						MOV		DX,FS:[DI+SF_FIRST_CLUSTER_NUM]		; First cluster of file
						JCXZ	GET_CLUSTERS_INTO_FILE_FOUND		; If CX=0, return the first cluster of file.

						MOV		DX,FS:[DI+SF_CUR_ABS_CLUSTER_NUM]	; If CX=current rel, return current abs.
						MOV		BX,DX
						CMP		CX,FS:[DI+SF_CUR_REL_CLUSTER_NUM]
						JE		GET_CLUSTERS_INTO_FILE_FOUND
						MOV		DX,FS:[DI+SF_FIRST_CLUSTER_NUM]		; First cluster of file
						JB		GET_CLUSTERS_INTO_FILE_SCAN			; Need to start from DX and hop CX times.
;GET_CLUSTERS_INTO_FILE_AFTER:
						; The wanted cluster is behind the current known cluster.
						; Can save some hops.
						SUB		CX,FS:[DI+SF_CUR_REL_CLUSTER_NUM]
						MOV		DX,FS:[DI+SF_CUR_ABS_CLUSTER_NUM]

GET_CLUSTERS_INTO_FILE_SCAN:
						; DX is the current cluster
						; CX is steps to hop.
						PUSH	CX
						MOV		BX,DX
						CALL	GET_NEXT_CLUSTER
						; EBX, Hiword of EDX Preserved
						; DS,EDI  Destroyed
						; EAX,ECX Destroyed
						POP		CX
						JB		GET_CLUSTERS_INTO_FILE_ERROR
						LOOP	GET_CLUSTERS_INTO_FILE_SCAN


GET_CLUSTERS_INTO_FILE_FOUND:
						POP		EDI
						POP		ECX
						MOV		FS:[DI+SF_CUR_REL_CLUSTER_NUM],CX
						MOV		FS:[DI+SF_CUR_ABS_CLUSTER_NUM],DX
						CLC
						RET

GET_CLUSTERS_INTO_FILE_ERROR:
						POP		EDI
						POP		ECX
						STC
						RET


GET_CLUSTERS_INTO_FILE	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  FS:DI  SF_ENTRY
;Return
;  CF=0 DS:SI  Pointer to the 32-byte directory entry in a buffer
;       DS:DX  Pointer to the buffer header.
;  CF=1        Error  SI Destroyed
;  GS:BP       DPB
;Destroyed:
;  AX
;  Hiword EDI  Destroyed from GETBUFFER_REGULAR
GET_DIRENT_POINTER:
						PUSH	DI
						MOV		DX,FS:[DI+SF_DIR_ENT_SECTOR]
						XOR		AX,AX						; AX=0 Read
						CALL	GETBUFFER_REGULAR
						MOV		DX,DI
						LEA		SI,[DI+IO_BUF_INFO_size]	; LEA doesn't affect flags unlike 6809.
						POP		DI
						JC		GET_DIRENT_POINTER_END


						; DS:SI is top of the sector.
						MOVZX	AX,BYTE PTR FS:[DI+SF_DIR_ENT_POS_IN_SECTOR]
						SHL		AX,DIRENT_SHIFT
						ADD		SI,AX

						CLC
GET_DIRENT_POINTER_END:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Return
;  CF=0 Found,  CF=1 Not Found
;  ES  Current PDB
;  BX=Available JFN of current PDB
;  Preserves DS:SI
;  Preserves EAX
;  Destroys ES,DI
GET_AVAILABLE_JFN:
						MOV		ES,CS:[CurrentPDB]
						LES		DI,ES:[PSP_FILE_TABLE_POINTER]
						XOR		BX,BX

GET_AVAILABLE_JFN_LOOP:
						CMP		BYTE PTR ES:[DI+BX],FILE_NOT_OPEN
						JE		GET_AVAILABLE_JFN_LOOP_FOUND	; If Equal, CF=0.
						INC		BX
						CMP		BX,WORD PTR ES:[PSP_FILE_TABLE_SIZE]
						JB		GET_AVAILABLE_JFN_LOOP

						STC
GET_AVAILABLE_JFN_LOOP_FOUND:
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   BX  JFN
;   DL  SFN
; GS Destroyed
RESERVE_JFN:
						PUSH	DI
						MOV		GS,CS:[CurrentPDB]
						LGS		DI,GS:[PSP_FILE_TABLE_POINTER]
						MOV		GS:[DI+BX],DL
						POP		DI
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   BX  JFN
; GS Destroyed
UNRESERVE_JFN:
						PUSH	DI
						MOV		GS,CS:[CurrentPDB]
						LGS		DI,GS:[PSP_FILE_TABLE_POINTER]
						MOV		BYTE PTR GS:[DI+BX],FILE_NOT_OPEN
						POP		DI
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Return
;  FS:DI=Available SF_ENTRY, DX=SFN
;  Preserves EAX
;  Preserves DS:SI
;  CX Destroyed
;  BX Destroyed
GET_AVAILABLE_SF_ENTRY:
						LFS		BX,CS:[FIRST_SFT_PTR]

						XOR		DX,DX
GET_AVAIL_SF_ENTRY_OUTER_LOOP:
						LEA		DI,[BX+SFT_size]
						MOV		CX,FS:[BX+SFT_COUNT]
						JCXZ	GET_AVAIL_SF_ENTRY_NEXT_SFT

GET_AVAIL_SF_ENTRY_INNER_LOOP:
						CMP		WORD PTR FS:[DI+SF_REFCOUNT],0
						JE		GET_AVAIL_SF_ENTRY_FOUND

						INC		DX
						ADD		DI,SF_ENTRY_size
						LOOP	GET_AVAIL_SF_ENTRY_INNER_LOOP

GET_AVAIL_SF_ENTRY_NEXT_SFT:
						LFS		BX,FS:[BX+SFT_NEXT]
						CMP		BX,0ffffh
						JNE		GET_AVAIL_SF_ENTRY_OUTER_LOOP

						STC
						RET

GET_AVAIL_SF_ENTRY_FOUND:
						CLC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  DIRENT
;   FS:DI  SF_ENTRY
;   GS:BP  DPB
;   AL     Open Mode
;   BX     DIRENT Sector
;   DX     DIRENT Position in Sector in bytes.
; Not for CHARDEV
MAKE_SF_ENTRY_FROM_DIRENT:
						XOR		AH,AH
						MOV		FS:[DI+SF_MODE],AX
						MOV		AL,DS:[SI+DIRENT_ATTR]
						MOV		FS:[DI+SF_ATTR],AL

						MOVZX	AX,BYTE PTR GS:[BP+DPB_DRIVE_CODE]
						OR		AX,SF_DEVFLAG_BLOCK_NOT_WRITTEN
						MOV		FS:[DI+SF_DEVFLAGS],AX

						MOV		WORD PTR FS:[DI+SF_DRIVER_POINTER],BP
						MOV		WORD PTR FS:[DI+SF_DRIVER_POINTER+2],GS

						MOV		AX,DS:[SI+DIRENT_FIRST_CLUSTER]
						MOV		WORD PTR FS:[DI+SF_FIRST_CLUSTER_NUM],AX
						MOV		WORD PTR FS:[DI+SF_CUR_ABS_CLUSTER_NUM],AX

						MOV		EAX,DWORD PTR DS:[SI+DIRENT_TIME]
						MOV		DWORD PTR FS:[DI+SF_TIME],EAX

						MOV		EAX,DWORD PTR DS:[SI+DIRENT_FILE_SIZE]
						MOV		DWORD PTR FS:[DI+SF_FILE_SIZE],EAX

						XOR		EAX,EAX
						MOV		FS:[DI+SF_FILE_POINTER],EAX
						MOV		FS:[DI+SF_NEXT_SHARED_SFT],EAX

						MOV		FS:[DI+SF_CUR_REL_CLUSTER_NUM],AX
						MOV		FS:[DI+SF_SHARE_FT_OFFSET],AX
						; ABS CLUSTER NUM already set to the first cluster.

						MOV		FS:[DI+SF_DIR_ENT_SECTOR],BX
						SHR		DX,DIRENT_SHIFT
						MOV		FS:[DI+SF_DIR_ENT_POS_IN_SECTOR],DL

						MOV		EAX,DWORD PTR DS:[SI+DIRENT_FILENAME]
						MOV		DWORD PTR FS:[DI+SF_FILENAME],EAX
						MOV		EAX,DWORD PTR DS:[SI+DIRENT_FILENAME+4]
						MOV		DWORD PTR FS:[DI+SF_FILENAME+4],EAX
						MOV		EAX,DWORD PTR DS:[SI+DIRENT_FILENAME+7]
						MOV		DWORD PTR FS:[DI+SF_FILENAME+7],EAX

						; NEXT_SHARED_SFT already taken care
						MOV		AX,CS:[MACHINE_NUMBER]
						MOV		FS:[DI+SF_MACHINE_NUMBER],AX
						MOV		AX,CS:[CurrentPDB]
						MOV		FS:[DI+SF_PSP_OWNER],AX
						; SHARE_FT_OFFSET already taken care

						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;Input
; EDX=Directory Sector
; AX=Position in Directory Sector
; EBP=DPB (Hiword=SEG, Loword=OFFSET)
;Return
; CF=0  FS:DI=SF_ENTRY
; CF=1  No match
MATCH_SF_ENTRY_DIRENT_SECTOR:
						LFS		DI,CS:[FIRST_SFT_PTR]

MATCH_SF_ENTRY_DIRENT_OUTER:
						PUSH	DI

						MOV		CX,FS:[DI+SFT_COUNT]
						ADD		DI,SFT_size

MATCH_SF_ENTRY_DIRENT_INNER:
						CMP		WORD PTR FS:[DI+SF_REFCOUNT],0
						JE		MATCH_SF_ENTRY_DIRENT_NEXT
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV+SF_DEVFLAG_REDIRECTED
						JNE		MATCH_SF_ENTRY_DIRENT_NEXT
						CMP		EBP,FS:[DI+SF_DRIVER_POINTER]
						JNE		MATCH_SF_ENTRY_DIRENT_NEXT
						CMP		DX,FS:[DI+SF_DIR_ENT_SECTOR]
						JNE		MATCH_SF_ENTRY_DIRENT_NEXT
						CMP		AL,FS:[DI+SF_DIR_ENT_POS_IN_SECTOR]
						JE		MATCH_SF_ENTRY_DIRENT_FOUND
MATCH_SF_ENTRY_DIRENT_NEXT:
						ADD		DI,SF_ENTRY_size
						LOOP	MATCH_SF_ENTRY_DIRENT_INNER

						POP		DI

						_LFS	DI,FS:[DI+SFT_NEXT]
						CMP		DI,0FFFFh
						JNE		MATCH_SF_ENTRY_DIRENT_OUTER

						STC
						RET

MATCH_SF_ENTRY_DIRENT_FOUND:
						ADD		SP,2
						CLC
						RET


