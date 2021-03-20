SET_ESBX_AS_REQPTR		MACRO
						PUSH	CS
						POP		ES
						MOV		BX,OFFSET YSDOS_UTILITY_BUFFER
						ENDM



UNPREP_REQPTR			MACRO
						; Eventually I'll take from stack.
						; Until I know enough stack, I keep it YSDOS_UTILITY_BUFFER
						ENDM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL     DEVREQ_CMD_OPEN or DEVREQ_CMD_CLOSE
;   FS:DI  SF_ENTRY
; Output
;   CF=1      Error
;   AL        Destroyed
;   AH,BX,CX  Preserved
;   ES,DS     Preserved
DEVCALL_OPEN_SF			PROC
						MOV		AL,DEVREQ_CMD_OPEN
						CALL	DEVCALL_OPEN_CLOSE_SF
						RET
DEVCALL_OPEN_SF			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL     DEVREQ_CMD_OPEN or DEVREQ_CMD_CLOSE
;   FS:DI  SF_ENTRY
; Output
;   CF=1      Error
;   AL        Destroyed
;   AH,BX,CX  Preserved
;   ES,DS     Preserved
DEVCALL_CLOSE_SF		PROC
						MOV		AL,DEVREQ_CMD_CLOSE
						CALL	DEVCALL_OPEN_CLOSE_SF
						RET
DEVCALL_CLOSE_SF		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;DEVCALL_OPEN/CLOSE(sf_entry &sf)
;{
;	if(true!=(sf_entry.devflags & redirected)) // redirected means INT 21H device
;	{
;		if(sf_entry.devFlags&is_char)
;		{
;			auto driverPtr=sf_entry.driver_pointer;
;			DEVCALL_Open/Close(driverPtr,random,random);
;		}
;		else if(BYTE PTR CS:[02b1]!=0)
;		{
;			auto dpb=(dpb *)sf_entry.driver_pointer;
;			auto driverPtr=dpb->driver_pointer;
;			DEVCALL_OpenClose(driverPtr,dpb->drive,dpb->unit);
;		}
;	}
;}

; Input
;   AL     DEVREQ_CMD_OPEN or DEVREQ_CMD_CLOSE
;   FS:DI  SF_ENTRY
; Output
;   AX,BX,CX  Destroyed
;   ES,DS     Destroyed
DEVCALL_OPEN_CLOSE_SF	PROC
						PUSH	AX
						PUSH	BX
						PUSH	CX
						PUSH	SI
						PUSH	DS
						PUSH	ES

						MOV		BL,AL

						CALL	GET_SF_DEVICE_DRIVER
						;   DS:SI  Device Driver Pointer
						;   CL     Drive (0 if chardev)
						;   CH     Unit (0 if chardev)
						;	AH     Media Descriptor (0 if chardev)
						;   AL     0FFh CHARDEV, Zero Not CHARDEV
						;   ZF=1(E)    If redirected (INT 2F device)
						;   ZF=0(NE)   Redirected (INT 2F device)
						CLC
						JNE		DEVCALL_OPEN_CLOSE_SF_RET

						OR		AL,BYTE PTR CS:[USE_OPPENCLOSE_BLOCKDEV]
						; AL=IS_CHARDEV or 0!=CS:[USE_OPPENCLOSE_BLOCKDEV]
						JE		DEVCALL_OPEN_CLOSE_SF_RET

						MOV		AL,BL
						XOR		BX,BX
						TEST	WORD PTR DS:[SI+SYSDEV_DEVFLAGS],SYSDEV_DEVFLAG_OPEN_CLOSE_SUPPORTED
						JE		DEVCALL_OPEN_CLOSE_SF_RET

						CALL	DEVCALL_OPEN_OR_CLOSE

						CLC
						TEST	BX,DEVREQ_STATUS_ERROR
						JE		DEVCALL_OPEN_CLOSE_SF_RET
						STC

DEVCALL_OPEN_CLOSE_SF_RET:
						POP		ES
						POP		DS
						POP		SI
						POP		CX
						POP		BX
						POP		AX
						RET
DEVCALL_OPEN_CLOSE_SF	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;	AL  DEVREQ Command
;   CH  Unit
;   DS:SI  Device Driver Pointer
; Output
;   BX  Returned status code
;   ES  Destroyed
DEVCALL_OPEN_OR_CLOSE	PROC
						PUSH	CS
						POP		ES
						MOV		BX,OFFSET YSDOS_UTILITY_BUFFER
						MOV		BYTE PTR ES:[BX+REQ_LEN],0Dh
						MOV		BYTE PTR ES:[BX+REQ_UNIT],CH
						MOV		BYTE PTR ES:[BX+REQ_COMMAND],AL
						MOV		WORD PTR ES:[BX+REQ_STATUS],0
						CALL	CALL_STRATEGY_AND_INTERRUPT
						MOV		BX,ES:[BX+REQ_STATUS]
						RET
DEVCALL_OPEN_OR_CLOSE	ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL     Unit
;   AH     Media Descriptor
;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
; Return
;   CF=1 AX=Status Code  If error ((status code&0x8000)!=0)
;   CF=0 AH=[REQ+REQ_MEDIACHECK_CODE_RETURN] (1=unchanged, 0=unknown, -1=changed), AL Destroyed
DEVCALL_MEDIACHECK:
						PUSH	ES
						PUSH	DS
						PUSh	BX

						ROL		ESI,16
						MOV		DS,SI
						ROR		ESI,16	; DS:DI is device driver pointer.

						SET_ESBX_AS_REQPTR

						MOV		BYTE PTR ES:[BX+REQ_LEN],0fH
						MOV		ES:[BX+REQ_UNIT],AL
						MOV		BYTE PTR ES:[BX+REQ_COMMAND],DEVREQ_CMD_MEDIA_CHECK
						MOV		WORD PTR ES:[BX+REQ_STATUS],0
						MOV		BYTE PTR ES:[BX+REQ_READ_WRITE_MEDIA_DESC],AH
						CALL	CALL_STRATEGY_AND_INTERRUPT

						MOV		AX,ES:[BX+REQ_STATUS]
						TEST	AX,8000h
						STC
						JNE		DEVCALL_MEDIACHECK_RET

						MOV		AH,ES:[BX+REQ_MEDIACHECK_CODE_RETURN]
						CLC
DEVCALL_MEDIACHECK_RET:
						UNPREP_REQPTR
						POP		BX
						POP		DS
						POP		ES
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL     Unit
;   AH     Media Desc
;   CX     Length in bytes? (Prob number of sectors)
;   DX     LBA
;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
;   EDI    Data Buffer (Hiword=SEG, Loword=OFFSET)
; Return
;   AX     Status Code
;   CF=1   If AX&0x8000  CF=0   Otherwise
DEVCALL_READ_SECTOR		PROC
						PUSH	DS
						PUSH	ES
						PUSH	BX

						MOV		BX,OFFSET YSDOS_UTILITY_BUFFER
						MOV		BYTE PTR CS:[BX+REQ_LEN],16h
						MOV		CS:[BX+REQ_UNIT],AL
						MOV		BYTE PTR CS:[BX+REQ_COMMAND],DEVREQ_CMD_READ
						MOV		WORD PTR CS:[BX+REQ_STATUS],0
						MOV		CS:[BX+REQ_READ_WRITE_MEDIA_DESC],AH
						MOV		DWORD PTR CS:[BX+REQ_READ_WRITE_BUFFER_PTR],EDI
						MOV		CS:[BX+REQ_READ_WRITE_SECTOR_COUNT],CX
						MOV		CS:[BX+REQ_READ_WRITE_LBA],DX

						ROL		ESI,16
						MOV		DS,SI
						ROL		ESI,16

						PUSH	CS
						POP		ES
						CALL	CALL_STRATEGY_AND_INTERRUPT

						MOV		AX,ES:[BX+REQ_STATUS]
						TEST	AX,8000h
						STC
						JNE		DEVCALL_READ_SECTOR_DONE

						MOV		AX,ES:[BX+REQ_READ_WRITE_LENGTH]
						CLC
DEVCALL_READ_SECTOR_DONE:
						POP		BX
						POP		ES
						POP		DS
						RET
DEVCALL_READ_SECTOR		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



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
DEVCALL_WRITE			PROC
						PUSH	DS
						PUSH	ES
						PUSH	BX

						MOV		BX,OFFSET YSDOS_UTILITY_BUFFER
						MOV		BYTE PTR CS:[BX+REQ_LEN],16h
						MOV		CS:[BX+REQ_UNIT],AL
						MOV		BYTE PTR CS:[BX+REQ_COMMAND],DEVREQ_CMD_WRITE
						MOV		WORD PTR CS:[BX+REQ_STATUS],0
						MOV		CS:[BX+REQ_READ_WRITE_MEDIA_DESC],AH
						MOV		DWORD PTR CS:[BX+REQ_READ_WRITE_BUFFER_PTR],EDI
						MOV		CS:[BX+REQ_READ_WRITE_SECTOR_COUNT],CX
						MOV		CS:[BX+REQ_READ_WRITE_LBA],DX

						ROL		ESI,16
						MOV		DS,SI
						ROL		ESI,16

						PUSH	CS
						POP		ES
						CALL	CALL_STRATEGY_AND_INTERRUPT

						MOV		AX,ES:[BX+REQ_STATUS]
						TEST	AX,8000h
						STC
						JNE		DEVCALL_WRITE_DONE

						MOV		AX,ES:[BX+REQ_READ_WRITE_LENGTH]
						CLC
DEVCALL_WRITE_DONE:
						POP		BX
						POP		ES
						POP		DS
						RET
DEVCALL_WRITE			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



DEVERR_TO_DOSERR_TABLE:
						DB	DOSERR_WRITE_PROTEDTED
						DB	DOSERR_UNKNOWN_UNIT
						DB	DOSERR_DRIVE_NOT_READY
						DB	DOSERR_UNKNOWN_COMMAND
						DB	DOSERR_CRC_ERROR
						DB	DOSERR_BAD_REQ_LEN
						DB	DOSERR_SEEK_ERROR
						DB	DOSERR_UNKNOWN_MEDIUM
						DB	DOSERR_SECTOR_NOT_FOUND
						DB	DOSERR_OUT_OT_PAPER
						DB	DOSERR_WRITE_FAULT
						DB	DOSERR_READ_FAULT
						DB	DOSERR_GENERAL_FAULT
						DB	DOSERR_GENERAL_FAULT
						DB	DOSERR_INVALID_DISK_CHANGE



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX  Returned device status
; Output
;   AX  DOS Error
DEVERR_TO_DOSERR:
						XCHG	AX,BX
						AND		BX,000fH
						MOVZX	AX,BYTE PTR CS:[DEVERR_TO_DOSERR_TABLE+BX]
						XCHG	AX,BX
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AL    Unit
;   AH    Last known MediaDesc
;   EDI   Buffer Header used for BuildBPB (Hiword=SEG, Loword=OFFSET)
;   ESI   Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
; Return
;   CF=0  EAX    Built BPB (Hiword is SEG, Loword is OFFSET)
;   CF=1  AX     Status Code
DEVCALL_BUILDBPB:
						PUSH	DS
						PUSH	ES
						PUSH	BX

						MOV		BX,OFFSET YSDOS_UTILITY_BUFFER
						MOV		BYTE PTR CS:[BX+REQ_LEN],REQ_BUILDBPB_LEN
						MOV		CS:[BX+REQ_UNIT],AL
						MOV		BYTE PTR CS:[BX+REQ_COMMAND],DEVREQ_CMD_BUILD_BPB
						MOV		WORD PTR CS:[BX+REQ_STATUS],0
						MOV		CS:[BX+REQ_READ_WRITE_MEDIA_DESC],AH
						ADD		DI,IO_BUF_INFO_size
						MOV		DWORD PTR CS:[BX+REQ_READ_WRITE_BUFFER_PTR],EDI
						SUB		DI,IO_BUF_INFO_size

						ROL		ESI,16
						MOV		DS,SI
						ROL		ESI,16

						PUSH	CS
						POP		ES
						CALL	CALL_STRATEGY_AND_INTERRUPT

						MOV		AX,ES:[BX+REQ_STATUS]
						TEST	AX,8000h
						STC
						JNE		DEVCALL_BUILDBPB_DONE

						MOV		EAX,ES:[BX+REQ_BUILDBPB_PTR_RETURN]
						CLC
DEVCALL_BUILDBPB_DONE:
						POP		BX
						POP		ES
						POP		DS
						RET



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   AX     Zero (May be needed)
;   CX     Length in bytes
;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
;   EDI    Data Buffer (Hiword=SEG, Loword=OFFSET)
; Return
;   AX     Status Code
;   CF=1   If AX&0x8000  CF=0   Otherwise
DEVCALL_IOCTL_READ		PROC
						PUSH	DS
						PUSH	ES
						PUSH	BX

						MOV		BX,OFFSET YSDOS_UTILITY_BUFFER
						MOV		BYTE PTR CS:[BX+REQ_LEN],16h ; https://sites.google.com/site/pcdosretro/dostables tells 14h, but disassembly tells 16h
						MOV		CS:[BX+REQ_UNIT],AL
						MOV		BYTE PTR CS:[BX+REQ_COMMAND],DEVREQ_CMD_IOCTL_READ
						MOV		WORD PTR CS:[BX+REQ_STATUS],0
						MOV		CS:[BX+REQ_READ_WRITE_MEDIA_DESC],AH ; https://sites.google.com/site/pcdosretro/dostables says unused.  Maybe.
						MOV		DWORD PTR CS:[BX+REQ_READ_WRITE_BUFFER_PTR],EDI
						MOV		CS:[BX+REQ_READ_WRITE_LENGTH],CX

						ROL		ESI,16
						MOV		DS,SI
						ROL		ESI,16

						PUSH	CS
						POP		ES
						CALL	CALL_STRATEGY_AND_INTERRUPT

						MOV		AX,ES:[BX+REQ_STATUS]
						TEST	AX,8000h
						STC
						JNE		DEVCALL_IOCTL_READ_DONE

						MOV		AX,ES:[BX+REQ_READ_WRITE_LENGTH]
						CLC
DEVCALL_IOCTL_READ_DONE:
						POP		BX
						POP		ES
						POP		DS
						RET
DEVCALL_IOCTL_READ		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
;   AX=(Probably)Days since January 1 1980.
;   CH=hour;
;   CL=minute
;   DH=second
;   DL=1/100seconds
DEVCALL_READ_CLOCK:
						PUSH	BX
						PUSH	ESI
						PUSH	EDI

						XOR		AX,AX
						XOR		DX,DX
						MOV		CX,6
						MOV		ESI,DWORD PTR CS:[BCLOCK]

						MOV		DI,CS
						SHL		EDI,16
						MOV		DI,OFFSET YSDOS_UTILITY_BUFFER+20h ; Command takes 16h bytes.

						; Input
						;   AL     Unit
						;   AH     Media Desc
						;   CX     Length in bytes? (Prob number of sectors)
						;   DX     LBA
						;   ESI    Device Driver Pointer (Hiword=SEG, Loword=OFFSET)
						;   EDI    Data Buffer (Hiword=SEG, Loword=OFFSET)
						CALL	DEVCALL_READ_SECTOR
						; Return
						;   AX     Status Code
						;   CF=1   If AX&0x8000  CF=0   Otherwise
						JC		DEVCALL_READ_CLOCK_ERR

						MOV		AX,WORD PTR CS:[YSDOS_UTILITY_BUFFER+20h] ; Must be date
						MOV		CX,WORD PTR CS:[YSDOS_UTILITY_BUFFER+22h] ; CH=hour, CL=minute
						MOV		DX,WORD PTR CS:[YSDOS_UTILITY_BUFFER+24h] ; DH=second, DL=1/100seconds
						POP		EDI
						POP		ESI
						POP		BX
						RET

DEVCALL_READ_CLOCK_ERR:
						POP		EDI
						POP		ESI
						POP		BX
						XOR		AX,AX
						XOR		CX,CX
						XOR		DX,DX
						STC
						RET

