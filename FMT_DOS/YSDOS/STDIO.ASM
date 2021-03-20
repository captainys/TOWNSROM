;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return:
;   CF=1  Detected Ctrl+C.  Ctrl+C key code (3) will be popped.
;   CF=0  Not detected Ctrl+C.  Not touch the key buffer.
CHECK_FOR_CRTLC			PROC
						PUSH	DS
						PUSH	ES
						PUSH	AX
						PUSH	BX
						PUSH	SI

						CMP		BYTE PTR CS:[INDOS],1	; Take CTRL+C only if it is the first-level INT call.
						CLC
						JNE		CHECK_CTRLC_NOT_CTRL

						LDS		SI,CS:[BCON]
						PUSH	CS
						POP		ES
						MOV		BX,OFFSET CONSDEV_REQHDR
						MOV		BYTE PTR ES:[BX+REQ_LEN],CONSDEV_REQ_HEADER_size
						MOV		BYTE PTR ES:[BX+REQ_COMMAND],DEVREQ_CMD_NON_DEST_READ
						MOV		WORD PTR ES:[BX+REQ_STATUS],0
						CALL	CALL_STRATEGY_AND_INTERRUPT
						TEST	WORD PTR ES:[BX+REQ_STATUS],CONSDEV_FLAG_BUSY
						JNE		CHECK_CTRLC_NOT_CTRL

						CMP		BYTE PTR ES:[BX+CONSDEV_REQ_CHR],03h	; CHAR  03=Ctrl+C
						CLC
						JNE		CHECK_CTRLC_NOT_CTRL

						MOV		BYTE PTR ES:[BX+REQ_LEN],16h			; RW_REQ Size varies between 16h to 1eh
						MOV		BYTE PTR ES:[BX+REQ_COMMAND],DEVREQ_CMD_READ
						MOV		WORD PTR ES:[BX+REQ_STATUS],0

						MOV		BYTE PTR ES:[BX+RW_REQ_MEDIA_DESC],0
						; MS-DOS V2.0 Source Writes CL after XOR CX,CX.
						; MS-DOS V3.1 Write CL without XOR CX,CX.
						; The value of CL looks to be pretty random from deubgger.  I think it's a bug.
						; I go with writing zero.

						CALL	CALL_STRATEGY_AND_INTERRUPT

						STC

CHECK_CTRLC_NOT_CTRL:
						POP		SI
						POP		BX
						POP		AX
						POP		ES
						POP		DS
						RET
CHECK_FOR_CRTLC			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



PROCESS_CTRL_C			PROC
						; Process Ctrl+C
						MOV		BYTE PTR CS:[CONSWAP],0
						; Here calls SWAPBACK.  Probably CONSWAP is a flag for redirection.
						; MS-DOS V2.0's SWAPBACK does some processing.
						; MS-DOS V3.1's SWAPBACK only clears the CONSWAP flag.

						RESTORE_REGISTERS
						DEC		BYTE PTR CS:[INDOS]

						MOV		CS:[CTRL_C_SP],SP
						INT		23H		; User Ctrl+C Handler.  Command.com will not return from there.

						; The original MS-DOS checks if the SP changes across INT 23H,
						; and re-try the same command if SP stays the same.
						; How come?  Well, I don't understand, but I just follow what it does.
						CMP		SP,CS:[CTRL_C_SP]
						JE		PROCESS_CTRL_C_RETRY

						; Then, the original MS-DOS does another strange check.
						; If SP==SavedSP-2, it assumes the new system call???
						; So, it is a situation INT 23H returns with RETF instead of IRET.
						; I really don't understand why.  I just kill the process.
						MOV		AX,4C00H
						JMP		INT_21H_COMMAND

PROCESS_CTRL_C_RETRY:
						; Assuming INT 23H saves registers, I see that the state of SS,SP and
						; registers are as same as the beginning of INT 21H from RESTORE_REGISTERS
						JMP		INT_21H_COMMAND


CTRL_C_SP				DW		0

PROCESS_CTRL_C			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Return
;   CF=0  FS:DI  SF_TABLE
;   CF=1  Error
;   AX destroyed
GET_COUT_SF_ENTRY		PROC
						CMP		BYTE PTR CS:[CONSWAP],0
						JNE		GET_COUT_SF_ENTRY_REDIR

						MOV		AX,FILE_STDOUT
						CALL	GET_SF_ENTRY_FROM_JFN
						RET

GET_COUT_SF_ENTRY_REDIR:
						LFS		DI,CS:[PROB_COUT_SF_ENTRY_PTR]
						CLC
						RET
GET_COUT_SF_ENTRY		ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



PUTC					PROC
						CMP		AL,ASCII_TAB
						JNE		PUTC_NOT_TAB
PUTC_TAB_LOOP:
						MOV		AL,' '
						CALL	PUTC_LOW_LEVEL
						INC		BYTE PTR CS:[CARPOS]
						TEST	BYTE PTR CS:[CARPOS],7
						JNE		PUTC_TAB_LOOP
						RET
PUTC_NOT_TAB:
						CMP		AL,ASCII_RETURN
						JNE		PUTC_NOT_RETURN
						MOV		BYTE PTR CS:[CARPOS],0
PUTC_NOT_RETURN:
						CMP		AL,ASCII_BACKSPACE
						JNE		PUTC_CALL_LOW_LEVEL
						DEC		BYTE PTR CS:[CARPOS]

PUTC_CALL_LOW_LEVEL:
						CALL	PUTC_LOW_LEVEL
						RET

PUTC					ENDP



; Pretty much everything destroyed.
PUTC_LOW_LEVEL			PROC
						INC		BYTE PTR CS:[CONOUT_CTRLC_CHECK_CTR]
						TEST	BYTE PTR CS:[CONOUT_CTRLC_CHECK_CTR],3
						JNE		PUTC_LL_NO_CTRLC

						CALL	CHECK_FOR_CRTLC
						JNC		PUTC_LL_NO_CTRLC
						CALL	PROCESS_CTRL_C
PUTC_LL_NO_CTRLC:
						PUSH	AX
						CALL	GET_COUT_SF_ENTRY
						POP		AX
						JB		PUTC_LOW_LEVEL_RET

						; FS:DI is the SF_ENTRY for CONOUT

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_REDIRECTED
						JNE		PUTC_LL_NOT_INT_29H_DEVICE
						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						JE		PUTC_LL_NOT_INT_29H_DEVICE


						LDS		SI,FS:[DI+SF_DRIVER_POINTER]

						; MS-DOS V3.1 does check SF_DEVFLAG_REDIRECTED and SF_DEVFLAG_IS_CHARDEV
						; with SF_ENTRY.SF_DEVFLAGS, and SF_DEVFLAG_CHAR_INT_29H_OUT with SYSDEV.SYSDEV_DEVFLAGS.
						; Aren't they copies?  But, actually CON devide has 0813h at SYSDEV.SYSDEV_DEVFLAGS,
						; but SF_TABLE has 00D3h.  Need more study.
						; -> Turned out SYSDEV.DEVFLAGS meaning slightly different from SF_ENTRY.DEVFLAGS.

						; DS:SI is the device driver pointer.
						TEST	WORD PTR DS:[SI+SYSDEV_DEVFLAGS],SYSDEV_DEVFLAG_INT_29H_OUT
						JE		PUTC_LL_NOT_INT_29H_DEVICE

						; OK, is a INT 29H device.
						INT		29H
						CLC
PUTC_LOW_LEVEL_RET:
						RET


PUTC_LL_NOT_INT_29H_DEVICE:
						CALL	WRITE_ONE_BYTE

						RET

PUTC_LOW_LEVEL			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;    AL     Byte output
;    FS:DI   SF_ENTRY
; Pretty much every registere destroyed from FWRITE
WRITE_ONE_BYTE			PROC
						XOR		AH,AH
						PUSH	AX		; SS:SP is one-byte string.

						TEST	WORD PTR FS:[DI+SF_DEVFLAGS],SF_DEVFLAG_IS_CHARDEV
						JE		WRITE_ONE_BYTE_BLOCKDEV

						LDS		SI,FS:[DI+SF_DRIVER_POINTER]
						;    DS:SI  Device Driver Pointer (Passed to CALL_STRATEGY_AND_INTERRUPT)
						PUSH	CS
						POP		ES
						MOV		BX,OFFSET CONSDEV_REQHDR2

						MOV		WORD PTR ES:[BX+REQ_LEN],016h	; Length=16h(for WRITE), Unit=0
						MOV		BYTE PTR ES:[BX+REQ_COMMAND],DEVREQ_CMD_WRITE
						MOV		WORD PTR ES:[BX+REQ_STATUS],0

						MOV		WORD PTR ES:[BX+REQ_READ_WRITE_MEDIA_DESC],0	; Meaning?
						MOV		WORD PTR ES:[BX+REQ_READ_WRITE_BUFFER_PTR],SP
						MOV		WORD PTR ES:[BX+REQ_READ_WRITE_BUFFER_SEG],SS
						MOV		WORD PTR ES:[BX+REQ_READ_WRITE_LENGTH],1

						CALL	CALL_STRATEGY_AND_INTERRUPT
						JMP		WRITE_ONE_BYTE_EXIT

WRITE_ONE_BYTE_BLOCKDEV:

						;     FS:DI  SF_ENTRY
						;     CX     Bytes to write
						;     EDX    Data Pointer (Hiword is SEG, and Loword is OFFSET)
						MOV		CX,1
						MOV		DX,SS
						SHL		EDX,16
						MOV		DX,SP
						CALL	FWRITE

WRITE_ONE_BYTE_EXIT:
						POP		AX
						RET

WRITE_ONE_BYTE			ENDP



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; Input
;   DS:SI  '$'-terminated string
PUTS:
						LODSB
						CMP		AL,'$'
						JE		PUTS_END
						PUSH	DS
						PUSH	SI
						CALL	PUTC
						POP		SI
						POP		DS
						JMP		PUTS
PUTS_END:
						RET
