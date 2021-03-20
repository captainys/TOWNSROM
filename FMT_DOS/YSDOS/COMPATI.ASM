COMPAT_AX				DW		0


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Replace Original GETBUFFR for Testing
; Input
;   AL==0 -> Preread
;   AL!=0 -> Don't preread
;   DX==LBA
;   SI==0 -> Non-FAT sector
;   SI!=0 -> FAT sector
;   ES:BP    Drive Parameter Block
;
; Output
;   CF==0 Success
;   CS:[CURBUF]
;   CS:[LASTBUR] populated
;   DS=CS  WTF!?
;   DI Buffer Offset
;   CF==1 Fail
COMPAT_GETBUFFR			PROC
						PUSH	GS
						PUSH	FS
						PUSH	ESI

						PUSH	ES
						POP		GS	; GS:[BP] is DPB

						ROL		EDI,16
						PUSH	DI
						ROL		EDI,16

						OR		SI,SI
						JNE		COMPAT_GETBUFFER_FAT
						CALL	GETBUFFER_REGULAR
						JMP		COMPAT_GETBUFFER_DONE

COMPAT_GETBUFFER_FAT:
						CALL	GETBUFFER_FAT

COMPAT_GETBUFFER_DONE:
						JB		COMPAT_CURBUF_LASTBUF_SET
						MOV		WORD PTR CS:[CURBUF],DI;
						MOV		WORD PTR CS:[CURBUF+2],DS
						MOV		WORD PTR CS:[LASTBUFFER],DI;
						MOV		WORD PTR CS:[LASTBUFFER+2],DS

COMPAT_CURBUF_LASTBUF_SET:
						ROL		EDI,16
						POP		DI
						ROL		EDI,16

						POP		ESI
						POP		FS
						POP		GS

						PUSH	CS
						POP		DS

						RET

COMPAT_GETBUFFR			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Take Over GetNextCluster ES:BP=DPB, BX=Cluster()
; 1679:00005225
;   ZF    Set depending on the output DI
;   CF=0  DI is next cluster
;   CF=1  Error
COMPAT_GET_NEXT_CLUSTER	PROC
						PUSH	GS
						PUSh	FS
						PUSH	DS
						PUSHHI_EDI
						PUSH	EAX
						PUSH	ECX
						PUSH	EDX

						PUSH	ES
						POP		GS

						; Don't forget this.
						MOV		WORD PTR GS:[BP+DPB_NUM_FREE_CLUSTERS],0ffffh


						CALL	GET_NEXT_CLUSTER
						; EBX, Hiword of EDX Preserved
						; DS,EDI  Destroyed
						; EAX,ECX Destroyed
						MOV		DI,DX
						JB		COMPAT_GET_NEXT_CLUSTER_DONE

						CALL	GET_BUFFER_BACK
						MOV		WORD PTR CS:[CURBUF],DI
						MOV		WORD PTR CS:[CURBUF+2],DS

						MOV		DI,DX	; Do it again. GET_BUFFER_BACK returns DI
						OR		DI,DI

COMPAT_GET_NEXT_CLUSTER_DONE:
						POP		EDX
						POP		ECX
						POP		EAX
						POPHI_EDI
						POP		DS
						POP		FS
						POP		GS

						RET
COMPAT_GET_NEXT_CLUSTER	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Make Full-Path Name in CS:[FILENAME_BUFFER(0360h)]
; Set CS:[CURRENT_CDS_STRUCT(053Ah)]
; Set CS:[DPB_OR_SYSDEV] to DPB
; Set CS:[FILENAME_BUFFER_PTR(054Ah)] to FILENAME_BUFFER (Maybe unnecessary)
COMPAT_MKFUL:
						PUSH_ALL_HIWORD

COMPAT_MKFUL_DIFFBUF:
						CMP		DI,OFFSET FILENAME_BUFFER
						JNE		COMPAT_MKFUL_DIFFBUF

						CMP		BYTE PTR CS:[NO_SET_DIR],0	; CDS not ready?
						JNE		YSDOS_INFINITE_LOOP

						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],0ffffh ; Tentatively clear CURRENT CDS
						MOV		BYTE PTR CS:[UNKNOWN_FLAG_0515h],0ffh

						PUSh	CS
						POP		ES
						MOV		DI,OFFSET FILENAME_BUFFER
						CALL	MAKE_FULLPATH
						JB		COMPAT_MKFUL_EXIT

						PUSH	CS
						POP		DS
						MOV		SI,OFFSET FILENAME_BUFFER
						CALL	CRUNCH_FILEPATH

						CALL	FULLPATH_TO_LESSER_WILDCARD

						CMP		WORD PTR CS:[FILENAME_BUFFER],5C5Ch ; '\\' means INT 2F drive.
						JE		COMPAT_MKFUL_EXIT
						CMP		BYTE PTR CS:[FILENAME_BUFFER+2],'/' ; Forward Slash means CHARDEV
						JE		COMPAT_MKFUL_USE_TEMP_CDS

;COMPAT_MKFUL_USE_EXISTING_CDS:
						MOV		AL,CS:[FILENAME_BUFFER]
						SUB		AL,'A'
						CALL	GET_ALth_CDS_IN_DSSI
						MOV		AX,DOSERR_DIR_NOT_FOUND
						JB		COMPAT_MKFUL_EXIT

						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],SI	 ; I don't know if it is necessary
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],DS	 ; I don't know if it is necessary
						MOV		EAX,DS:[SI+CDS_DRIVE_PARAM_BLOCK]
						MOV		CS:[DPB_OR_SYSDEV],EAX

						JMP		COMPAT_MKFUL_EXIT

COMPAT_MKFUL_USE_TEMP_CDS:
						; ES is already CS
						MOV		DI,OFFSET TEMPORARY_CDS
						; Question is if it was a device-driver, FOPEN shouldn't even look at the CDS
						; How about just set the pointer, without setting up?
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT],DI
						MOV		WORD PTR CS:[CURRENT_CDS_STRUCT+2],CS
						; At least REDIRECTED flag needs to be cleared after all.
						MOV		WORD PTR CS:[DI+CDS_DRIVE_TYPE],CDS_TYPE_VALID

COMPAT_MKFUL_EXIT:
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR1],OFFSET FILENAME_BUFFER
						MOV		WORD PTR CS:[FILENAME_BUFFER_PTR2],0ffffh
						; To let Proc 41C9h take FILENAME_BUFFER+3 by LEA SI,[DI+3],
						; PTR2 must be 0ffffh and PTR1 must be FILENAME_BUFFER.
						; See 1679:0000421F.

						PUSH	CS	; Looks like caller assumes DS=CS at the end of this function.
						POP		DS

						POP_ALL_HIWORD

						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   ES:BP  DPB
; Return
;   CF=0 No Error.  NE:Unchanged  E:Changed or New()
COMPAT_MEDIACHECK_READYCDS:
						PUSH_ALL_HIWORD
						PUSH	ES

						;   CF=0  No Error  AL=(0:No Change  1:Changed)   GS:BP is DPB for the drive.
						;   CF=1  Device Error  AX=Return Code from Device Driver
						;   ESI   Destroyed
						MOV		AL,ES:[BP+DPB_DRIVE_CODE]
						CALL	MEDIACHECK_READYCDS

						POP		ES

						PUSH	CS
						POP		DS

						CMP		AL,1
						POP_ALL_HIWORD
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



COMPAT_INT21:
						MOV		CS:[COMPAT_AX],AX
						POP		AX
						PUSHF
						PUSH	CS
						PUSH	AX
						MOV		AX,CS:[COMPAT_AX]
						JMP		INT_21H_COMMAND



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



