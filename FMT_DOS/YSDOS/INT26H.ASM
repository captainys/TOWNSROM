INT_26H_AX				DW		0



; Input
;   AL=Drive Number (0=A:)
;   CX=Number of Sectors to write
;   DX=Starting sector
;   DS:BX=Data Buffer
INT_26H_BIOS_DISKWRITE:
						SAVE_REGISTERS
						MOV		CS:[INT_26H_AX],AX

						MOV		EDI,DS
						SHL		EDI,16
						MOV		DI,BX	; EDI=Data Buffer

						PUSH	EDI
						PUSH	CX
						PUSH	DX
						CALL	GET_DRIVE_CDS
						POP		DX
						POP		CX
						POP		EDI
						JC		INT_26H_INVALID_DRIVE

						; DS:BX=CDS
						TEST	WORD PTR DS:[BX+CDS_DRIVE_TYPE],CDS_TYPE_REDIRECTED
						JNE		INT_26H_INVALID_DRIVE

						_LGS	BP,DS:[BX+CDS_DRIVE_PARAM_BLOCK]

						MOV		AL,GS:[BP+DPB_UNIT_CODE]
						MOV		AH,GS:[BP+DPB_MEDIA_DESC_TYPE]
						MOV		ESI,GS:[BP+DPB_PTR_TO_DEV_DRIVER]
						; Input
						;   AL     Unit
						;   AH     Media Desc
						;   CX     Length in bytes in CHARDEV, Number of sectors in BLOCKDEV
						;   DX     LBA
						;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
						;   EDI    Data Buffer (Hiword=SEG, Loword=OFFSET)
						; Return
						;   CF=0   AX=Length written
						;   CF=1   If 0!=(StatusCode&0x8000) AX=StatusCode
						CALL	DEVCALL_WRITE
						JC		INT_26H_DEVERROR


						MOV		AX,CS:[INT_26H_AX]	; Recover drive
						_LDS	SI,CS:[IO_BUFF_PTR]
INT_26H_IO_BUF_LOOP:
						CMP		AL,BYTE PTR DS:[SI+IO_BUF_DRV_LOGICAL]
						JNE		INT_26H_IO_BUF_NEXT

						MOV		BX,DS:[SI+IO_BUF_SECTOR_NUM]
						SUB		BX,DX
						JB		INT_26H_IO_BUF_NEXT
						CMP		BX,CX
						JAE		INT_26H_IO_BUF_NEXT

						CALL	DISCARD_BUFFER

INT_26H_IO_BUF_NEXT:
						_LDS	SI,DS:[IO_BUF_NEXT]
						CMP		SI,0FFFFh
						JNE		INT_26H_IO_BUF_LOOP



INT_26H_EXIT:
						RESTORE_REGISTERS
						MOV		AX,CS:[INT_26H_AX]
						RETF

INT_26H_DEVERROR:
						CALL	DEVERR_TO_DOSERR
						MOV		WORD PTR CS:[INT_26H_AX],AX
						STC
						JMP		INT_26H_EXIT

INT_26H_INVALID_DRIVE:
						MOV		WORD PTR CS:[INT_26H_AX],DOSERR_INVALID_DRIVE
						STC
						JMP		INT_26H_EXIT
