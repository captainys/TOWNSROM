;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Output
;   DS:DI  Buffer at the back of the chain
; Assumes there is at least one buffer.
GET_BUFFER_BACK			PROC
						PUSH	CS
						POP		DS
						MOV		DI,OFFSET IO_BUFF_PTR
GET_BUFFER_BACK_LOOP:
						LDS		DI,DS:[DI]
						CMP		WORD PTR DS:[DI+IO_BUF_NEXT],0ffffh
						JNE		GET_BUFFER_BACK_LOOP

						RET
GET_BUFFER_BACK			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:DI  Buffer Header
; Hiword of EDI Destroyed (DS is copied)
MOVE_BUFFER_TO_BACK		PROC
						PUSH	FS
						PUSh	BX

						CMP		WORD PTR DS:[DI+IO_BUF_NEXT],0FFFFh
						JE		MOV_BUF_BACK_DONE	; Already back.

						SHL		EDI,16
						MOV		DI,DS
						ROL		EDI,16	;EDI=32-bit buffer pointer

						; First detach it.
						PUSH	CS
						POP		FS
						MOV		BX,OFFSET IO_BUFF_PTR

MOV_BUF_BACK_DETACH_LOOP:
						CMP		EDI,DWORD PTR FS:[BX+IO_BUF_NEXT]
						JE		MOV_BUF_BACK_DETACH_FOUND
						CMP		WORD PTR FS:[BX+IO_BUF_NEXT],0ffffh
						JE		MOV_BUF_BACK_ERREND
						LFS		BX,FS:[BX+IO_BUF_NEXT]
						JMP		MOV_BUF_BACK_DETACH_LOOP

MOV_BUF_BACK_DETACH_FOUND:
						; FS:[BX]->Next=bufferToMoveBack=EDI
						; DS:[DI]->Next=newNextOfFSBX

						MOV		EDI,DWORD PTR DS:[DI+IO_BUF_NEXT]
						; Temporarily EDI=newNextOfFSBX

						XCHG	EDI,DWORD PTR FS:[BX+IO_BUF_NEXT];
						; EDI=bufferToMoveBack
						; FS:[BX]->Next=newNextOfFSBX

						; FS:[BX] is guaranteed not 0xffff, since DS:[DI+IO_BUF_NEXT]
						; has already been confirmed not 0xffff.

MOV_BUF_BACK_SEEK_BACK_LOOP:
						LFS		BX,FS:[BX+IO_BUF_NEXT]
						MOV		ECX,DWORD PTR FS:[BX+IO_BUF_NEXT]
						CMP		CX,0FFFFh
						JNE		MOV_BUF_BACK_SEEK_BACK_LOOP


						MOV		DWORD PTR FS:[BX+IO_BUF_NEXT],EDI
						MOV		DWORD PTR DS:[DI+IO_BUF_NEXT],ECX

MOV_BUF_BACK_DONE:
						CLC
						POP		BX
						POP		FS
						RET
MOV_BUF_BACK_ERREND:
						STC
						POP		BX
						POP		FS
						RET
MOVE_BUFFER_TO_BACK		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DX     LBA
;   AH     Drive
; Return
;   CF=0   DS:DI  Buffer Header
;   CF=1   Not Found, DS:DI destroyed
FIND_MATCHING_BUFFER	PROC
						LDS		DI,CS:[IO_BUFF_PTR]

FIND_MATCHING_BUFFER_LOOP:
						CMP		AH,DS:[DI+IO_BUF_DRV_LOGICAL]
						JNE		FIND_MATCHING_BUFFER_NEXT
						CMP		DX,DS:[DI+IO_BUF_SECTOR_NUM]
						JE		FOUND_MATCHING_BUFFER

FIND_MATCHING_BUFFER_NEXT:
						LDS		DI,DS:[DI+IO_BUF_NEXT]
						CMP		DI,0ffffh
						JNE		FIND_MATCHING_BUFFER_LOOP

DIDNT_FIND_MATCHING_BUFFER:
						STC
						RET

FOUND_MATCHING_BUFFER:
						CLC
						RET

FIND_MATCHING_BUFFER	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   Nothing
; Return
;   CF=0   DS:DI  Buffer Header
;   CF=1   Not Found, DS:DI destroyed
FIND_AVAILABLE_BUFFER	PROC
						PUSH	CS
						POP		DS
						MOV		DI,OFFSET IO_BUFF_PTR

FIND_AVAILABLE_BUFFER_LOOP:
						LDS		DI,DS:[DI]
						TEST	BYTE PTR DS:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_DIRTY
						JE		FOUND_AVAILABLE_BUFFER

						CMP		WORD PTR DS:[DI],0ffffh
						JNE		FIND_AVAILABLE_BUFFER_LOOP

						STC
						RET
FOUND_AVAILABLE_BUFFER:
						CLC
						RET

FIND_AVAILABLE_BUFFER	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   none
; Output
;   DS:DI  A buffer made available.
; BX,CX Destroyed.
; Hiword of EDI Destroyed
; GS:BP, DX and AL Preserved.
MAKE_AVAILABLE_BUFFER	PROC
						PUSH	GS
						PUSH	BP
						PUSH	SI
						PUSH	AX
						PUSH	DX

						LDS		SI,CS:[IO_BUFF_PTR]
						CALL	WRITE_BACK_BUFFER
						MOV		DI,SI

						POP		DX
						POP		AX
						POP		SI
						POP		BP
						POP		GS
						RET
MAKE_AVAILABLE_BUFFER	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  Drive Parameter Block
;   DS:DI  Buffer Header
;   DX     LBA
; Output
;   Initialized buffer
;   DX  Destroyed
CLEAN_BUFFER_HEADER		PROC
						MOV		DS:[DI+IO_BUF_SECTOR_NUM],DX

						MOV		DL,GS:[BP+DPB_DRIVE_CODE]
						MOV		DS:[DI+IO_BUF_DRV_LOGICAL],DL

						MOV		BYTE PTR DS:[DI+IO_BUF_FLAGS],00h
						MOV		BYTE PTR DS:[DI+IO_BUF_WRITE_COUNT],1  ; Tentative
						MOV		BYTE PTR DS:[DI+IO_BUF_WRITE_INC],0    ; Tentative
						MOV		WORD PTR DS:[DI+IO_BUF_DRV_PARAM],BP
						MOV		WORD PTR DS:[DI+IO_BUF_DRV_PARAM+2],GS

						MOV		WORD PTR DS:[DI+IO_BUF_UNUSED],07777h   ; Just keep it clean

						RET
CLEAN_BUFFER_HEADER		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  DPB
;   DS:DI  Buffer
; Output
;   Hiword of EDI  Destroyed (Written DS)
;   CX  Destroyed
;   AX  Destroyed from DEVCALL_READ_SECTOR
POPULATE_BUFFER			PROC

						; DEVCALL_READ_SECTOR
						; Input
						;   AL     Unit
						;   AH     Media Desc
						;   CX     Length in bytes?
						;   DX     LBA
						;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
						;   EDI    Data Buffer (Hiword=SEG, Loword=OFFSET)

						MOV		AL,GS:[BP+DPB_UNIT_CODE]
						MOV		AH,GS:[BP+DPB_MEDIA_DESC_TYPE]

						MOV		CX,1   ; Read one sector
						MOV		DX,DS:[DI+IO_BUF_SECTOR_NUM]

						ROL		EDI,16
						MOV		DI,DS
						ROL		EDI,16
						ADD		DI,IO_BUF_INFO_size

						MOV		ESI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						CALL	DEVCALL_READ_SECTOR
						JC		POPULATE_BUFFER_FAIL

POPULATE_BUFFER_SUCCESS:
						SUB		DI,IO_BUF_INFO_size
						CLC
						RET
POPULATE_BUFFER_FAIL:
						SUB		DI,IO_BUF_INFO_size
						STC
						RET
POPULATE_BUFFER			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  Drive Parameter Block
;   DX     LBA
;   AL     AL==0 Read sector
;          AL!=0 Don't read sector (Just make an available buffer)
; Output
;   CF=0   DS:DI=Buffer (Buffer Header)
;   CF=1   Error
;   AX     Destroyed
;   DX     Destroyed
;   Hiword EDI  Destroyed
GETBUFFER_REGULAR		PROC
						MOV		AH,GS:[BP+DPB_DRIVE_CODE]
						CALL	FIND_MATCHING_BUFFER ; DS:DI Buffer Header, No register destroyed
						JNC		GETBUFFER_REGULAR_DONE

						CALL	FIND_AVAILABLE_BUFFER ; DS:DI Buffer Header, No register destroyed
						JNC		GETBUFFER_REGULAR_PREREAD

						CALL	MAKE_AVAILABLE_BUFFER ; DS:DI Buffer Header, No register destroyed
						JC		GETBUFFER_REGULAR_ERR

GETBUFFER_REGULAR_PREREAD:
						CALL	CLEAN_BUFFER_HEADER

						OR		AL,AL
						JNE		GETBUFFER_REGULAR_DONE
						; GS:BP  DPB
						; DS:DI  Buffer
						CALL	POPULATE_BUFFER

GETBUFFER_REGULAR_DONE:
						CALL	MOVE_BUFFER_TO_BACK
						; COMPAT_GET_NEXT_CLUSTER assumes the last-used buffer is at the bottom.

GETBUFFER_REGULAR_ERR:
						RET
GETBUFFER_REGULAR		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   GS:BP  Drive Parameter Block
;   DX     LBA
;   AL     AL==0 Read sector
;          AL!=0 Don't read sector (Just make an available buffer)
; Output
;   DS:DI  Buffer
;   AX     Destroyed
;   DX     Destroyed
;   Hiword EDI  Destroyed
GETBUFFER_FAT			PROC
						MOV		AH,GS:[BP+DPB_DRIVE_CODE]
						CALL	FIND_MATCHING_BUFFER ; DS:DI Buffer Header, No register destroyed
						JNC		GETBUFFER_FAT_DONE

						CALL	FIND_AVAILABLE_BUFFER
						JNC		GETBUFFER_FAT_PREREAD

						CALL	MAKE_AVAILABLE_BUFFER
						JC		GETBUFFER_FAT_ERROR

GETBUFFER_FAT_PREREAD:
						CALL	CLEAN_BUFFER_HEADER

						OR		BYTE PTR DS:[DI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_FAT
						OR		AL,AL
						JNE		GETBUFFER_FAT_DONE
						; GS:BP  DPB
						; DS:DI  Buffer
						MOV		AL,GS:[BP+DPB_NUM_FATS]
						MOV		DS:[DI+IO_BUF_WRITE_COUNT],AL
						MOV		AL,GS:[BP+DPB_SECTORS_PER_FAT]
						MOV		DS:[DI+IO_BUF_WRITE_INC],AL
						CALL	POPULATE_BUFFER

GETBUFFER_FAT_DONE:
						CALL	MOVE_BUFFER_TO_BACK
						; COMPAT_GET_NEXT_CLUSTER assumes the last-used buffer is at the bottom.

GETBUFFER_FAT_ERROR:
						RET
GETBUFFER_FAT			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  DS:SI  Buffer Header
;Output
;  CF=0  No error.
;  CF=1  AX is the Device Status
;  AX  Destroyed
;  AX  Destroyed
;  BX  Destroyed
;  CX  Destroyed
;  DX  Destroyed
;  EDI Destroyed
WRITE_BACK_BUFFER:
						PUSH	GS
						PUSH	BP

						MOV		BX,0	; To remember error.

						TEST	BYTE PTR DS:[SI+IO_BUF_FLAGS],IO_BUF_FLAG_DIRTY
						JE		WRITE_BACK_BUFFER_END

						LGS		BP,DS:[SI+IO_BUF_DRV_PARAM]
						MOV		DX,DS:[SI+IO_BUF_SECTOR_NUM]

						MOV		DI,DS
						SHL		EDI,16
						MOV		DI,SI
						ADD		DI,IO_BUF_INFO_size
						; EDI is Buffer Pointer (Not Buffer Header Poiner)

WRITE_BACK_BUFFER_FAT_LOOP:
						PUSH	SI

						MOV		ESI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]

						MOV		AL,GS:[BP+DPB_UNIT_CODE]
						MOV		AH,GS:[BP+DPB_MEDIA_DESC_TYPE]
						MOV		CX,1

						CALL	DEVCALL_WRITE
						RCL		BL,1	; Take CF to Bit0 of BL.
						OR		BH,BL	; Bit0 of BH remembers the carry.

						POP		SI

						CMP		DX,DS:[SI+IO_BUF_SECTOR_NUM]
						JNE		WRITE_BACK_BUFFER_END ; Jump if second write.

						MOVZX	CX,BYTE PTR DS:[SI+IO_BUF_WRITE_INC]
						ADD		DX,CX	; Tentatively move to the redundant FAT sector

						TEST	BYTE PTR DS:[SI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_FAT
						JNE		WRITE_BACK_BUFFER_FAT_LOOP

WRITE_BACK_BUFFER_END:
						AND		BYTE PTR DS:[SI+IO_BUF_FLAGS],0ffh-IO_BUF_FLAG_DIRTY

						POP		BP
						POP		GS
						SHR		BH,1	; Move error flag to CF
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;  DS:SI=Buffer
; Output
;  Force Test Write and
;    CF=0 AX=0 if success
;    CF=1 AX=DOSERR if failed
;  It won't change IO_BUF_FLAGS.
;  If failed, it discards the buffer.  (Because nothing can be done.)
BUFFER_TESTWRITE:
						MOV		BL,BYTE PTR DS:[SI+IO_BUF_FLAGS]
						OR		BYTE PTR DS:[SI+IO_BUF_FLAGS],IO_BUF_FLAG_DIRTY
						PUSH	BX
						CALL	WRITE_BACK_BUFFER
						POP		BX
						MOV		BYTE PTR DS:[SI+IO_BUF_FLAGS],BL

						JC		BUFFER_TESTWRITE_ERROR

						XOR		AX,AX
						RET

BUFFER_TESTWRITE_ERROR:
						MOV		WORD PTR DS:[SI+IO_BUF_DRV_LOGICAL],IO_BUF_DRV_UNUSED ; Also clears the flags.
						CALL	DEVERR_TO_DOSERR
						STC
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  DS:SI  Buffer Header
;Output
;  AX  Destroyed
;  BX  Destroyed
;  CX  Destroyed
;  DX  Destroyed
;  EDI Destroyed
WRITE_BACK_AND_MARK_UNUSED:
						CALL	WRITE_BACK_BUFFER
						PUSHF
						MOV		WORD PTR DS:[SI+IO_BUF_DRV_LOGICAL],IO_BUF_DRV_UNUSED ; Also clears the flags.
						POPF
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



FLUSH_BUFFERS:
						PUSH	DS
						PUSH	DI

						PUSH	AX ; Place holder for status code
						LDS		SI,CS:[IO_BUFF_PTR]
						XOR		BX,BX

FLUSH_BUFFERS_LOOP:
						PUSH	BX
						CALL	WRITE_BACK_BUFFER
						POP		BX
						JNC		FLUSH_BUFFERS_NEXT

						POP		BX	; Push status code in the stack
						PUSH	AX
						MOV		BL,0FFH

FLUSH_BUFFERS_NEXT:
						LDS		SI,DS:[SI+IO_BUF_NEXT]
						CMP		SI,0ffffh
						JNE		FLUSH_BUFFERS_LOOP


						POP		AX
						SHR		BL,1	; Bit0 of BL into CF
						POP		DI
						POP		DS
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  AL     Driver (0=A:)
;Output:
;  CF=0   No error.
;  CF=1   There was an error.  AX is the last status from the driver.
;  BX  Destroyed
;  CX  Destroyed
;  DX  Destroyed
;  DS  Destroyed
;  ESI Destroyed
;  EDI Destroyed
FLUSH_BUFFERS_DRIVE:
						PUSH	AX	; Place holder for Device Status

						MOV		BX,0	; Remember errors.
						AND		AL,01fh	; Drive

						LDS		SI,CS:[IO_BUFF_PTR]
FLUSH_BUFFERS_DRIVE_LOOP:
						MOV		AH,DS:[SI+IO_BUF_DRV_LOGICAL]
						AND		AH,01fh
						CMP		AH,AL
						JNE		FLUSH_BUFFERS_DRIVE_NEXT

						PUSH	BX
						PUSH	AX
						CALL	WRITE_BACK_AND_MARK_UNUSED
						POP		AX
						POP		BX
						JNC		FLUSH_BUFFERS_DRIVE_NEXT

						OR		BH,1
						POP		CX
						PUSH	AX

FLUSH_BUFFERS_DRIVE_NEXT:
						LDS		SI,DS:[SI+IO_BUF_NEXT]
						CMP		SI,0ffffh
						JNE		FLUSH_BUFFERS_DRIVE_LOOP

						SHR		BH,1
						POP		AX
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;Input
;  AL     Driver (0=A:)
;Output:
;  CF=0   No error.
;  CF=1   There was an error.  AX=Device Status
;  BX  Destroyed
;  CX  Destroyed
;  DX  Destroyed
;  DS  Destroyed
;  ESI Destroyed
;  EDI Destroyed
;It will not mark buffers unused.  It only turn off DIRTY flags, for subsequent file operations.
FLUSH_BUFFERS_DRIVE_FAT:
						PUSH	AX

						MOV		BX,0	; Remember errors.
						AND		AL,01fh	; Drive

						LDS		SI,CS:[IO_BUFF_PTR]
FLUSH_BUFFERS_DRIVE_FAT_LOOP:
						TEST	BYTE PTR DS:[SI+IO_BUF_FLAGS],IO_BUF_FLAG_IS_FAT
						JE		FLUSH_BUFFERS_DRIVE_FAT_NEXT

						MOV		AH,DS:[SI+IO_BUF_DRV_LOGICAL]
						AND		AH,01fh
						CMP		AH,AL
						JNE		FLUSH_BUFFERS_DRIVE_FAT_NEXT

						PUSH	BX
						CALL	WRITE_BACK_BUFFER
						POP		BX
						JNC		FLUSH_BUFFERS_DRIVE_FAT_NEXT

						OR		BH,1
						POP		CX
						PUSH	AX

FLUSH_BUFFERS_DRIVE_FAT_NEXT:
						LDS		SI,DS:[SI+IO_BUF_NEXT]
						CMP		SI,0ffffh
						JNE		FLUSH_BUFFERS_DRIVE_FAT_LOOP

						SHR		BH,1
						POP		AX
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL  Drive(0=A:)
; Output
;   CF=0  Found a buffer for the drive
;   CF=1  Didn't find a buffer for the drive
CHECK_WRITTEN_BUFFER_FOR_DRIVE:
						PUSH	DS
						PUSH	SI

						LDS		SI,CS:[IO_BUFF_PTR]

CHECK_WRITTEN_BUFFER_DRIVE_LOOP:
						CMP		DS:[SI+IO_BUF_DRV_LOGICAL],AL
						JNE		CHECK_WRITTEN_BUFFER_DRIVE_NEXT
						TEST	BYTE PTR DS:[SI+IO_BUF_FLAGS],IO_BUF_FLAG_DIRTY
						CLC
						JNE		CHECK_WRITTEN_BUFFER_DRIVE_FOUND
CHECK_WRITTEN_BUFFER_DRIVE_NEXT:
						LDS		SI,DS:[SI+IO_BUF_NEXT]
						CMP		SI,0FFFFh
						JNE		CHECK_WRITTEN_BUFFER_DRIVE_LOOP

						STC		; Not found

CHECK_WRITTEN_BUFFER_DRIVE_FOUND:
						POP		SI
						POP		DS
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL  Drive(0=A:)
; Output
;   None
;   Buffers of the drive is discarded.
DISCARD_BUFFER_FOR_DRIVE:
						PUSH	DS
						PUSH	SI

						LDS		SI,CS:[IO_BUFF_PTR]

DISCARD_BUFFER_FOR_DRIVE_LOOP:
						CMP		DS:[SI+IO_BUF_DRV_LOGICAL],AL
						JNE		DISCARD_BUFFER_FOR_DRIVE_NEXT
						CALL	DISCARD_BUFFER
DISCARD_BUFFER_FOR_DRIVE_NEXT:
						LDS		SI,DS:[SI+IO_BUF_NEXT]
						CMP		SI,0FFFFh
						JNE		DISCARD_BUFFER_FOR_DRIVE_LOOP

						POP		SI
						POP		DS
						RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  Buffer Header
DISCARD_BUFFER:
						MOV		WORD PTR DS:[SI+IO_BUF_DRV_LOGICAL],IO_BUF_DRV_UNUSED ; Also clears the flags.
						RET



